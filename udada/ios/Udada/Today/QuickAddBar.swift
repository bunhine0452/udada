import SwiftUI

/// 한 줄로 넣고 싶은 것이 무엇으로 읽혔는지 (칩으로 고친 것까지)
struct Draft: Equatable {
    var title: String
    var day: DayKey?
    var part: Part
    var time: Int?
    var duration: Int
    var repeatRule: RepeatRule?

    var isEmpty: Bool { title.trimmingCharacters(in: .whitespaces).isEmpty }

    func item(created: Date) -> Item {
        Item(title: title, day: day, part: part, time: time, duration: duration, created: created, repeatRule: repeatRule)
    }

    /// "내일 15:00 약속 · 1시간" · "오늘 낮 · 30분" · "나중에" · "매주 월·수·금 아침 · 30분, 11월 16일부터"
    func summary(today: DayKey) -> String {
        guard let day else { return "나중에" }
        var when = repeatRule.map { "\($0.label) " } ?? "\(Fmt.day(day, today: today)) "
        when += time.map { "\(Fmt.hm($0)) 약속" } ?? part.name
        var s = when + " · " + Fmt.dur(duration)
        if repeatRule != nil && day != today { s += ", \(day.m)월 \(day.d)일부터" }
        return s
    }
}

/// 칩으로 고른 것 (없으면 글에서 읽은 것)
struct DraftChips: Equatable {
    enum DayPick: Equatable { case day(DayKey), later }
    var day: DayPick?
    var part: Part?
    var duration: Int?
}

enum DraftMaker {
    static func make(_ text: String, chips: DraftChips, selected: DayKey, now: Date, settings: Settings, calendar: Calendar = .current) -> Draft {
        let p = Parser.parse(text, now: now, parts: settings.parts, calendar: calendar)
        let today = DayKey(now, calendar: calendar)
        let later = chips.day == .later || (chips.day == nil && p.later)
        var day: DayKey?
        if !later {
            if case .day(let k) = chips.day { day = k } else { day = p.day ?? selected }
        }
        let time = later || chips.part != nil ? nil : p.time
        let current = settings.parts.part(at: minuteOfDay(now, calendar: calendar))
        let part = time.map { settings.parts.part(at: $0) } ?? chips.part ?? p.part ?? (day == today ? current : .afternoon)
        let duration = chips.duration ?? p.duration ?? (time != nil ? 60 : settings.defaultDuration)
        return Draft(title: p.title, day: day, part: part, time: time, duration: duration, repeatRule: later ? nil : p.repeatRule)
    }
}

/// 딥링크(udada://add)는 화면이 생기기 전에 올 수도 있다 — 마지막으로 받은 요청 번호를 기억해 한 번만 받는다
@MainActor private enum AddRequests { static var handled = 0 }

/// 화면 맨 아래 한 줄: 적고 엔터. 키보드는 그대로 남아 이어서 적을 수 있다.
/// 여러 줄을 붙여 넣으면 줄마다 하나씩 들어간다 (엔터 한 번은 '넣기').
struct QuickAddBar: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let day: DayKey
    var focused: FocusState<Bool>.Binding
    @Binding var presetPart: Part?
    /// 딥링크 · 단축어의 '넣기 줄 열기'를 받는 줄 (오늘 탭 것 하나만)
    var handlesRequests = false

    @State private var text = ""
    @State private var chips = DraftChips()
    @State private var pickingDate = false
    @State private var pickedDate = Date()
    /// Apple Intelligence 판 (말로 · 사진으로 · 물어보기 · 붙여넣기)
    @State private var showAI = false
    /// 한 줄에 여러 일이 있을 때 나눈 카드 (규칙이 먼저, 모델이 다듬는 대로 바뀐다)
    @State private var cards: [DumpSuggestion] = []
    /// 여러 일로 읽혔지만 한 줄로 넣겠다고 했다
    @State private var oneLine = false

    private var lines: [String] { Parser.split(text) }
    private var draft: Draft { DraftMaker.make(text, chips: chips, selected: day, now: store.now, settings: store.settings) }
    private var open: Bool { focused.wrappedValue || !text.isEmpty }
    private var canAdd: Bool { !(lines.isEmpty || (lines.count == 1 && draft.isEmpty)) }
    /// 약속을 묻는 글을 붙여 넣었으면 넣지 않고 내 일정을 보고 답장을 쓴다
    private var offered: Bool { lines.count == 1 && ReplyRules.looksLikeOffer(lines[0], now: store.now) }
    /// 한 주를 풀어 달라는 말이면 넣지 않고 옮길 안을 보여 준다
    private var relieving: Bool { lines.count == 1 && ReplanRules.looksLikeReplan(lines[0]) }
    /// 물어보는 말이면 넣지 않고 찾는다
    private var asking: Bool { lines.count == 1 && !offered && CommandRules.isQuestion(lines[0]) }
    /// 한 줄에 일이 여럿이면("엄마한테 전화하고 보고서 쓰고…") 나눠서 넣는다. 칩을 골랐거나 시키는 말이면 아니다.
    private var multi: Bool {
        guard lines.count == 1, !oneLine, !asking, !relieving, !offered, chips == DraftChips(), !CommandRules.looksLikeCommand(lines[0]) else { return false }
        return BrainRules.split(lines[0]).count >= 2
    }
    private var shownCards: [DumpSuggestion] {
        cards.isEmpty ? BrainRules.organize(text, today: store.today, now: store.now, parts: store.settings.parts) : cards
    }

    var body: some View {
        VStack(spacing: 10) {
            if open { panel.transition(.move(edge: .bottom).combined(with: .opacity)) }
            HStack(alignment: .bottom, spacing: 8) {
                aiButton
                field
                if open {
                    Button(offered ? "답장" : relieving ? "풀기" : asking ? "찾기" : "넣기", action: submit)
                        .buttonStyle(FillButton(tone: .ink, height: 50, full: false))
                        .fixedSize()
                        .disabled(!canAdd)
                        .accessibilityIdentifier("add.go")
                } else {
                    Button { store.cover = .rest } label: {
                        // 큰 글자에서는 글자 대신 바람 표시만 — 적는 칸이 좁아지지 않게
                        if typeSize.isAccessibilitySize {
                            Label("식히기", systemImage: "wind").labelStyle(.iconOnly)
                        } else {
                            Label("식히기", systemImage: "wind").labelStyle(.titleOnly)
                        }
                    }
                    .buttonStyle(FillButton(tone: .mint, height: 50, full: false))
                    .fixedSize()
                    .accessibilityHint("1분 숨, 3분 멀리 보기, 10분 걷기 중 하나")
                    .accessibilityIdentifier("rest.open")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Ink.sheet.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Hairline() }
        .animation(.spring(response: 0.3, dampingFraction: 0.88), value: open)
        .onChange(of: presetPart) { _, p in
            if let p { chips.part = p; chips.day = .day(day); presetPart = nil }
        }
        .task(id: multi ? text : "") {
            cards = []
            guard multi else { return }
            // 치는 동안에는 기다렸다가, 멈추면 모델이 다듬은 카드를 흘려 받는다
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            for await c in Brain.shared.organizeStream(text, today: store.today, now: store.now) {
                guard !Task.isCancelled else { return }
                withAnimation(Motion.soft) { cards = c }
            }
        }
        .onChange(of: text.isEmpty) { _, empty in if empty { oneLine = false } }
        .sheet(isPresented: $showAI) { AIPanel().environment(store) }
        .onAppear { if handlesRequests { takeRequest(afterAppear: true) } }
        .onChange(of: store.addFocusRequest) { _, _ in if handlesRequests { takeRequest(afterAppear: false) } }
        .sheet(isPresented: $pickingDate) {
            NavigationStack {
                DatePicker("날짜", selection: $pickedDate, in: store.today.date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Ink.accent)
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .navigationTitle("어느 날?")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("고르기") { chips.day = .day(DayKey(pickedDate)); pickingDate = false; focused.wrappedValue = true }
                        }
                        ToolbarItem(placement: .cancellationAction) { Button("닫기") { pickingDate = false } }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Ink.sheet)
        }
    }

    // MARK: Apple Intelligence 버튼

    private var aiButton: some View {
        Button {
            Haptic.tick()
            focused.wrappedValue = false
            showAI = true
        } label: {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Ink.accent)
                .frame(width: 50, height: 50)
                .background(RoundedRectangle(cornerRadius: Metric.radiusButton, style: .continuous).fill(Ink.accentSoft))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Apple Intelligence로 하기")
        .accessibilityHint("말로 쏟아내기, 사진에서 넣기, 물어보거나 시키기")
        .accessibilityIdentifier("ai.open")
    }

    // MARK: 입력칸

    private var field: some View {
        HStack(alignment: .center, spacing: 0) {
            // 세로로 자라는 칸: 한 줄 칸(UITextField)은 붙여 넣은 줄바꿈을 띄어쓰기로 바꿔 여러 줄이 한 항목이 된다.
            // 엔터 한 번은 아래 onChange 에서 '넣기'로 바꾼다 — 키보드가 내려갔다 올라오지 않고 그대로 이어 적는다.
            TextField("", text: $text, prompt: Text(typeSize.isAccessibilitySize ? "한 줄로 적기" : "적기 · 예) 내일 3시 치과").foregroundStyle(Ink.text3), axis: .vertical)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Ink.text)
                .lineLimit(1...4)
                .focused(focused)
                .submitLabel(.done)
                .onSubmit(submit)
                .onChange(of: text) { old, new in returnTyped(old: old, new: new) }
                .padding(.leading, 14)
                .padding(.trailing, text.isEmpty ? 14 : 4)
                .padding(.vertical, 13)
                .accessibilityLabel("할 일이나 일정 한 줄로 적기")
                .accessibilityIdentifier("add.field")
            if !text.isEmpty {
                Button {
                    text = ""
                    chips = DraftChips()
                    Haptic.tick()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Ink.text3)
                        .frame(width: Metric.tap, height: Metric.tap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("지우기")
                .accessibilityIdentifier("add.clear")
            }
        }
        .frame(minHeight: 50)
        .background(RoundedRectangle(cornerRadius: Metric.radiusButton, style: .continuous).fill(Ink.fill))
    }

    /// 엔터 한 번(줄바꿈 하나만 더해짐)은 넣기. 여러 줄을 붙여 넣은 것은 그대로 둔다.
    private func returnTyped(old: String, new: String) {
        guard new.contains("\n") else { return }
        let added = new.filter { $0 == "\n" }.count - old.filter { $0 == "\n" }.count
        guard added == 1, new.filter({ $0 != "\n" }) == old.filter({ $0 != "\n" }) else { return }
        // 친 자리의 줄바꿈 하나만 뺀다 (전에 붙여 넣은 줄들은 남긴다): 처음 달라지는 자리가 그 줄바꿈이다
        var t = new
        var o = old.startIndex, n = t.startIndex
        while o < old.endIndex && old[o] == t[n] { o = old.index(after: o); n = t.index(after: n) }
        t.remove(at: n)
        text = t
        submit()
    }

    private func takeRequest(afterAppear: Bool) {
        guard store.addFocusRequest != AddRequests.handled else { return }
        AddRequests.handled = store.addFocusRequest
        if !store.pendingAddText.isEmpty { text = store.pendingAddText; store.pendingAddText = "" }
        if afterAppear {
            // 화면이 막 생겼을 때는 칸이 창에 붙은 뒤에 커서를 준다
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focused.wrappedValue = true }
        } else {
            focused.wrappedValue = true
        }
    }

    // MARK: 칩 판

    @ViewBuilder private var panel: some View {
        if multi { splitPanel } else { chipPanel }
    }

    /// 한 줄에 여러 일: 나눈 카드와 어디로 가는지를 넣기 전에 보여 준다
    private var splitPanel: some View {
        let out = SiriWork.sort(shownCards, today: store.today, now: store.now, settings: store.settings)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if shownCards.contains(where: \.fromAI) { AIBadge() }
                Text("\(out.rows.count)개로 나눠 넣을게").font(.system(.subheadline, weight: .bold)).foregroundStyle(Ink.text)
                Spacer(minLength: 4)
                Button("한 줄로") { Haptic.tick(); oneLine = true }
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                    .frame(minHeight: Metric.tap)
                    .accessibilityHint("나누지 않고 적은 그대로 한 줄로 넣기")
                    .accessibilityIdentifier("add.oneline")
            }
            ForEach(out.rows.prefix(4), id: \.self) { r in
                HStack(spacing: 8) {
                    Text(r.title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(r.tag).font(.system(.caption, weight: .bold)).foregroundStyle(Ink.accent)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.accentSoft))
                        .fixedSize()
                }
                .frame(minHeight: 30)
                .transition(Motion.row)
            }
            if out.rows.count > 4 { Text("그리고 \(out.rows.count - 4)개 더").font(Typo.meta).foregroundStyle(Ink.text3) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("add.split")
    }

    private var chipPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                preview
                Button {
                    focused.wrappedValue = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Ink.text2)
                        .frame(width: Metric.tap, height: Metric.tap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("키보드 내리기")
                .accessibilityIdentifier("add.dismiss")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    rowLabel("날")
                    Chip(title: "오늘", on: draft.day == store.today) { chips.day = .day(store.today) }
                    Chip(title: "내일", on: draft.day == store.today.adding(days: 1)) { chips.day = .day(store.today.adding(days: 1)) }
                    Chip(title: "모레", on: draft.day == store.today.adding(days: 2)) { chips.day = .day(store.today.adding(days: 2)) }
                    Chip(title: "나중에", on: draft.day == nil, id: "chip.later") { chips.day = .later }
                    Chip(title: otherDayLabel, on: isOtherDay, id: "chip.otherday") { pickedDate = (draft.day ?? store.today).date(); pickingDate = true }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    rowLabel("때")
                    ForEach(Part.allCases) { p in
                        Chip(title: p.name, on: draft.day != nil && draft.time == nil && draft.part == p, id: "chip.part.\(p.rawValue)") {
                            chips.part = p
                            if chips.day == .later { chips.day = nil }
                        }
                    }
                    Rectangle().fill(Ink.rule).frame(width: 1, height: 24).padding(.horizontal, 4)
                    ForEach([15, 30, 60, 120], id: \.self) { m in
                        Chip(title: Fmt.dur(m), on: draft.duration == m) { chips.duration = m }
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
        }
    }

    private var preview: some View {
        Group {
            if lines.count > 1 {
                Text("\(lines.count)개를 한 번에 넣어. 각 줄을 따로 읽어.")
            } else if draft.isEmpty {
                Text("그냥 적고 넣기. 시각을 쓰면 약속이 돼.")
            } else if offered {
                Text("약속을 묻는 글이네. 내 일정을 보고 답장을 써 줄게.")
            } else if relieving {
                Text("한 주를 풀어 달라는 말이네. 옮길 안을 먼저 보여 줄게.")
            } else if asking {
                Text("물어보는 말이네. 넣지 않고 내 기록에서 찾아 줄게.")
            } else {
                Text("\(Text(draft.title).fontWeight(.bold).foregroundStyle(Ink.text))  →  \(draft.summary(today: store.today))")
            }
        }
        .font(.system(.subheadline))
        .foregroundStyle(Ink.text2)
        .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previewLabel)
        .accessibilityIdentifier("add.preview")
    }

    private var previewLabel: String {
        if lines.count > 1 { return "\(lines.count)개를 한 번에 넣어. 각 줄을 따로 읽어." }
        if offered { return "약속을 묻는 글이네. 내 일정을 보고 답장을 써 줄게." }
        if relieving { return "한 주를 풀어 달라는 말이네. 옮길 안을 먼저 보여 줄게." }
        if asking { return "물어보는 말이네. 넣지 않고 내 기록에서 찾아 줄게." }
        if draft.isEmpty { return "그냥 적고 넣기. 시각을 쓰면 약속이 돼." }
        return "\(draft.title), \(draft.summary(today: store.today))"
    }

    private func rowLabel(_ s: String) -> some View {
        Text(s).font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.text3)
            .frame(minWidth: 24, alignment: .leading)
            .accessibilityHidden(true)
    }

    private var isOtherDay: Bool {
        guard let d = draft.day else { return false }
        return store.today.days(to: d) > 2 || d < store.today
    }
    private var otherDayLabel: String {
        guard isOtherDay, let d = draft.day else { return "날짜…" }
        return "\(d.m)/\(d.d)"
    }

    // MARK: 넣기

    private func submit() {
        let ls = lines
        guard !ls.isEmpty else { return }
        // "치과 내일로 미뤄 줘"처럼 이미 있는 일을 바꾸라는 말이면 새 할 일로 넣지 않고 '말로 하기'로 보낸다 (미리 보여 주고 적용)
        if ls.count == 1, CommandRules.looksLikeCommand(ls[0]),
           CommandRules.plan(ls[0], data: store.data, now: store.now).steps.contains(where: { $0.kind != .add && $0.ok }) {
            store.pendingAddText = ls[0]
            text = ""
            focused.wrappedValue = false
            store.cover = .find
            return
        }
        // 약속을 묻는 글이면 답장 화면으로
        if offered {
            let q = ls[0]
            text = ""
            focused.wrappedValue = false
            store.reply = ReplyRequest(text: q)
            return
        }
        // 한 주를 풀어 달라는 말이면 그 화면으로
        if relieving {
            let q = ls[0]
            text = ""
            focused.wrappedValue = false
            store.replan = ReplanRequest(text: q)
            return
        }
        // 물음이면 찾기로
        if asking {
            store.pendingAddText = ls[0]
            text = ""
            focused.wrappedValue = false
            store.cover = .find
            return
        }
        // 한 줄에 여러 일이면 나눈 카드대로 넣는다 (되돌리기 한 번)
        if multi {
            let out = SiriWork.sort(shownCards, today: store.today, now: store.now, settings: store.settings)
            guard !out.items.isEmpty else { return }
            store.change(undo: "\(out.items.count)개로 나눠 넣었어") { d in out.items.forEach { d.add($0) } }
            Haptic.success()
            if out.items.contains(where: { $0.time != nil }) { Task { _ = await Notifier.requestPermission() } }
            text = ""
            chips = DraftChips()
            focused.wrappedValue = true
            return
        }
        let now = store.now
        var added: [Draft] = []
        if ls.count == 1 {
            let d = DraftMaker.make(ls[0], chips: chips, selected: day, now: now, settings: store.settings)
            guard !d.isEmpty else { return }
            added = [d]
        } else {
            added = ls.map { DraftMaker.make($0, chips: chips, selected: day, now: now, settings: store.settings) }.filter { !$0.isEmpty }
        }
        guard !added.isEmpty else { return }
        let today = store.today
        let msg = added.count == 1 ? "넣었어 · \(added[0].summary(today: today))" : "\(added.count)개 넣었어"
        store.change(undo: msg) { data in
            for (i, d) in added.enumerated() { data.add(d.item(created: now.addingTimeInterval(Double(i) * 0.001))) }
        }
        Haptic.success()
        if added.contains(where: { $0.time != nil }) { Task { _ = await Notifier.requestPermission() } }
        text = ""
        chips = DraftChips()
        focused.wrappedValue = true
    }
}
