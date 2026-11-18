import SwiftUI

/// 집중: 시계는 위로 센다(재촉하지 않는다). 예상과 실제를 남겨 다음 길이를 넉넉히 잡게 한다 (계획 오류 — Kruger & Evans 2004).
/// 첫 동작 한 줄은 시작을 막는 '싫음'을 줄인다 (Steel 2007).
/// 예상은 막대 끝의 눈금 하나. 넘으면 눈금 너머로 먹색이 이어질 뿐 — 빨강도 경고도 없다.
struct FocusView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: Entry?

    @State private var title = ""
    @State private var planned = 30
    @State private var started: Date?
    @State private var firstStep: String?
    @State private var stepFromAI = false
    @State private var stepLoading = false
    @State private var closed = false
    @State private var result: FocusLog?
    @State private var left = false
    @State private var didSetUp = false
    @State private var next: FlowNext?

    var body: some View {
        ZStack {
            Ink.ground.ignoresSafeArea()
            if let next {
                FlowNextView(next: next).transition(.opacity)
            } else if let r = result {
                summary(r).transition(.opacity)
            } else if !didSetUp {
                Color.clear
            } else if started == nil {
                chooser
            } else {
                running
            }
        }
        .animation(.easeInOut(duration: 0.3), value: result)
        .animation(.easeInOut(duration: 0.3), value: next)
        .onAppear(perform: setUp)
        // 다른 기기(Mac)에서 끝냈으면 여기 시계도 멈춘다
        .onChange(of: store.data.activeFocus == nil) { _, gone in
            guard gone, started != nil, !closed, result == nil, next == nil else { return }
            closed = true
            LiveActivity.end()
            UIApplication.shared.isIdleTimerDisabled = false
            store.show("다른 기기에서 집중을 끝냈어")
            dismiss()
        }
    }

    // MARK: 무엇을

    private var chooser: some View {
        let todos = store.sheet(for: store.today).bands.flatMap(\.todos).filter { !$0.done }
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Button("닫기") { dismiss() }
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                    .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                    .accessibilityIdentifier("focus.close")
            }
            ScreenTitle(title: "무엇에 집중할까?", sub: "하나만 고르면 시계가 위로 세기 시작해.")
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(todos) { e in
                        Button { begin(with: e) } label: {
                            HStack(spacing: 12) {
                                Text(e.title).font(Typo.row).foregroundStyle(Ink.text)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Text("\(e.part.name) · \(Fmt.dur(e.duration))")
                                    .font(Typo.num(.subheadline, .semibold)).foregroundStyle(Ink.text2)
                                    .fixedSize()
                            }
                            .frame(minHeight: Metric.rowMin)
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("focus.pick.\(e.title)")
                        Hairline()
                    }
                    if todos.isEmpty { Hint(text: "오늘 남은 할 일이 없어. 그냥 시계만 켜도 돼.") }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            Button("이름 없이 시작") { begin(with: nil) }
                .buttonStyle(FillButton(tone: .ink))
                .accessibilityIdentifier("focus.free")
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 12)
    }

    // MARK: 하는 중

    private var running: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let s = started ?? Date()
            let spent = max(0, ctx.date.timeIntervalSince(s) * Launch.speed)
            let plan = Double(planned * 60)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Ink.accent).frame(width: 7, height: 7)
                        Text("집중 중").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.accent)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    Button("그만") { stop(finished: false) }
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                        .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                        .accessibilityIdentifier("focus.stop")
                }
                .padding(.top, 4)
                VStack(alignment: .leading, spacing: 14) {
                    Text(title.isEmpty ? "집중" : title)
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("focus.title")
                    stepCard
                }
                .padding(.top, 8)
                FlowCenteredScroll {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(clock(spent))
                            .font(Typo.num(size: 88, .bold, relativeTo: .largeTitle))
                            .foregroundStyle(Ink.text)
                            .lineLimit(1).minimumScaleFactor(0.4)
                            .accessibilityLabel("\(Int(spent / 60))분 지남")
                            .accessibilityIdentifier("focus.clock")
                        PlanBar(planned: plan, spent: spent)
                        HStack(alignment: .firstTextBaseline) {
                            Text("예상 \(Fmt.dur(planned))").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                                .accessibilityIdentifier("focus.plan")
                            Spacer(minLength: 8)
                            if spent > plan {
                                Text("\(Fmt.dur(max(1, Int((spent - plan) / 60)))) 더 · 이어서 해도 돼")
                                    .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button("식히기") { stop(finished: false, then: .rest(nil)) }
                        .buttonStyle(FillButton(tone: .mint))
                        .accessibilityIdentifier("focus.rest")
                    Button("끝냈어") { stop(finished: true) }
                        .buttonStyle(FillButton(tone: .accent))
                        .accessibilityIdentifier("focus.done")
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder private var stepCard: some View {
        if let step = firstStep {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("첫 동작").font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.text3)
                    Spacer(minLength: 4)
                    if stepFromAI { AIBadge() }
                }
                Text(step).font(.system(.headline)).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("focus.step")
        } else if stepLoading {
            ThinkingLine(text: "첫 동작 찾는 중")
        }
    }

    // MARK: 끝냈어

    private func summary(_ r: FocusLog) -> some View {
        VStack(spacing: 0) {
            FlowCenteredScroll {
                VStack(alignment: .leading, spacing: 18) {
                    Text("끝냈어.").font(Typo.serif(34, relativeTo: .largeTitle)).foregroundStyle(Ink.text)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("focus.summary")
                    Text(r.title).font(.system(.title3, weight: .semibold)).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                        compareRow("예상", minutes: r.planned, of: max(r.planned, r.spent, 1), color: Ink.text3)
                        compareRow("실제", minutes: r.spent, of: max(r.planned, r.spent, 1), color: Ink.accent)
                    }
                    Text(verdict(r)).font(.system(.body)).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Metric.gutter)
            }
            Button("닫기") { leave() }
                .buttonStyle(FillButton(tone: .ink))
                .accessibilityIdentifier("focus.summary.close")
                .padding(.horizontal, Metric.gutter)
        }
        .padding(.bottom, 12)
        .contentShape(Rectangle())
        .onTapGesture { leave() }
        .task {
            // 잠깐 보여 주고 스스로 닫힌다 (VoiceOver 면 다 읽을 시간을 더 준다). 결과는 토스트로 한 번 더.
            try? await Task.sleep(for: .seconds(UIAccessibility.isVoiceOverRunning ? 6 : 2.2))
            leave()
        }
    }

    private func compareRow(_ label: String, minutes: Int, of total: Int, color: Color) -> some View {
        GridRow {
            Text(label).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
            GeometryReader { g in
                Capsule().fill(color).frame(width: max(8, g.size.width * CGFloat(minutes) / CGFloat(total)), height: 10)
                    .frame(maxHeight: .infinity)
            }
            .frame(height: 22)
            Text(Fmt.dur(minutes)).font(Typo.num(.headline)).foregroundStyle(Ink.text)
                .gridColumnAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func verdict(_ r: FocusLog) -> String {
        let gap = r.spent - r.planned
        if abs(gap) <= max(2, r.planned / 10) { return "예상과 거의 같았어." }
        if gap < 0 { return "예상보다 \(Fmt.dur(-gap)) 일찍 끝났어." }
        return "예상보다 \(Fmt.dur(gap)) 더 걸렸어. 다음엔 조금 넉넉히 잡아도 돼."
    }

    private func leave() {
        guard let r = result, !left else { return }
        left = true
        store.show("예상 \(Fmt.dur(r.planned)) · 실제 \(Fmt.dur(r.spent))")
        dismiss()
    }

    // MARK: 동작

    private func setUp() {
        guard !didSetUp else { return }
        defer { didSetUp = true }
        if let a = store.data.activeFocus {
            title = a.title
            planned = a.planned
            started = a.started
            loadStep()
            return
        }
        if let e = entry { begin(with: e) }
    }

    private func begin(with e: Entry?) {
        title = e?.title ?? ""
        planned = e?.duration ?? 25
        let now = Date()
        started = now
        var itemID: UUID?
        if let e {
            store.change { itemID = $0.materialize(e.source) }
        }
        let active = ActiveFocus(itemID: itemID, title: title.isEmpty ? "집중" : title, planned: planned, started: now)
        store.change { $0.activeFocus = active }
        LiveActivity.startFocus(title: active.title, started: now, planned: planned)
        UIApplication.shared.isIdleTimerDisabled = true
        Haptic.firm()
        loadStep()
    }

    /// 규칙이면 바로, AI 면 기다리는 동안 한 줄이 숨 쉰다. 'AI' 표시는 AI 가 낸 걸음에만.
    private func loadStep() {
        let t = title
        guard !t.isEmpty, t != "집중" else { return }
        let rule: String? = BrainRules.isCrisis(t) ? nil : BrainRules.firstStep(for: BrainRules.tidy(t))
        // 흔한 갈래(문서·전화·청소…)는 다듬어 둔 문장이 바로 — AI 를 기다릴 일이 없다
        guard Brain.shared.isReady, BrainRules.knownStep(for: BrainRules.tidy(t)) == nil else { firstStep = rule; return }
        stepLoading = true
        Task {
            let got = await Brain.shared.firstStep(for: t) ?? rule
            firstStep = got
            stepFromAI = got != nil && got != rule
            stepLoading = false
        }
    }

    /// 집중 기록은 한 번만. 끝냈으면 잠깐 견줘 보여 주고, 아니면 바로 닫거나 다음 화면(식히기)으로.
    private func stop(finished: Bool, then after: FlowNext? = nil) {
        guard !closed, let s = started else {
            if let after { handOff(after) } else { dismiss() }
            return
        }
        closed = true
        let spent = max(1, Int((Date().timeIntervalSince(s) * Launch.speed / 60).rounded()))
        let id = store.data.activeFocus?.itemID
        let now = store.now
        let log = FocusLog(at: s.addingTimeInterval(store.clockOffset), title: title.isEmpty ? "집중" : title, planned: planned, spent: spent, finished: finished)
        store.change { data in
            data.activeFocus = nil
            data.focus.append(log)
            if let id {
                data.update(id) { it in
                    it.spent = (it.spent ?? 0) + spent
                    if finished { it.done = true; it.doneAt = now }
                }
            }
        }
        LiveActivity.end()
        UIApplication.shared.isIdleTimerDisabled = false
        if finished {
            Haptic.success()
            result = log
            return
        }
        if let after {
            handOff(after)
        } else {
            store.show("\(Fmt.dur(spent)) 집중했어." + (id != nil ? " 할 일은 그대로 있어." : ""))
            dismiss()
        }
    }

    private func handOff(_ after: FlowNext) {
        FlowNextView.prepare(after, store: store)
        next = after
    }

    private func clock(_ s: Double) -> String {
        let n = Int(s)
        return n >= 3600 ? String(format: "%d:%02d:%02d", n / 3600, (n / 60) % 60, n % 60) : String(format: "%d:%02d", n / 60, n % 60)
    }
}

/// 예상과 실제를 한 줄에: 예상 끝에 눈금 하나. 넘치면 막대가 줄어들어 눈금 너머로 먹색이 이어진다.
private struct PlanBar: View {
    var planned: Double
    var spent: Double

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let span = max(planned, spent, 1)
            let planX = w * planned / span
            let fill = w * min(spent, planned) / span
            let over = w * max(0, spent - planned) / span
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.fill).frame(width: planX, height: 8)
                Capsule().fill(Ink.accent).frame(width: spent > 0 ? max(8, fill) : 0, height: 8)
                if over > 0 {
                    Capsule().fill(Ink.text2).frame(width: over, height: 8).offset(x: planX)
                }
                Rectangle().fill(Ink.text).frame(width: 2, height: 18).offset(x: min(w - 2, max(0, planX - 1)))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}
