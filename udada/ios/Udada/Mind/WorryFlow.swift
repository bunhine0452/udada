import SwiftUI

/// 걱정 시간: 하루 한 번, 10분만. 걱정을 정해진 시간으로 미루면 걱정·불안·불면이 줄었다 (McGowan & Behar 2013).
/// 하나씩 보고 — 내 손 안에 할 것이 있으면 할 일로, 없으면 내려놓거나 다음에 다시.
/// 답은 기다리지 않아도 된다(버튼은 늘 눌린다). 위기 낱말이면 AI 를 부르지 않고 바로 상담 전화를 보여 준다.
/// 보이는 문장은 늘 정해 둔 규칙 문장이고 AI 는 '내 손 안인지'와 작은 걸음만 고른다 — 그래서 'AI' 표시를 붙이지 않는다.
struct WorryFlow: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var queue: [Item] = []
    @State private var index = 0
    @State private var advice: [UUID: WorryAdvice] = [:]
    @State private var loading: Set<UUID> = []
    @State private var start = Date()
    @State private var shredding: String?
    @State private var counts = (task: 0, letGo: 0, keep: 0)
    @State private var started = false
    @State private var timeUp = false

    var body: some View {
        ZStack {
            Ink.ground.ignoresSafeArea()
            if !started {
                Color.clear
            } else if let w = queue[safe: index] {
                card(w)
            } else {
                ending.transition(.opacity)
            }
        }
        .onAppear {
            guard !started else { return }
            queue = store.data.worries
            start = Date()
            started = true
            loadAdvice(0)
            loadAdvice(1)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.86), value: index)
    }

    /// 답 하나 미리 받아 두기 (다음 장까지). 규칙이면 바로, AI 면 기다리는 동안에도 버튼은 눌린다.
    private func loadAdvice(_ i: Int) {
        guard let w = queue[safe: i], advice[w.id] == nil, !loading.contains(w.id) else { return }
        if BrainRules.isCrisis(w.title) { advice[w.id] = BrainRules.crisisAdvice(); return }
        let rule = BrainRules.worry(w.title)
        guard Brain.shared.isReady else { advice[w.id] = rule; return }
        loading.insert(w.id)
        let id = w.id, title = w.title
        Task {
            let got = await Brain.shared.worry(title)
            advice[id] = got.line.isEmpty ? rule : got
            loading.remove(id)
        }
    }

    // MARK: 한 장

    private func card(_ w: Item) -> some View {
        let a = advice[w.id]
        let crisis = a?.crisis == true
        return VStack(spacing: 0) {
            header.padding(.horizontal, Metric.gutter)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(index + 1) / \(queue.count) · " + (timeUp ? "10분이 지났어. 여기까지만 봐도 돼." : "10분만 보고 다시 내려놓자."))
                        .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    ZStack(alignment: .topLeading) {
                        Text(w.title).font(.system(.title2, weight: .bold)).foregroundStyle(Ink.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(shredding == nil ? 1 : 0)
                        if let s = shredding { ShredText(text: s) }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(Ink.sheet))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).strokeBorder(Ink.text.opacity(0.85), lineWidth: 1.5))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("worry.card")
                    .id(w.id)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .offset(y: 24).combined(with: .opacity), removal: .opacity))
                    adviceView(w, a)
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 10)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 10) {
                if !crisis {
                    Button(a?.inMyHands == true && a?.step != nil ? "이 걸음을 오늘 할 일로" : "오늘 할 일로") { toTask(w) }
                        .buttonStyle(FillButton(tone: .ink))
                        .accessibilityIdentifier("worry.task")
                }
                HStack(spacing: 10) {
                    Button("내려놓기") { letGo(w) }
                        .buttonStyle(FillButton(tone: .quiet))
                        .accessibilityHint("이 걱정을 지워")
                        .accessibilityIdentifier("worry.letgo")
                    Button("다음에 다시") { keep(w) }
                        .buttonStyle(FillButton(tone: .line))
                        .accessibilityHint("상자에 두고 다음 걱정 시간에 다시 봐")
                        .accessibilityIdentifier("worry.keep")
                }
            }
            .disabled(shredding != nil)
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
        }
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("걱정 시간").font(Typo.serif(24, relativeTo: .title2)).foregroundStyle(Ink.text)
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            // 초를 세지 않는다 — 걱정 시간에 째깍이는 시계는 재촉이 된다. 1분에 한 번만 바뀐다.
            TimelineView(.periodic(from: start, by: 60)) { ctx in
                let left = max(0, 600 - ctx.date.timeIntervalSince(start))
                Text(left > 0 ? "\(Int((left / 60).rounded(.up)))분 남음" : "10분 끝")
                    .font(Typo.num(.headline)).foregroundStyle(left > 0 ? Ink.text2 : Ink.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityLabel(left > 0 ? "남은 시간 \(Int((left / 60).rounded(.up)))분" : "10분이 지났어")
                    .accessibilityIdentifier("worry.timer")
                    .onChange(of: left <= 0) { _, up in
                        if up && !timeUp { timeUp = true; Haptic.soft() }
                    }
            }
            Button("그만") { dismiss() }
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                .accessibilityIdentifier("worry.stop")
        }
        .padding(.top, 4)
    }

    @ViewBuilder private func adviceView(_ w: Item, _ a: WorryAdvice?) -> some View {
        if let a, a.crisis {
            VStack(alignment: .leading, spacing: 10) {
                Text("혼자 버티지 않아도 돼.").font(.system(.headline, weight: .bold)).foregroundStyle(Ink.text)
                Text("지금 많이 힘들면 바로 이야기할 수 있는 곳이 있어. 24시간 열려 있어.")
                    .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
                // 큰 글자면 번호만 (잘린 번호는 누를 수 없어 보인다)
                Button { call("109") } label: {
                    ViewThatFits(in: .horizontal) { Text("109 · 자살예방 상담"); Text("109 전화") }
                }
                .buttonStyle(FillButton(tone: .accent, height: 50))
                .accessibilityLabel("자살예방 상담 109에 전화")
                .accessibilityIdentifier("worry.call.109")
                Button { call("15770199") } label: {
                    ViewThatFits(in: .horizontal) { Text("1577-0199 · 정신건강 위기상담"); Text("1577-0199 전화") }
                }
                .buttonStyle(FillButton(tone: .line, height: 50))
                .accessibilityLabel("정신건강 위기상담 1577-0199에 전화")
                .accessibilityIdentifier("worry.call.1577")
            }
            .card()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("worry.crisis")
        } else if let a {
            VStack(alignment: .leading, spacing: 8) {
                Text(a.inMyHands ? "내 손 안에 있는 것" : "지금은").font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.text3)
                Text(a.line).font(.system(.subheadline)).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                if a.inMyHands, let step = a.step {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("작은 한 걸음").font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.text3)
                        Text(step).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.fill))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("worry.advice")
        } else {
            ThinkingLine(text: "내 손 안에 할 수 있는 게 있는지 보는 중")
        }
    }

    private func call(_ number: String) {
        if let u = URL(string: "tel://\(number)") { openURL(u) }
    }

    /// 지금 보이는 장에만 듣는다 — 두 번 눌러도 다음 걱정을 건너뛰지 않게
    private func isCurrent(_ w: Item) -> Bool { shredding == nil && queue[safe: index]?.id == w.id }

    /// 내 손 안의 걸음이 있으면 그 걸음을 제목으로, 원래 걱정은 메모로 남긴다
    private func toTask(_ w: Item) {
        guard isCurrent(w) else { return }
        let a = advice[w.id]
        let step = a?.inMyHands == true ? a?.step : nil
        let part = store.settings.parts.part(at: minuteOfDay(store.now))
        let today = store.today, now = store.now
        store.change { data in
            data.update(w.id) { it in
                it.worry = false
                if let step {
                    if it.note.isEmpty { it.note = "걱정: " + it.title }
                    it.title = step
                }
                it.day = today
                it.part = part
                it.time = nil
                it.duration = 15
                it.created = now
            }
        }
        counts.task += 1
        Haptic.tap()
        next()
    }

    private func letGo(_ w: Item) {
        guard isCurrent(w) else { return }
        shredding = w.title
        Haptic.shred()
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.35 : 0.7)) {
            store.change { $0.remove(.item(w.id)) }
            shredding = nil
            counts.letGo += 1
            next()
        }
    }

    private func keep(_ w: Item) {
        guard isCurrent(w) else { return }
        counts.keep += 1
        Haptic.tick()
        next()
    }

    private func next() {
        index += 1
        loadAdvice(index)
        loadAdvice(index + 1)
    }

    // MARK: 끝

    private var nextWorryTime: String {
        let t = store.settings.worryTime
        return "다음 걱정 시간은 \(minuteOfDay(store.now) < t ? "오늘" : "내일") \(Fmt.hm(t))."
    }

    private var ending: some View {
        VStack(spacing: 0) {
            FlowCenteredScroll {
                VStack(alignment: .leading, spacing: 16) {
                    Text(queue.isEmpty ? "걱정 상자가 비어 있어." : "다 봤어. 다시 내려놓자.")
                        .font(Typo.serif(28, relativeTo: .title)).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("worry.end")
                    if !queue.isEmpty {
                        Text("할 일로 \(counts.task) · 내려놓음 \(counts.letGo) · 다음에 \(counts.keep)")
                            .font(Typo.num(.headline)).foregroundStyle(Ink.text2)
                    }
                    Text(queue.isEmpty ? "걱정이 떠오르면 비우기에서 ‘걱정 시간’ 칸에 넣어 둬. 그때 같이 보자."
                         : "걱정은 정해진 때에만. 나머지 시간엔 상자가 들고 있을게.")
                        .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    if store.settings.worryOn {
                        Text(nextWorryTime).font(.system(.footnote)).foregroundStyle(Ink.text3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metric.gutter)
            }
            Button("닫기") { dismiss() }
                .buttonStyle(FillButton(tone: .ink))
                .accessibilityIdentifier("worry.close")
                .padding(.horizontal, Metric.gutter)
        }
        .padding(.bottom, 12)
    }
}
