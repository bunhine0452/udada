import SwiftUI
import UIKit

/// 말로 쏟아내기: 말하는 동안 말이 끝난 조각마다 카드가 한 장씩 떨어진다. [다 말했어] 를 누르면 글과 그 카드들을 넘긴다.
/// 카드는 규칙이 바로 만들고(기다림 없음), Apple Intelligence 가 한 장씩 칸을 다시 본다. 열리면 바로 듣기 시작. 녹음은 저장하지 않는다.
struct VoiceDumpView: View {
    var onDone: (String, [DumpSuggestion]) -> Void
    var onCancel: () -> Void

    init(onDone: @escaping (String, [DumpSuggestion]) -> Void, onCancel: @escaping () -> Void) {
        self.onDone = onDone
        self.onCancel = onCancel
    }

    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 떨어진 카드 · 아직 말하는 중인 끝 조각
    @State private var cards: [LiveCard] = []
    @State private var pending = ""
    /// 한동안 조용하면 끝 조각도 끝난 말로 친다
    @State private var quiet = false
    /// 확인용(-udSay <글>): 마이크 대신 그 글을 한 낱말씩 말한 것처럼 흘린다 (시뮬레이터 · UI 테스트)
    @State private var spoken = ""
    @State private var sayDone = false
    private static let script: String? = {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-udSay"), i + 1 < a.count else { return nil }
        return a[i + 1].precomposedStringWithCanonicalMapping
    }()

    private var heard: String { Self.script != nil ? spoken : voice.text }
    private var listening: Bool { Self.script != nil ? !sayDone : voice.state == .listening }

    @State private var voice = VoiceInput()
    @State private var finishing = false
    @State private var history: [Double] = Array(repeating: 0, count: 18)
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScreenTitle(title: "말로 쏟아내기", sub: "생각나는 대로 말해. 순서 상관없어.")
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 12)
            Hairline().padding(.horizontal, Metric.gutter)
            transcript
            Hairline().padding(.horizontal, Metric.gutter)
            controls
        }
        .background(Ink.ground.ignoresSafeArea())
        .task {
            guard let script = Self.script else { await voice.start(); return }
            for word in script.split(separator: " ") {
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }
                spoken += (spoken.isEmpty ? "" : " ") + word
            }
            sayDone = true
        }
        .onChange(of: heard) { _, _ in quiet = false; settle() }
        .onChange(of: listening) { _, _ in settle() }
        // 1.6초 조용하면 끝 조각도 카드로
        .task(id: heard) {
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled, !heard.isEmpty else { return }
            quiet = true
            settle()
        }
        // 떨어진 카드를 Apple Intelligence 가 한 장씩 다시 본다
        .task(id: cards.map(\.source)) { await refine() }
        .onDisappear { voice.cancel() }
        // 권한 창이 뜨면 .inactive 가 되므로, 앱을 떠날 때만 멈춘다 (글은 남는다)
        .onChange(of: phase) { _, p in if p == .background { voice.stop() } }
        .onChange(of: voice.level) { _, v in
            history.removeFirst()
            history.append(v)
        }
        .onChange(of: voice.state) { _, s in
            if s == .listening { Haptic.soft() }
            if s != .listening { history = Array(repeating: 0, count: history.count) }
        }
    }

    // MARK: - 위

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                voice.cancel()
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Ink.text2)
                    .frame(width: Metric.tap, height: Metric.tap)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("닫기")
            .accessibilityIdentifier("voice.close")
        }
        .padding(.horizontal, Metric.gutter - 10)
        .padding(.top, 4)
    }

    // MARK: - 받아쓴 글

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch voice.state {
                    case .denied(let why): problem(why, settings: true)
                    case .unavailable(let why): problem(why, settings: false)
                    default: EmptyView()
                    }
                    if heard.isEmpty {
                        Text(placeholder)
                            .font(.system(.title2))
                            .foregroundStyle(Ink.text3)
                    } else {
                        // 방금 들은 말 (끝 세 줄만 — 카드가 주인공이다)
                        Text(heard)
                            .font(.system(.subheadline))
                            .foregroundStyle(Ink.text3)
                            .lineLimit(3)
                            .truncationMode(.head)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("voice.text")
                        ForEach(Array(cards.enumerated()), id: \.element.id) { i, c in
                            cardRow(c)
                                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: -18)).combined(with: .scale(scale: 0.96, anchor: .top)), removal: .opacity))
                                .accessibilityIdentifier("voice.card.\(i)")
                        }
                        if !pending.isEmpty {
                            HStack(spacing: 10) {
                                BreathDot(size: 8)
                                Text(pending).font(.system(.body)).foregroundStyle(Ink.text2).lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: Metric.rowMin, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: Metric.radiusBlock, style: .continuous).strokeBorder(Ink.rule, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                            .accessibilityLabel("말하는 중: \(pending)")
                            .accessibilityIdentifier("voice.pending")
                        }
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 16)
                .animation(reduceMotion ? nil : Motion.soft, value: cards.map(\.id))
            }
            .scrollDismissesKeyboard(.never)
            .onChange(of: heard) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("end", anchor: .bottom) }
            }
            .onChange(of: cards.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("end", anchor: .bottom) }
            }
        }
    }

    /// 떨어진 카드 한 장: 다듬은 한 줄 + 어디로 갈지
    private func cardRow(_ c: LiveCard) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(c.s.text).font(Typo.row).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            if c.s.fromAI {
                Image(systemName: "apple.intelligence").font(.system(.caption2, weight: .semibold)).foregroundStyle(Ink.accent)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
                    .accessibilityLabel("Apple Intelligence가 다시 봄")
            }
            Text(tag(c.s)).font(.system(.caption, weight: .bold)).foregroundStyle(Ink.accent)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.accentSoft))
                .fixedSize()
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: Metric.rowMin, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metric.radiusBlock, style: .continuous).fill(Ink.sheet))
        .accessibilityElement(children: .combine)
    }

    /// "지금" · "내일 아침" · "걱정 시간" · "버리기"
    private func tag(_ s: DumpSuggestion) -> String {
        switch s.bin {
        case .now: return "지금"
        case .worry: return "걱정 시간"
        case .drop: return "버리기"
        case .date:
            let p = Parser.parse(s.text, now: store.now, parts: store.settings.parts)
            guard let w = DumpPlan.suggestedWhen(s, parsed: p) else { return "날짜 정하기" }
            return DumpPlan.label(w, time: p.time, today: store.today)
        }
    }

    /// 받아쓴 글이 바뀔 때마다: 말이 끝난 조각만 카드로 (같은 조각의 카드는 그대로 둔다)
    private func settle() {
        let (settled, tail) = LiveDump.cut(heard, open: listening && !quiet)
        let next = LiveDump.reconcile(cards, settled: settled) { BrainRules.suggest($0, today: store.today, now: store.now, parts: store.settings.parts) }
        if next.count > cards.count { Haptic.soft() }
        cards = next
        pending = tail
    }

    /// 아직 안 본 카드를 차례로 Apple Intelligence 에 보인다 (칸만 다시 고른다 — 글은 그대로). 그 사이 조각이 바뀌었으면 버린다.
    private func refine() async {
        guard Brain.shared.isReady else { return }
        for c in cards where !c.refined {
            guard !Task.isCancelled else { return }
            let s = await Brain.shared.suggest(for: c.source, today: store.today, now: store.now)
            guard !Task.isCancelled, let i = cards.firstIndex(where: { $0.id == c.id && $0.source == c.source }) else { continue }
            var better = s
            better.piece = cards[i].s.piece
            withAnimation(reduceMotion ? nil : Motion.soft) { cards[i].s = better; cards[i].refined = true }
        }
    }

    private var placeholder: String {
        switch voice.state {
        case .asking: voice.preparing != nil ? "한국어 받아쓰기를 준비하고 있어." : "마이크를 켜는 중이야."
        case .listening: "듣고 있어. 말해 봐."
        default: "아래 키를 누르고 말해 봐."
        }
    }

    private func problem(_ why: String, settings: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(why)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            if settings {
                Text("마이크와 음성 인식을 켜야 말을 글자로 바꿀 수 있어.")
                    .font(Typo.meta)
                    .foregroundStyle(Ink.text2)
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(FillButton(tone: .line, height: 46, full: false))
                .accessibilityIdentifier("voice.settings")
            } else {
                Button("다시 해 보기") { Task { await voice.start() } }
                    .buttonStyle(FillButton(tone: .line, height: 46, full: false))
                    .accessibilityIdentifier("voice.retry")
            }
        }
        .card()
    }

    // MARK: - 아래: 막대 · 마이크 키 · 다시 / 다 말했어

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(note)
                    .font(Typo.meta)
                    .foregroundStyle(Ink.text3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if voice.state == .listening {
                    Text(clock)
                        .font(Typo.num(.subheadline, .semibold))
                        .foregroundStyle(remaining < 30 ? Ink.text : Ink.text3)
                        .accessibilityLabel("남은 시간 \(Int(remaining))초")
                }
            }
            HStack(spacing: 12) {
                micKey
                meterBars
            }
            HStack(spacing: 10) {
                Button("다시") { again() }
                    .buttonStyle(FillButton(tone: .quiet, full: false))
                    .frame(minWidth: 96)
                    .disabled(heard.isEmpty || finishing)
                    .accessibilityHint("받아쓴 글을 지우고 처음부터 말해")
                    .accessibilityIdentifier("voice.again")
                Button(finishing ? "정리하는 중…" : cards.isEmpty ? "다 말했어" : "다 말했어 · 카드 \(cards.count + (pending.isEmpty ? 0 : 1))장") { done() }
                    .buttonStyle(FillButton(tone: listening ? .ink : .accent))
                    .disabled(heard.isEmpty || finishing)
                    .opacity(heard.isEmpty ? 0.5 : 1)
                    .accessibilityIdentifier("voice.done")
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var note: String {
        if voice.stoppedByLimit { return "3분이 지나서 멈췄어. 키를 누르면 이어서 들어." }
        if voice.usesServer { return "이 기기는 애플 서버에서 글자로 바꿔. 녹음은 저장하지 않아." }
        return "녹음은 저장하지 않아. 글자는 기기 안에서 바뀌어."
    }

    private var remaining: TimeInterval { max(0, VoiceInput.limit - voice.elapsed) }
    private var clock: String {
        let r = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", r / 60, r % 60)
    }

    private var micKey: some View {
        let listening = voice.state == .listening
        let busy = voice.state == .asking
        let title: String = {
            if busy { return voice.preparing.map { "준비 중 \(Int($0 * 100))%" } ?? "준비 중" }
            if listening { return "잠깐 멈추기" }
            return voice.text.isEmpty ? "눌러서 말하기" : "이어 말하기"
        }()
        return Button {
            Haptic.tap()
            if listening { voice.stop() } else { Task { await voice.start() } }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: listening ? "pause.fill" : "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(Typo.button)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(listening ? Ink.accentText : Ink.blockText)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(listening ? Ink.accent : Ink.block))
            .contentShape(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .disabled(busy || finishing)
        .accessibilityLabel(listening ? "멈추기" : "말하기")
        .accessibilityValue(listening ? "듣는 중" : "멈춤")
        .accessibilityIdentifier("voice.mic")
    }

    /// 소리 크기 막대 (최근 값이 오른쪽). 빛 번짐 없이 먹색 막대만.
    private var meterBars: some View {
        let listening = voice.state == .listening
        return HStack(alignment: .center, spacing: 3) {
            ForEach(history.indices, id: \.self) { i in
                Capsule()
                    .fill(listening ? Ink.text : Ink.rule)
                    .frame(width: 3, height: 6 + 44 * history[i])
            }
        }
        .frame(width: 18 * 6, height: 72)
        .animation(.linear(duration: 0.08), value: history)
        .accessibilityHidden(true)
    }

    // MARK: - 동작

    private func again() {
        Haptic.tick()
        let wasListening = voice.state == .listening
        voice.cancel()
        cards = []; pending = ""; quiet = false
        if wasListening { Task { await voice.start() } }
    }

    private func done() {
        finishing = true
        Task {
            let text = (Self.script != nil ? spoken : await voice.finish()).trimmingCharacters(in: .whitespacesAndNewlines)
            finishing = false
            guard !text.isEmpty else { return }
            // 마지막 글로 한 번 더 맞춘다 (끝 조각까지 카드로). 이미 다듬은 카드는 그대로 간다.
            let final = LiveDump.reconcile(cards, settled: LiveDump.cut(text, open: false).settled) {
                BrainRules.suggest($0, today: store.today, now: store.now, parts: store.settings.parts)
            }
            Haptic.success()
            onDone(text, final.enumerated().map { i, c in var s = c.s; s.piece = i; return s })
        }
    }
}
