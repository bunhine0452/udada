import SwiftUI

/// 하루 닫기: 남은 할 일마다 내일 / 나중에 / 안 해 한 번씩. 계획만 세워도 머릿속 침투가 사라진다 (Masicampo & Baumeister 2011),
/// 안 끝난 일은 저녁 반추와 잠을 해친다 (Syrek & Antoni 2014). 끝은 도장 하나.
/// 카드는 밀어도 된다(→ 내일 · ← 안 해). 잘못 정했으면 앞 장으로 되돌린다. 기록은 하루에 하나 — 다시 닫으면 합친다.
struct CloseDayView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 정한 한 장: 되돌릴 때 원래 항목으로 돌려놓는다
    private struct Decision { var choice: CloseChoice; var saved: Item? }

    @State private var queue: [Entry] = []
    @State private var index = 0
    @State private var counts: [CloseChoice: Int] = [:]
    @State private var history: [Decision] = []
    @State private var stamped = false
    @State private var closingLine: String?
    @State private var started = false
    @State private var closed = false
    @AppStorage(FlowMemory.swipedKey) private var swipeLearned = false

    private var finished: Bool { started && index >= queue.count }

    var body: some View {
        ZStack {
            Ink.ground.ignoresSafeArea()
            if finished { ending.transition(.opacity) } else if let e = queue[safe: index] { card(e) }
        }
        .onAppear(perform: setUp)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.86), value: index)
    }

    private func setUp() {
        guard !started else { return }
        FlowMemory.prepare()
        queue = store.sheet(for: store.today).leftovers
        started = true
        if queue.isEmpty { finish() }
    }

    // MARK: 한 장

    private func card(_ e: Entry) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                header
                HStack(spacing: 4) {
                    ForEach(queue.indices, id: \.self) { k in
                        Capsule().fill(k < index ? Ink.text : Ink.fill).frame(height: 4)
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(.horizontal, Metric.gutter)
            FlowCenteredScroll {
                VStack(alignment: .leading, spacing: 14) {
                    Text("남은 건 하나씩 자리만 정하면 돼.")
                        .font(Typo.serif(20, relativeTo: .title3)).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                    entryCard(e)
                    if !swipeLearned { FlowSwipeHint(left: "안 해", right: "내일") }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 16)
            }
            VStack(spacing: 10) {
                Button("내일") { choose(.tomorrow, e) }
                    .buttonStyle(FillButton(tone: .ink))
                    .accessibilityHint("내일 아침 띠로 옮겨")
                    .accessibilityIdentifier("close.tomorrow")
                HStack(spacing: 10) {
                    Button("나중에") { choose(.later, e) }
                        .buttonStyle(FillButton(tone: .quiet))
                        .accessibilityHint("나중에 함에 넣어")
                        .accessibilityIdentifier("close.later")
                    Button("안 해") { choose(.drop, e) }
                        .buttonStyle(FillButton(tone: .line))
                        .accessibilityHint("지워")
                        .accessibilityIdentifier("close.drop")
                }
            }
            .padding(.horizontal, Metric.gutter)
        }
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(spacing: 2) {
            if !history.isEmpty {
                Button { undoLast() } label: {
                    Image(systemName: "chevron.left").font(.system(.body, weight: .semibold))
                        .frame(width: Metric.tap, height: Metric.tap)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Ink.text)
                .padding(.leading, -12)
                .accessibilityLabel("앞 장으로 되돌리기")
                .accessibilityIdentifier("close.back")
            }
            Text("\(min(index + 1, queue.count)) / \(queue.count)")
                .font(Typo.num(.headline)).foregroundStyle(Ink.text2)
                .accessibilityLabel("\(queue.count)개 중 \(min(index + 1, queue.count))번째")
                .accessibilityIdentifier("close.count")
            Spacer()
            Button("나중에 닫기") { leaveEarly() }
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                .frame(minHeight: Metric.tap)
                .accessibilityIdentifier("close.leave")
        }
        .frame(minHeight: Metric.tap)
        .padding(.top, 4)
    }

    private func entryCard(_ e: Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(e.title).font(.system(.title, weight: .bold)).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            Text([e.part.name, Fmt.dur(e.duration)].joined(separator: " · ") + (e.movedFrom.map { " · \(Fmt.day($0, today: store.today))부터" } ?? ""))
                .font(.system(.subheadline)).foregroundStyle(Ink.text2)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(Ink.sheet))
        .overlay(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).strokeBorder(Ink.text.opacity(0.85), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("close.card")
        .modifier(FlowSwipe(
            left: .init(label: "안 해", tint: Ink.text2) { choose(.drop, e) },
            right: .init(label: "내일", tint: Ink.text) { choose(.tomorrow, e) },
            peek: index == 0 && !swipeLearned,
            onUse: { swipeLearned = true }))
        .id(e.id)
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .offset(y: 24).combined(with: .opacity), removal: .opacity))
    }

    /// 지금 보이는 카드에만 듣는다 — 두 번 눌러도 다음 장을 건너뛰지 않게
    private func choose(_ c: CloseChoice, _ e: Entry) {
        guard !closed, queue[safe: index]?.id == e.id else { return }
        let today = store.today
        let saved = e.itemID.flatMap { store.data.item($0) }
        store.change { $0.apply(c, to: e.source, today: today) }
        history.append(Decision(choice: c, saved: saved))
        counts[c, default: 0] += 1
        if c == .drop { Haptic.soft() } else { Haptic.tap() }
        index += 1
        if index >= queue.count { finish() }
    }

    /// 앞 장으로: 방금 정한 것을 원래대로 (지운 것도 살린다)
    private func undoLast() {
        guard !closed, let last = history.popLast() else { return }
        if let saved = last.saved {
            store.change { data in
                if let i = data.items.firstIndex(where: { $0.id == saved.id }) { data.items[i] = saved } else { data.items.append(saved) }
            }
        }
        counts[last.choice, default: 1] -= 1
        index = max(0, index - 1)
        Haptic.tick()
    }

    private func leaveEarly() {
        if !history.isEmpty { store.show("\(history.count)개는 자리를 정했어. 나머지는 이따 닫아도 돼.") }
        dismiss()
    }

    /// 하루에 기록 하나: 오늘 이미 닫았으면 정한 수를 더한다
    private func finish() {
        guard !closed else { return }
        closed = true
        let today = store.today
        let now = store.now
        let done = store.sheet(for: today).doneTodos
        let t = counts[.tomorrow] ?? 0, l = counts[.later] ?? 0, d = counts[.drop] ?? 0
        store.change { data in
            var log = CloseLog(day: today, at: now, done: done, tomorrow: t, later: l, dropped: d)
            for old in data.closes where old.day == today {
                log.tomorrow += old.tomorrow
                log.later += old.later
                log.dropped += old.dropped
            }
            data.closes.removeAll { $0.day == today }
            data.closes.append(log)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            stamped = true
            // 닿는 순간에 쿵 (내려오는 데 0.13초)
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.02 : 0.13)) { Haptic.stamp() }
        }
        loadClosingLine(done: done, moved: t + l, dropped: d)
    }

    /// 닫는 한 줄은 사실만 말하는 규칙 문장 — 바로 보이고, Brain 이 다른 문장을 주면 조용히 바꾼다 (기다리게 하지 않는다)
    private func loadClosingLine(done: Int, moved: Int, dropped: Int) {
        let first = tomorrowFirst
        closingLine = BrainRules.closing(done: done, moved: moved, dropped: dropped, tomorrowFirst: first)
        Task {
            let got = await Brain.shared.closing(done: done, moved: moved, dropped: dropped, tomorrowFirst: first)
            if !got.isEmpty { closingLine = got }
        }
    }

    private var tomorrowFirst: String? {
        let s = store.sheet(for: store.today.adding(days: 1))
        return s.bands.flatMap { $0.events + $0.todos }.sorted { ($0.time ?? $0.part.index * 600) < ($1.time ?? $1.part.index * 600) }.first?.title
    }

    // MARK: 끝

    private var ending: some View {
        let today = store.today
        let done = store.sheet(for: today).doneTodos
        let first = tomorrowFirst
        return VStack(spacing: 0) {
            FlowCenteredScroll {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        InkStamp(top: "오늘 끝", bottom: "\(today.m).\(today.d)", shown: stamped)
                        Spacer()
                    }
                    .padding(.bottom, 6)
                    Text("오늘은 닫았어.").font(Typo.serif(30, relativeTo: .largeTitle)).foregroundStyle(Ink.text)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("close.end")
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) { stats(done) }
                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                            GridRow { stat("끝낸 것", done); stat("내일로", counts[.tomorrow] ?? 0) }
                            GridRow { stat("나중에", counts[.later] ?? 0); stat("안 함", counts[.drop] ?? 0) }
                        }
                    }
                    if let line = closingLine {
                        Text(line).font(.system(.body)).foregroundStyle(Ink.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("close.line")
                    }
                    // AI·규칙 문장이 이미 내일 첫 일을 말했으면 다시 쓰지 않는다
                    if let f = first, closingLine.map({ !$0.contains(f) }) ?? true {
                        Text("내일 처음은 ‘\(f)’.").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                    }
                    Text("남은 일에 자리가 생기면 머리가 그 일을 놓아 (Masicampo 2011).")
                        .font(.system(.footnote)).foregroundStyle(Ink.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 12)
            }
            Button("끝") { dismiss() }
                .buttonStyle(FillButton(tone: .ink))
                .accessibilityIdentifier("close.finish")
                .padding(.horizontal, Metric.gutter)
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder private func stats(_ done: Int) -> some View {
        stat("끝낸 것", done)
        stat("내일로", counts[.tomorrow] ?? 0)
        stat("나중에", counts[.later] ?? 0)
        stat("안 함", counts[.drop] ?? 0)
    }

    private func stat(_ label: String, _ n: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(n)").font(Typo.num(.title2)).foregroundStyle(Ink.text)
            Text(label).font(.system(.caption)).foregroundStyle(Ink.text2).fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}

/// 하루 닫기 도장: 겹 동그라미 + 명조 두 줄. 비스듬히 내려와 종이에 닿는 순간 잉크가 살짝 번지고 배어든다.
/// 잉크는 고르게 묻지 않는다 — 아주 작은 빈틈 몇 개. 동작 줄이기면 제자리에서 나타나기만 한다.
private struct InkStamp: View {
    var top: String
    var bottom: String
    var shown: Bool
    @State private var soaked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // 번짐: 닿은 순간 바깥으로 아주 조금 퍼지며 사라지는 고리
            Circle().strokeBorder(Ink.stamp, lineWidth: 2)
                .scaleEffect(soaked ? 1.1 : 1)
                .opacity(soaked || !shown || reduceMotion ? 0 : 0.4)
            ZStack {
                Circle().strokeBorder(Ink.stamp, lineWidth: soaked ? 4.6 : 4)
                Circle().strokeBorder(Ink.stamp, lineWidth: soaked ? 1.8 : 1.5).padding(9)
                VStack(spacing: 2) {
                    Text(top).font(Typo.serif(30, relativeTo: .title))
                    Text(bottom).font(Typo.num(size: 13, .semibold, relativeTo: .caption))
                }
                .foregroundStyle(Ink.stamp)
            }
            .mask(InkGrain())
        }
        .frame(width: 148, height: 148)
        .rotationEffect(.degrees(-12))
        .scaleEffect(shown || reduceMotion ? 1 : 1.7)
        .opacity(shown ? 0.92 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.25) : .spring(response: 0.3, dampingFraction: 0.62), value: shown)
        .onChange(of: shown) { _, s in
            guard s else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.13)) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { soaked = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(top) 도장")
        .accessibilityIdentifier("close.stamp")
    }
}

/// 도장 잉크의 작은 빈틈 (늘 같은 자리 — 씨앗 고정)
private struct InkGrain: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            ctx.blendMode = .destinationOut
            var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
            func next() -> CGFloat {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return CGFloat(seed >> 33) / CGFloat(UInt64(1) << 31)
            }
            for _ in 0..<70 {
                let x = next() * size.width, y = next() * size.height, r = 0.4 + next() * 1.1
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.black))
            }
        }
        .allowsHitTesting(false)
    }
}
