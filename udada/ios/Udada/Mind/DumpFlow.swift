import SwiftUI

/// 비우기 흐름: 쏟아내기(쓰기·말·사진) → 카드로 나누기 → 한 장씩 자리 정하기 → 지금 할 단 하나.
/// 열린 고리마다 '언제' 또는 '안 함'을 붙이면 침투 사고가 사라진다 (Masicampo & Baumeister 2011). 다 하게 만드는 게 아니다.
/// - AI 를 기다리지 않아도 된다: AI 가 없으면 규칙으로 바로, 있으면 '기다리지 않고 나누기'. 'AI' 표시는 AI 가 낸 제안에만.
/// - 중간에 닫아도 정한 것은 하루 한 장에 들어가고(기록은 한 번), 안 정한 줄은 쓰던 글로 남는다.
struct DumpFlow: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize

    enum Step: Hashable { case write, thinking, sort, finish }
    typealias When = DumpPlan.When

    struct Card: Identifiable, Hashable {
        var id: UUID { s.id }
        var s: DumpSuggestion
        var bin: DumpBin?
        var when: When?
        var committed = false
    }

    @State private var step: Step = .write
    @State private var text = ""
    @State private var restored = false
    @State private var clearedText: String?
    @State private var noiseBefore: Int?
    @State private var noiseAfter: Int?
    @State private var cards: [Card] = []
    @State private var index = 0
    @State private var pickingDate = false
    @State private var datePicker = false
    @State private var showVoice = false
    @State private var showScan = false
    @State private var showAudio = false
    /// 밖에서 받은 것(공유 · 녹음)을 읽는 중이면 그 한 줄
    @State private var receiving: String?
    /// 무엇에서 찾았는지 (Apple Intelligence 표시 옆에)
    @State private var receivedFrom: String?
    @State private var shredding: String?
    @State private var oneThingTitle: String?
    @State private var firstStep: String?
    @State private var firstStepFromAI = false
    @State private var stepLoading = false
    @State private var logged = false
    @State private var didSetUp = false
    @State private var organizing: Task<Void, Never>?
    @State private var canSkipWait = false
    @State private var next: FlowNext?
    @AppStorage(FlowMemory.draftKey) private var draft = ""
    @AppStorage(FlowMemory.swipedKey) private var swipeLearned = false
    @FocusState private var editorFocused: Bool

    static let example = "레포트 금요일까지 3장 시작도 안 함\n엄마한테 전화\n방 정리\n택배 반품 언제까지더라\n단톡 답장 안 했음\n다음 달 월세 오르면 어떡하지\n헬스 등록할까 말까"
    private static let placeholder = "할 일, 걱정, 생각난 거 전부.\n한 줄에 하나씩. 맞춤법·순서 상관없음."

    var body: some View {
        ZStack {
            Ink.ground.ignoresSafeArea()
            if let next {
                FlowNextView(next: next).transition(.opacity)
            } else {
                switch step {
                case .write: write.transition(.opacity)
                case .thinking: thinking.transition(.opacity)
                case .sort: sort.transition(.opacity)
                case .finish: finish.transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.88), value: step)
        .animation(.easeInOut(duration: 0.3), value: next)
        .onAppear(perform: setUp)
        .onDisappear(perform: closeOut)
        .onChange(of: text) { _, t in
            guard step == .write else { return }
            if !t.isEmpty { clearedText = nil }
            draft = t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : t
        }
        .fullScreenCover(isPresented: $showVoice) {
            VoiceDumpView(onDone: { t, live in
                showVoice = false
                // 적어 둔 글이 없었으면 말하는 동안 떨어진 카드로 바로 넘어간다 (다시 나누느라 기다리지 않는다)
                let fresh = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                text = fresh ? t : text + "\n" + t
                if fresh, !live.isEmpty, step == .write { startSorting(live) }
            }, onCancel: { showVoice = false })
            .environment(store)
        }
        .fullScreenCover(isPresented: $showScan) {
            TextScanView(onDone: { lines in
                showScan = false
                let joined = lines.joined(separator: "\n")
                text = text.isEmpty ? joined : text + "\n" + joined
            }, onCancel: { showScan = false })
        }
        .fileImporter(isPresented: $showAudio, allowedContentTypes: [.audio, .mpeg4Movie]) { result in
            if case .success(let url) = result { Task { await hear(url, own: false) } }
        }
        .sheet(isPresented: $datePicker) {
            DateOnlyPicker(initial: (cards[safe: index]?.s.day ?? store.today.adding(days: 1)).date()) { d in
                if let c = cards[safe: index] { put(c.id, .date, when: .day(DayKey(d), c.s.part ?? .morning)) }
            }
        }
    }

    /// 다시 나타날 때(말·사진 화면에서 돌아올 때)는 고른 소음을 덮지 않는다
    private func setUp() {
        guard !didSetUp else { return }
        didSetUp = true
        FlowMemory.prepare()
        noiseBefore = store.data.dumps.last?.after ?? 6
        if text.isEmpty, !draft.isEmpty { text = draft; restored = true }
        Brain.shared.prewarm()
        switch store.dumpMode {
        case .voice: DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showVoice = true }
        case .photo: DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showScan = true }
        case .text:
            // 화면이 다 올라오기 전의 포커스 요청은 무시될 수 있어 한 번 더 (느린 기기)
            for delay in [0.45, 1.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if step == .write && !editorFocused && !showVoice && !showScan { editorFocused = true }
                }
            }
        }
        store.dumpMode = .text
        if store.takeInbox { store.takeInbox = false; Task { await takeInbox() } }
    }

    // MARK: 밖에서 받기 (공유로 받아 둔 것 · 녹음 파일)

    private func append(_ lines: [String], from label: String) {
        guard !lines.isEmpty else { return }
        withAnimation(reduceMotion ? nil : Motion.soft) {
            let joined = lines.joined(separator: "\n")
            text = text.isEmpty ? joined : text + "\n" + joined
            receivedFrom = label
        }
    }

    /// 받아 둔 것을 하나씩 읽어 챙길 줄만 적는 칸에 올린다. 읽은 것은 보관함에서 지운다. 그 뒤는 여느 비우기와 같다.
    private func takeInbox() async {
        let items = Inbox.items()
        guard !items.isEmpty else { return }
        editorFocused = false
        var found = 0
        for (i, url) in items.enumerated() {
            let ext = url.pathExtension.lowercased()
            receiving = items.count > 1 ? "받아 둔 것을 읽는 중 · \(i + 1)/\(items.count)" : "받아 둔 것을 읽는 중"
            if ext == "txt", let s = try? String(contentsOf: url, encoding: .utf8) {
                let got = await Brain.shared.capture(s, now: store.now)
                append(got.lines, from: "받은 글에서 찾음"); found += got.lines.count
            } else if ext == "jpg", let img = UIImage(contentsOfFile: url.path), let cg = img.cgImage {
                let ocr = await TextScan.recognize(img)
                if !ocr.isEmpty {
                    let seen = await Brain.shared.readPhoto(cg, ocr: ocr)
                    // 대화 캡처처럼 일정표가 아닌 그림은 읽은 글자를 '받은 글'로 다시 본다
                    let raw = seen.fromAI ? seen.lines : (await Brain.shared.capture(ocr.joined(separator: "\n"), now: store.now)).lines
                    // 파일 카드 · 날짜 가름줄 · 지난 날짜 같은 화면 껍데기는 일정이 아니다
                    let lines = ScreenRules.keep(raw, strict: false, now: store.now)
                    append(lines, from: "받은 사진에서 찾음"); found += lines.count
                }
            } else if AudioNotes.isAudio(url) {
                found += await hear(url, own: true)
            }
        }
        Inbox.remove(items)
        store.inboxCount = Inbox.items().count
        receiving = nil
        if found == 0 { store.show("챙길 일정이나 할 일을 못 찾았어") }
    }

    /// 녹음 파일을 기기 안에서 받아쓰고 챙길 줄을 올린다. own: 받아 둔 것(보관함)에서 부른 것 — 읽는 중 표시는 부른 쪽이 정리한다.
    @discardableResult private func hear(_ url: URL, own: Bool) async -> Int {
        editorFocused = false
        receiving = "녹음을 이 iPhone 안에서 받아쓰는 중"
        defer { if !own { receiving = nil } }
        do {
            let heard = try await AudioNotes.transcribe(url)
            let got = await Brain.shared.capture(heard, now: store.now)
            append(got.lines, from: "녹음에서 찾음")
            if got.lines.isEmpty, !own { store.show("챙길 일정이나 할 일을 못 찾았어") }
            return got.lines.count
        } catch {
            if !own { store.show(AudioNotes.message(error)) }
            return 0
        }
    }

    // MARK: 1. 쏟아내기

    private var write: some View {
        let n = BrainRules.split(text).count
        return VStack(alignment: .leading, spacing: 12) {
            topBar(title: "쏟아내기")
            if editorFocused {
                noiseLine.transition(.opacity)
            } else {
                ScaleBar(value: $noiseBefore, label: "지금 머리 소음", low: "조용함", high: "터질 듯", id: "dump.noise")
                    .transition(.opacity)
            }
            if let old = clearedText {
                noteRow("비웠어.", action: "되돌리기", id: "dump.restore") { text = old; clearedText = nil; restored = true }
            } else if restored && !text.isEmpty {
                noteRow("지난번에 쓰던 거야. 이어서 써도 돼.", action: "지우기", id: "dump.clear") {
                    clearedText = text
                    text = ""
                    restored = false
                    Haptic.tap()
                }
            }
            if let receiving {
                HStack(spacing: 10) { BreathDot(size: 9); ThinkingLine(text: receiving) }
                    .transition(.opacity)
                    .accessibilityIdentifier("dump.receiving")
            } else if let receivedFrom {
                AIBadge(text: receivedFrom).transition(.opacity)
            }
            editor
            HStack(spacing: 8) {
                squareKey("mic", label: "말로 쏟아내기", id: "dump.write.voice") { editorFocused = false; showVoice = true }
                squareKey("camera", label: "사진으로 넣기", id: "dump.write.photo") { editorFocused = false; showScan = true }
                squareKey("waveform", label: "녹음 파일에서 찾기", id: "dump.write.audio") { editorFocused = false; showAudio = true }
                Button { organize() } label: {
                    Text(n == 0 ? "한 줄 이상 써 줘" : "정리하기 · \(n)개")
                }
                .buttonStyle(FillButton(tone: .accent))
                .disabled(n == 0)
                .accessibilityIdentifier("dump.sort")
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 10)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: editorFocused)
    }

    /// 쓰는 동안엔 소음 막대를 한 줄로 접는다 (작은 화면에서 쓸 자리를 지킨다)
    private var noiseLine: some View {
        let v = noiseBefore ?? -1
        return Button { editorFocused = false } label: {
            HStack(spacing: 10) {
                Text("머리 소음").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                HStack(spacing: 2) {
                    ForEach(0...10, id: \.self) { i in
                        Capsule().fill(Ink.text.opacity(i <= v ? 0.9 : 0.14)).frame(width: 4, height: 12)
                    }
                }
                Text(noiseBefore.map { "\($0)" } ?? "—").font(Typo.num(.headline)).foregroundStyle(Ink.text)
                Spacer(minLength: 4)
                Text("바꾸기").font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.text2)
            }
            .frame(minHeight: Metric.tap)
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("지금 머리 소음 \(noiseBefore.map { "\($0)" } ?? "고르지 않음")")
        .accessibilityHint("키보드를 내리고 막대로 바꿔")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("dump.noise.line")
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(.system(.body))
            .foregroundStyle(Ink.text)
            .scrollContentBackground(.hidden)
            .focused($editorFocused)
            // 쏟아낸 날것 그대로 둔다 — 글쓰기 도구가 먼저 고쳐 쓰면 사용자의 말이 사라진다
            .writingToolsBehavior(.disabled)
            .accessibilityLabel("쏟아낼 것, 한 줄에 하나")
            .accessibilityIdentifier("dump.text")
            // 빈 종이에서만: 안내 글(눌러도 입력칸으로 통과) + 처음 쓰는 사람을 위한 예시.
            // 덧그림이라 입력칸 크기를 밀어내지 않는다 (큰 글자 + 키보드에서 칸이 작아도 화면이 밀려 올라가지 않게)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Self.placeholder)
                            .font(.system(.body))
                            .foregroundStyle(Ink.text3)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        Button {
                            text = Self.example
                            Haptic.tap()
                        } label: {
                            Text("예시로 채워 보기").font(.system(.subheadline, weight: .semibold)).underline()
                        }
                        .foregroundStyle(Ink.text2)
                        .frame(minHeight: Metric.tap)
                        .accessibilityIdentifier("dump.example")
                    }
                    .padding(.top, 8).padding(.leading, 5)
                }
            }
            .padding(10)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous))
            .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(Ink.sheet))
            .overlay(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous)
                .strokeBorder(editorFocused ? Ink.text.opacity(0.45) : Ink.rule, lineWidth: 1))
    }

    private func noteRow(_ message: String, action: String, id: String, _ run: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(message).font(.system(.footnote)).foregroundStyle(Ink.text2)
            Spacer(minLength: 4)
            Button(action, action: run)
                .font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.text)
                .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                .accessibilityIdentifier(id)
        }
    }

    private func squareKey(_ symbol: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
        }
        .buttonStyle(FillButton(tone: .quiet, height: 54, full: false))
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    // MARK: 2. 나누는 중 (AI 가 있을 때만 잠깐)

    private var thinking: some View {
        let lines = BrainRules.split(text)
        return VStack(alignment: .leading, spacing: 16) {
            topBar(title: "나누는 중")
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.prefix(6).enumerated()), id: \.offset) { _, l in
                    Text(l).font(.system(.body)).foregroundStyle(Ink.text3).lineLimit(1)
                }
                if lines.count > 6 {
                    Text("그리고 \(lines.count - 6)줄 더").font(.system(.footnote)).foregroundStyle(Ink.text3)
                }
            }
            .accessibilityHidden(true)
            ThinkingLine(text: "카드로 나누는 중이야. 기기 안에서만 처리해.")
            Spacer(minLength: 0)
            if canSkipWait {
                Button("기다리지 않고 나누기") { skipWait() }
                    .buttonStyle(FillButton(tone: .quiet))
                    .accessibilityIdentifier("dump.skip")
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 10)
        .animation(.easeInOut(duration: 0.25), value: canSkipWait)
    }

    private func organize() {
        guard step == .write else { return }
        editorFocused = false
        let raw = text
        let rules = BrainRules.organize(raw, today: store.today, now: store.now, parts: store.settings.parts)
        guard !rules.isEmpty else { return }
        // AI 가 없거나 꺼져 있으면 규칙으로 바로
        guard Brain.shared.isReady else { startSorting(rules); return }
        // 기다리는 화면 없이 바로 시작한다: 규칙 카드로 첫 장을 보여 주고, Apple Intelligence 가 다듬는 대로 **아직 안 넘긴 카드**만 바꿔 끼운다.
        organizing?.cancel()
        organizing = Task {
            var started = false
            for await list in Brain.shared.organizeStream(raw, today: store.today, now: store.now) {
                guard !Task.isCancelled else { return }
                if !started { startSorting(list); started = true } else { refine(with: list) }
            }
        }
    }

    /// 지금 보고 있는 카드와 이미 넘긴 카드는 그대로 두고, 뒤에 남은 카드만 새 목록의 것으로 바꾼다 (보던 글이 눈앞에서 바뀌지 않게)
    private func refine(with list: [DumpSuggestion]) {
        guard step == .sort, index < cards.count else { return }
        let seenPieces = Set(cards.prefix(index + 1).map(\.s.piece))
        let rest = list.filter { $0.piece < 0 || !seenPieces.contains($0.piece) }.filter { s in s.piece > (cards[index].s.piece) || s.piece < 0 }
        cards = Array(cards.prefix(index + 1)) + rest.map { Card(s: $0) }
    }

    private func skipWait() {
        guard step == .thinking else { return }
        organizing?.cancel()
        organizing = nil
        startSorting(BrainRules.organize(text, today: store.today, now: store.now, parts: store.settings.parts))
    }

    private func startSorting(_ list: [DumpSuggestion]) {
        cards = list.map { Card(s: $0) }
        index = 0
        pickingDate = false
        restored = false
        step = cards.isEmpty ? .write : .sort
    }

    // MARK: 3. 한 장씩

    private var sort: some View {
        let card = cards[safe: index]
        return VStack(spacing: 0) {
            VStack(spacing: 10) {
                sortHeader
                progressBar
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 6)
            if let card {
                // 카드는 머리줄과 칸 사이 가운데에, 넘치면 스크롤 (큰 글자). 밀어 넘길 때 화면 끝에서만 잘리도록 가로 여백은 안쪽에.
                FlowCenteredScroll {
                    VStack(alignment: .leading, spacing: 12) {
                        // 위기 줄이면 도움 먼저 — 카드 위에(큰 글자에서도 스크롤 없이 보이게), 카드 밖에(카드는 한 덩어리로 읽혀 안의 버튼은 VoiceOver 로 못 누른다)
                        if BrainRules.isCrisis(card.s.text) { crisisCalls }
                        sortCard(card)
                        if !swipeLearned { FlowSwipeHint(left: "버리기", right: "제안대로") }
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.vertical, 14)
                }
                VStack(spacing: 10) {
                    if pickingDate {
                        dateChoices(card).transition(.opacity)
                    } else {
                        bins(card).transition(.opacity)
                    }
                    acceptButton(card)
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 6)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 10)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.86), value: index)
        .animation(.easeInOut(duration: 0.2), value: pickingDate)
    }

    private var sortHeader: some View {
        HStack(spacing: 2) {
            Button { back() } label: {
                Image(systemName: "chevron.left").font(.system(.body, weight: .semibold))
                    .frame(width: Metric.tap, height: Metric.tap)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(Ink.text)
            .padding(.leading, -12)
            .accessibilityLabel(index == 0 ? "다시 쓰기" : "앞 장으로")
            .accessibilityIdentifier("sort.back")
            Text("\(min(index + 1, cards.count)) / \(cards.count)")
                .font(Typo.num(.headline)).foregroundStyle(Ink.text2)
                .fixedSize()
                .accessibilityLabel("\(cards.count)장 중 \(min(index + 1, cards.count))번째")
                .accessibilityIdentifier("sort.count")
            Spacer(minLength: 6)
            if cards.count - index > 1 {
                Button("남은 건 제안대로") { acceptAll() }
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(minHeight: Metric.tap)
                    .padding(.trailing, 10)
                    .accessibilityIdentifier("sort.all")
            }
            Button("닫기") { close() }
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                .accessibilityIdentifier("dump.close")
        }
        .padding(.top, 4)
    }

    private var progressBar: some View {
        Group {
            if cards.count <= 16 {
                HStack(spacing: 3) {
                    ForEach(cards.indices, id: \.self) { k in
                        Capsule().fill(k < index ? Ink.text : Ink.fill).frame(height: 4)
                    }
                }
            } else {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Ink.fill)
                        Capsule().fill(Ink.text).frame(width: g.size.width * CGFloat(index) / CGFloat(max(1, cards.count)))
                    }
                }
                .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private func sortCard(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                Text(card.s.text)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(shredding == nil ? 1 : 0)
                if let s = shredding { ShredText(text: s) }
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("제안").font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.text3)
                    Text(suggestionLabel(card.s)).font(.system(.subheadline, weight: .bold)).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if card.s.fromAI { AIBadge() }
                }
                Text(card.s.reason).font(.system(.subheadline)).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.fill))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(Ink.sheet))
        .overlay(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).strokeBorder(Ink.text.opacity(0.85), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sort.card")
        .modifier(FlowSwipe(
            left: .init(label: "버리기", tint: Ink.text, flies: false) { put(card.id, .drop) },
            right: .init(label: "제안대로", tint: Ink.accent) { accept(card) },
            enabled: shredding == nil,
            peek: index == 0 && !swipeLearned,
            onUse: { swipeLearned = true }))
        .id(card.id)
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .offset(y: 24).combined(with: .opacity), removal: .opacity))
    }

    /// 위기 낱말이 든 줄: 걱정 시간까지 기다리지 않고 바로 이야기할 곳
    private var crisisCalls: some View {
        HStack(spacing: 8) {
            Button { call("109") } label: { Text("109 전화") }
                .buttonStyle(FillButton(tone: .accent, height: 44))
                .accessibilityLabel("자살예방 상담 109에 전화")
                .accessibilityIdentifier("sort.call.109")
            Button { call("15770199") } label: { Text("1577-0199") }
                .buttonStyle(FillButton(tone: .line, height: 44))
                .accessibilityLabel("정신건강 위기상담 1577-0199에 전화")
        }
        .accessibilityElement(children: .contain)
    }

    private func call(_ number: String) {
        if let u = URL(string: "tel://\(number)") { openURL(u) }
    }

    private func bins(_ card: Card) -> some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow { binKey(.now, card); binKey(.date, card) }
            GridRow { binKey(.worry, card); binKey(.drop, card) }
        }
    }

    private func binKey(_ b: DumpBin, _ card: Card) -> some View {
        let suggested = card.s.bin == b
        return Button {
            if b == .date { pickingDate = true; Haptic.tick() } else { put(card.id, b) }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.binTag(b)).font(.system(.caption, weight: .semibold)).foregroundStyle(suggested ? Ink.accent : Ink.text3)
                Text(Self.binName(b)).font(.system(.headline, weight: .bold)).foregroundStyle(Ink.text)
            }
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.sheet))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(suggested ? Ink.accent : Ink.rule, lineWidth: suggested ? 2 : 1))
        }
        .buttonStyle(PressStyle())
        .disabled(shredding != nil)
        .accessibilityLabel(Self.binName(b) + (suggested ? ", 제안" : ""))
        .accessibilityHint(Self.binTag(b))
        .accessibilityIdentifier("bin.\(b.rawValue)")
    }

    private func acceptButton(_ card: Card) -> some View {
        let label = suggestionLabel(card.s)
        return Button { accept(card) } label: {
            if typeSize.isAccessibilitySize {
                // 큰 글자: 한 줄에 둘을 욱여넣지 않고 두 줄로
                VStack(spacing: 2) {
                    Text("제안대로")
                    Text(label).font(.system(.subheadline, weight: .semibold)).opacity(0.85)
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 8) {
                    Text("제안대로")
                    Spacer(minLength: 4)
                    Text(label).font(.system(.subheadline, weight: .semibold)).opacity(0.85)
                }
            }
        }
        .buttonStyle(FillButton(tone: .accent))
        .disabled(shredding != nil)
        .accessibilityLabel("제안대로, \(label)")
        .accessibilityIdentifier("sort.suggest")
    }

    private func dateChoices(_ card: Card) -> some View {
        let options = DumpPlan.options(for: card.s, parsed: parse(card.s), today: store.today)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text("언제 할래? 그때 알려 줄게.").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                Spacer(minLength: 4)
                Button("다른 칸") { pickingDate = false }
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text)
                    .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                    .accessibilityIdentifier("when.back")
            }
            FlowWrap(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                    Chip(title: o.label, on: o.suggested, id: "when.\(i)") { put(card.id, .date, when: o.when) }
                }
                Chip(title: "날짜…", on: false, id: "when.pick") { datePicker = true }
            }
        }
    }

    /// 제안에는 시각이 없다 — 글에 든 날짜·시각은 Parser 로 다시 읽는다 ("내일 3시 치과" → 내일 15:00)
    private func parse(_ s: DumpSuggestion) -> Parsed { Parser.parse(s.text, now: store.now, parts: store.settings.parts) }

    private func suggestedWhen(_ s: DumpSuggestion) -> When? { DumpPlan.suggestedWhen(s, parsed: parse(s)) }

    private func suggestionLabel(_ s: DumpSuggestion) -> String {
        guard let w = suggestedWhen(s) else { return Self.binName(s.bin) }
        return "날짜 · " + DumpPlan.label(w, time: parse(s).time, today: store.today)
    }

    static func binName(_ b: DumpBin) -> String {
        switch b { case .now: "지금"; case .date: "날짜 정하기"; case .worry: "걱정 시간"; case .drop: "버리기" }
    }
    static func binTag(_ b: DumpBin) -> String {
        switch b { case .now: "2분이면 끝"; case .date: "그때 알려 줌"; case .worry: "내 손 밖"; case .drop: "안 해도 됨" }
    }

    private func accept(_ card: Card) {
        put(card.id, card.s.bin, when: suggestedWhen(card.s))
    }

    /// 지금 보이는 카드에만 듣는다 — 두 번 눌러도 다음 카드를 건너뛰지 않게
    private func put(_ id: UUID, _ b: DumpBin, when: When? = nil) {
        guard step == .sort, shredding == nil, cards[safe: index]?.id == id else { return }
        pickingDate = false
        cards[index].bin = b
        cards[index].when = b == .date ? (when ?? .day(store.today.adding(days: 1), .morning)) : nil
        if b == .drop {
            shredding = cards[index].s.text
            Haptic.shred()
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.35 : 0.7)) {
                shredding = nil
                advance()
            }
        } else {
            Haptic.tap()
            advance()
        }
    }

    private func advance() {
        guard step == .sort else { return }
        if index + 1 >= cards.count {
            index = cards.count
            toFinish()
        } else {
            index += 1
        }
    }

    private func back() {
        guard step == .sort, shredding == nil else { return }
        pickingDate = false
        if index == 0 { step = .write; return }
        index -= 1
        cards[index].bin = nil
        cards[index].when = nil
        Haptic.tick()
    }

    private func acceptAll() {
        guard step == .sort, shredding == nil, index < cards.count else { return }
        for i in index..<cards.count where cards[i].bin == nil {
            cards[i].bin = cards[i].s.bin
            cards[i].when = suggestedWhen(cards[i].s)
        }
        index = cards.count
        Haptic.success()
        toFinish()
    }

    // MARK: 4. 끝

    private var binCounts: [DumpBin: Int] { Dictionary(grouping: cards.compactMap(\.bin), by: { $0 }).mapValues(\.count) }

    private func toFinish() {
        guard step == .sort else { return }
        commitAll()
        draft = ""
        noiseAfter = nil
        step = .finish
        loadFirstStep()
    }

    private func loadFirstStep() {
        guard let one = oneThingTitle else { return }
        let rule: String? = BrainRules.isCrisis(one) ? nil : BrainRules.firstStep(for: BrainRules.tidy(one))
        let ai = Brain.shared.isReady && BrainRules.knownStep(for: BrainRules.tidy(one)) == nil
        guard ai else { firstStep = rule; return }
        stepLoading = true
        Task {
            let got = await Brain.shared.firstStep(for: one) ?? rule
            firstStep = got
            firstStepFromAI = ai && got != nil && got != rule
            stepLoading = false
        }
    }

    private var finish: some View {
        let c = binCounts
        return VStack(spacing: 0) {
            topBar(title: "다 정했어").padding(.horizontal, Metric.gutter)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DumpFinishCard(oneThing: oneThingTitle, firstStep: firstStep, stepFromAI: firstStepFromAI,
                                   stepLoading: stepLoading, counts: c, minute: minuteOfDay(store.now),
                                   partName: store.settings.parts.part(at: minuteOfDay(store.now)).name)
                    ScaleBar(value: $noiseAfter, label: "지금 머리 소음 · 아까 \(noiseBefore ?? 0)", low: "조용함", high: "터질 듯", id: "dump.noise.after")
                    Text((c[.date] ?? 0) + (c[.worry] ?? 0) > 0
                         ? "날짜 정한 건 그때, 걱정은 걱정 시간에 알려 줄게. 머리에 안 들고 있어도 돼."
                         : "정리한 건 하루 한 장에 다 들어갔어.")
                        .font(.system(.footnote)).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 10)
            }
            .scrollBounceBehavior(.basedOnSize)
            HStack(spacing: 10) {
                Button("숨 1분") { done(then: .rest(.breath)) }
                .buttonStyle(FillButton(tone: .mint))
                .accessibilityIdentifier("finish.breath")
                Button("끝") { done() }
                    .buttonStyle(FillButton(tone: .ink))
                    .accessibilityIdentifier("finish.done")
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
    }

    // MARK: 닫기 · 저장

    private func topBar(title: String) -> some View {
        HStack {
            Text(title).font(Typo.serif(24, relativeTo: .title2)).foregroundStyle(Ink.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("닫기") { close() }
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                .accessibilityIdentifier("dump.close")
        }
        .padding(.top, 4)
    }

    /// 끝 화면이면 '끝'과 같고, 그 전이면 정한 것만 넣고 나머지는 쓰던 글로 남긴다
    private func close() {
        if step == .finish { done(); return }
        organizing?.cancel()
        let placed = cards.filter { $0.bin != nil }.count
        closeOut()
        if placed > 0 {
            store.show(draft.isEmpty ? "\(placed)개 자리를 정했어." : "\(placed)개 자리를 정했어. 남은 건 다음에 이어서 해.")
        } else if !draft.isEmpty {
            store.show("쓰던 건 남겨 둘게.")
        }
        dismiss()
    }

    /// 몇 번을 불러도 같다: 정한 카드는 한 번만 넣고, 기록도 한 번만, 안 정한 줄은 쓰던 글로
    private func closeOut() {
        commitAll()
        writeLog()
        saveDraft()
    }

    private func saveDraft() {
        switch step {
        case .write, .thinking: draft = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : text
        case .sort: draft = cards.filter { $0.bin == nil }.map(\.s.text).joined(separator: "\n")
        case .finish: draft = ""
        }
    }

    private func done(then after: FlowNext? = nil) {
        commitAll()
        let log = writeLog()
        draft = ""
        if let log {
            var msg = "머리에서 \(log.total)개를 내려놨어."
            if log.after < log.before { msg += " 소음 \(log.before) → \(log.after)." }
            if log.dropped > 0 { msg += " \(log.dropped)개는 진짜로 지웠어." }
            store.show(msg)
            Haptic.success()
        }
        if let after {
            FlowNextView.prepare(after, store: store)
            next = after
        } else {
            dismiss()
        }
    }

    /// 비우기 기록은 한 번만. 끝에서 소음을 다시 안 쟀으면 처음 값 그대로.
    @discardableResult
    private func writeLog() -> DumpLog? {
        let placed = cards.compactMap(\.bin)
        guard !logged, !placed.isEmpty else { return nil }
        logged = true
        let c = Dictionary(grouping: placed, by: { $0 }).mapValues(\.count)
        let before = noiseBefore ?? 6
        let log = DumpLog(at: store.now, before: before, after: noiseAfter ?? before,
                          now: c[.now] ?? 0, dated: c[.date] ?? 0, worry: c[.worry] ?? 0, dropped: c[.drop] ?? 0)
        store.change { $0.dumps.append(log) }
        return log
    }

    /// 자리를 정한 카드를 하루 한 장에 넣는다 (카드마다 한 번만). 지금 칸의 첫 장은 오늘의 하나로 꽂는다.
    private func commitAll() {
        let pending = cards.indices.filter { !cards[$0].committed && cards[$0].bin != nil }
        guard !pending.isEmpty else { return }
        let now = store.now
        let today = store.today
        let settings = store.settings
        let firstNow = cards.firstIndex { $0.bin == .now }
        var pinnedTitle: String?
        store.change { data in
            for (n, i) in pending.enumerated() {
                let c = cards[i]
                let created = now.addingTimeInterval(Double(n) * 0.001)
                guard var it = DumpPlan.item(for: c.s, bin: c.bin, when: c.when, today: today, now: now, settings: settings, created: created) else { continue }
                if i == firstNow {
                    for k in data.items.indices where data.items[k].day == today { data.items[k].pinned = false }
                    it.pinned = true
                    pinnedTitle = it.title
                }
                data.add(it)
            }
        }
        for i in pending { cards[i].committed = true }
        if let pinnedTitle { oneThingTitle = pinnedTitle }
        if !Launch.isUITest, pending.contains(where: { cards[$0].bin == .date || cards[$0].bin == .worry }) {
            Task { _ = await Notifier.requestPermission() }
        }
    }
}
