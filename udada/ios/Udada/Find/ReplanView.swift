import SwiftUI

/// 한 주 풀기 (iPhone). "이번 주 너무 빡빡해" → 무엇을 봤는지 한 줄씩 → 한 주의 짐이 옮기기 전·후로 → 옮길 일을 고르고 눌러야 적용.
/// Apple Intelligence 는 미뤄도 되는 일과 그 자리에서 해야 하는 일을 가르고, 어디로 옮길지와 모든 숫자는 규칙이 실제 빈 시간으로 센다.
struct ReplanView: View {
    var request: ReplanRequest

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var text = ""
    @State private var traces: [ReplanTrace] = []
    @State private var result: ReplanResult?
    @State private var chosen: Set<String> = []
    @State private var busy = false
    /// 그림이 '옮긴 뒤'를 보이고 있나
    @State private var showAfter = false
    @State private var run = 0
    /// 지금 도는 한 번의 표 — 앞서 돌던 것이 뒤늦게 보낸 과정 줄을 받지 않는다
    @State private var ticket = UUID()
    @FocusState private var focused: Bool

    private static let examples = ["이번 주 너무 빡빡해", "오늘 낮이 넘쳐", "내일 일이 너무 많아 좀 덜어 줘", "수요일은 비워 줘"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("한 주 풀기").font(Typo.serif(28, relativeTo: .title)).foregroundStyle(Ink.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("닫기") { dismiss() }
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Ink.text2)
                    .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                    .accessibilityIdentifier("replan.close")
            }
            .padding(.top, 8)

            HStack(spacing: 10) {
                Image(systemName: "apple.intelligence").font(.system(.body, weight: .semibold)).foregroundStyle(Ink.accent)
                    .accessibilityHidden(true)
                TextField("", text: $text, prompt: Text("예) 이번 주 너무 빡빡해").foregroundStyle(Ink.text3))
                    .font(.system(.title3, weight: .medium)).foregroundStyle(Ink.text)
                    .submitLabel(.go)
                    .focused($focused)
                    .onSubmit { start() }
                    .accessibilityIdentifier("replan.field")
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: Metric.radiusButton, style: .continuous).fill(Ink.sheet))
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if traces.isEmpty && result == nil && !busy { intro } else { working }
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            if let r = result, !r.moves.isEmpty {
                let n = r.moves.filter { chosen.contains($0.id) }.count
                Button(n == 0 ? "옮길 일을 골라" : "\(n)개 옮기기") { apply(r) }
                    .buttonStyle(FillButton(tone: .accent))
                    .disabled(n == 0)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("replan.apply")
            }
        }
        .padding(.horizontal, Metric.gutter)
        .background(Ink.ground.ignoresSafeArea())
        .onAppear {
            text = request.text
            if text.isEmpty { focused = true } else { start() }
        }
        .task(id: run) { await work() }
    }

    // MARK: 처음 (아직 안 물었을 때)

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("넘치는 칸의 일을 빈 칸으로 옮기는 안을 내 줘. 바꾸기 전에 먼저 보여 주고, 네가 눌러야 옮겨.")
                .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Self.examples, id: \.self) { ex in
                Button { text = ex; start() } label: {
                    Text(ex).font(Typo.row).foregroundStyle(Ink.text)
                        .frame(maxWidth: .infinity, minHeight: Metric.tap, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                Hairline()
            }
            Text(Brain.shared.isReady ? "미뤄도 되는 일과 꼭 해야 하는 일은 이 iPhone 의 Apple Intelligence 가 가르고, 어디에 넣을지는 실제 빈 시간으로 계산해."
                                     : "어디에 넣을지는 실제 빈 시간으로 계산해. 밖으로 나가는 건 없어.")
                .font(Typo.meta).foregroundStyle(Ink.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 보는 과정 · 그림 · 옮길 일

    @ViewBuilder private var working: some View {
        // 무엇을 봤나 (도구를 부를 때마다 한 줄씩)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(traces) { t in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: t.kind == .week ? "calendar" : t.kind == .todos ? "list.bullet" : "arrow.left.arrow.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(t.fromAI ? Ink.accent : Ink.text2)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    Text(t.text).font(.system(.subheadline)).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(Motion.rise)
            }
            if busy { ThinkingLine(text: traces.isEmpty ? "한 주를 펼치는 중…" : "미뤄도 되는 일을 가르는 중…").padding(.leading, 30) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("replan.trace")

        if let r = result {
            VStack(alignment: .leading, spacing: 8) {
                Text(ReplanRules.headline(r, chosen: chosen))
                    .font(Typo.serif(21, relativeTo: .title3)).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("replan.headline")
                if r.fromAI { AIBadge(text: "Apple Intelligence가 미룰 일을 골랐어") }
            }
            .transition(Motion.rise)

            // 한 주의 짐: 옮기기 전 ↔ 옮긴 뒤
            VStack(alignment: .leading, spacing: 10) {
                if !r.moves.isEmpty {
                    HStack(spacing: 6) {
                        Chip(title: "지금", on: !showAfter, id: "replan.before") { withAnimation(reduceMotion ? nil : Motion.page) { showAfter = false } }
                        Chip(title: "옮긴 뒤", on: showAfter, id: "replan.after") { withAnimation(reduceMotion ? nil : Motion.page) { showAfter = true } }
                    }
                }
                ReplanChart(snapshot: r.snapshot, cells: showAfter ? r.after(chosen) : r.snapshot.cells, changed: changed(r))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(Ink.sheet))
            .transition(Motion.rise)

            if !r.moves.isEmpty {
                VStack(spacing: 0) {
                    ForEach(r.moves) { m in
                        moveRow(m, r.snapshot)
                        Hairline().padding(.leading, 52)
                    }
                }
                .padding(.leading, -12)
                .transition(Motion.rise)
            }
        }
    }

    private func moveRow(_ m: ReplanMove, _ s: ReplanSnapshot) -> some View {
        let on = chosen.contains(m.id)
        return Button {
            Haptic.tick()
            withAnimation(reduceMotion ? nil : Motion.soft) { if on { chosen.remove(m.id) } else { chosen.insert(m.id) } }
        } label: {
            HStack(spacing: 4) {
                CheckBox(done: on)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(m.todo.entry.title).font(Typo.row).foregroundStyle(Ink.text).lineLimit(2).multilineTextAlignment(.leading)
                        if m.fromAI {
                            Image(systemName: "apple.intelligence").font(.system(.caption2, weight: .semibold)).foregroundStyle(Ink.accent)
                                .accessibilityLabel("Apple Intelligence가 고름")
                        }
                    }
                    Text("\(s.short(m.todo.entry.day, m.todo.entry.part)) → \(s.short(m.day, m.part)) · \(Fmt.dur(m.todo.entry.duration))")
                        .font(Typo.num(.footnote, .semibold)).foregroundStyle(Ink.accent)
                    Text(m.optional ? "그 자리에서 해야 해 보여서 꺼 뒀어. 옮기려면 눌러." : m.why)
                        .font(Typo.meta).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .frame(minHeight: Metric.rowMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("replan.move.\(m.todo.entry.title)")
    }

    /// 고른 옮김이 건드리는 칸 (그림에서 테두리로 짚는다)
    private func changed(_ r: ReplanResult) -> Set<String> {
        var out: Set<String> = []
        for m in r.moves where chosen.contains(m.id) {
            out.insert(ReplanChart.key(m.todo.entry.day, m.todo.entry.part))
            out.insert(ReplanChart.key(m.day, m.part))
        }
        return out
    }

    // MARK: 하기

    private func start() {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !busy else { return }
        focused = false
        Haptic.tick()
        run += 1
    }

    private func work() async {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard run > 0, !q.isEmpty else { return }
        busy = true
        result = nil
        traces = []
        showAfter = false
        let mine = UUID()
        ticket = mine
        let r = await Brain.shared.replan(q, data: store.data, external: store.external, now: store.now) { t in
            Task { @MainActor in
                guard ticket == mine, !traces.contains(where: { $0.text == t.text }) else { return }
                withAnimation(reduceMotion ? nil : Motion.soft) { traces.append(t) }
            }
        }
        guard ticket == mine else { return }
        // 과정 줄이 먼저 보이게 한 박자 쉰다
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        chosen = r.defaults
        withAnimation(reduceMotion ? nil : Motion.page) { result = r; busy = false }
        guard !r.moves.isEmpty else { return }
        // 지금의 짐을 보여 준 뒤, 옮긴 뒤로 넘어간다
        try? await Task.sleep(for: .milliseconds(900))
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? nil : Motion.page) { showAfter = true }
        Haptic.soft()
    }

    private func apply(_ r: ReplanResult) {
        let picked = r.moves.filter { chosen.contains($0.id) }
        guard !picked.isEmpty else { return }
        store.change(undo: picked.count == 1 ? "한 개를 옮겼어" : "\(picked.count)개를 옮겼어") { d in
            for m in picked { d.move(m.todo.entry.source, to: m.day, part: m.part) }
        }
        Haptic.success()
        dismiss()
    }
}

/// 한 주의 짐 그림: 날마다 한 기둥, 아침·낮·저녁 세 칸. 칸은 넣은 일이 빈 시간을 얼마나 채웠는지만큼 차고, 넘치면 먹색으로 꽉 차며 넘친 시간을 적는다.
struct ReplanChart: View {
    var snapshot: ReplanSnapshot
    var cells: [ReplanCell]
    /// 옮김이 건드리는 칸
    var changed: Set<String>

    static func key(_ d: DayKey, _ p: Part) -> String { "\(d.description)-\(p.rawValue)" }

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            VStack(alignment: .leading, spacing: 5) {
                Color.clear.frame(height: 34)
                ForEach(Part.allCases) { p in
                    Text(p.name).font(Typo.serif(13, relativeTo: .caption)).foregroundStyle(Ink.text2)
                        .frame(height: 40, alignment: .leading)
                }
            }
            .frame(width: 30, alignment: .leading)
            .accessibilityHidden(true)
            ForEach(snapshot.days, id: \.self) { d in
                VStack(spacing: 5) {
                    VStack(spacing: 0) {
                        Text(Fmt.weekday[d.weekday()]).font(.system(.caption2, weight: .semibold)).foregroundStyle(Ink.text3)
                        Text("\(d.d)").font(Typo.num(.footnote)).foregroundStyle(d == snapshot.today ? Ink.accent : Ink.text)
                    }
                    .frame(height: 34)
                    ForEach(Part.allCases) { p in
                        cell(cells.first { $0.day == d && $0.part == p }, key: Self.key(d, p))
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(d))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("replan.chart")
    }

    private func cell(_ c: ReplanCell?, key: String) -> some View {
        let over = (c?.overflow ?? 0) > 0
        let ratio: Double = {
            guard let c, !c.gone, c.planned > 0 else { return 0 }
            return c.free > 0 ? min(1, Double(c.planned) / Double(c.free)) : 1
        }()
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.fill.opacity(c?.gone == true ? 0.35 : 1))
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(over ? Ink.text : Ink.text3.opacity(0.55))
                    .frame(height: g.size.height * ratio)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            if over, let c {
                Text("+" + shortDur(c.overflow)).font(Typo.num(size: 10, .bold, relativeTo: .caption2)).foregroundStyle(Ink.sheet)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 2).padding(.bottom, 4)
            }
        }
        .frame(height: 40)
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Ink.accent, lineWidth: 1.5).opacity(changed.contains(key) ? 1 : 0)
        }
    }

    /// 좁은 칸에 넣는 짧은 길이: 50분 → "50", 1시간 30분 → "1.5h" 대신 "90"
    private func shortDur(_ m: Int) -> String { "\(m)분" }

    private func label(_ d: DayKey) -> String {
        let parts = cells.filter { $0.day == d && !$0.gone }.map { c in
            c.overflow > 0 ? "\(c.part.name) \(Fmt.dur(c.overflow)) 넘침" : "\(c.part.name) 빈 \(Fmt.dur(c.room))"
        }
        return snapshot.label(d) + ", " + (parts.isEmpty ? "지나감" : parts.joined(separator: ", "))
    }
}
