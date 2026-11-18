import SwiftUI

// 기록 탭: 이번 주의 사실 몇 개 · 언제 끝냈나 · 예상 대 실제 · 12주 칸 · 최근 끝낸 일.
// 숫자는 사실로만 — 목표 · 연속 기록 · 점수 없음 (VALUE.md). 큰 숫자에 작은 이름표.

struct RecordsView: View {
    @Environment(Store.self) private var store
    /// 설정의 '소개 다시 보기': 시트가 다 내려간 뒤에 소개로 바꾼다 (띄운 쪽이 먼저 사라지지 않게)
    @State private var replayIntro = false
    /// 설정 시트는 이 값으로 띄운다. store.showSettings(딥링크 · 톱니)를 따라가되,
    /// 이 화면이 막 나타날 때 온 요청은 창에 붙은 뒤에 띄운다 (처음부터 true 인 시트는 안 뜰 때가 있다).
    @State private var settingsUp = false
    @State private var visible = false

    var body: some View {
        let stats = RecordStats.compute(store.data, today: store.today)
        let mondayFirst = store.settings.mondayFirst
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header(stats)
                if stats.isEmpty {
                    EmptyRecords()
                    GridSection(stats: stats, mondayFirst: mondayFirst)
                } else {
                    VStack(spacing: 12) {
                        ReflectionCard(text: stats.reflection)
                        WeekLedger(stats: stats)
                    }
                    PartBars(stats: stats)
                    FocusSection(stats: stats, unit: store.settings.defaultDuration)
                    GridSection(stats: stats, mondayFirst: mondayFirst)
                    HistorySection(stats: stats)
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Ink.ground.ignoresSafeArea())
        .accessibilityIdentifier("records.screen")
        .sheet(isPresented: $settingsUp, onDismiss: replayIfAsked) {
            SettingsView(replayIntro: {
                replayIntro = true
                store.showSettings = false
            })
            .environment(store)
        }
        .onAppear {
            visible = true
            syncSettings(justAppeared: true)
        }
        .onDisappear { visible = false }
        .onChange(of: store.showSettings) { _, _ in syncSettings(justAppeared: false) }
        .onChange(of: settingsUp) { _, up in
            // 끌어내려 닫으면 요청도 내린다
            if !up && store.showSettings { store.showSettings = false }
        }
    }

    private func syncSettings(justAppeared: Bool) {
        let want = store.showSettings
        guard want != settingsUp else { return }
        guard want else { settingsUp = false; return }
        guard visible else { return } // 보일 때 다시 맞춘다
        if !justAppeared {
            settingsUp = true
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            if store.showSettings && visible && !settingsUp { settingsUp = true }
        }
    }

    private func header(_ stats: RecordStats) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ScreenTitle(title: "기록", sub: "이번 주 · \(stats.weekRange)")
            Button {
                Haptic.tap()
                store.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Ink.text)
                    .frame(width: Metric.tap, height: Metric.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("설정")
            .accessibilityIdentifier("records.settings")
        }
    }

    private func replayIfAsked() {
        guard replayIntro else { return }
        replayIntro = false
        store.tab = .today
        store.change { $0.seenIntro = false }
    }
}

// MARK: - 이번 주 한 줄

/// 기록 위의 조용한 한 줄. 숫자로 만든 문장 — 주 중 언제 봐도 맞게 ("아직 끝낸 일이 없어").
/// (Brain.weekly 는 규칙 문장이고 주를 마칠 때 말투라 여기선 쓰지 않는다.)
struct ReflectionCard: View {
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이번 주 한 줄").font(Typo.caption).foregroundStyle(Ink.text3)
            Text(text)
                .font(.system(.body))
                .lineSpacing(3)
                .foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("records.reflection")
    }
}

/// 4.0 → "4", 3.86 → "3.9"
private func oneDecimal(_ v: Double) -> String {
    let r = (v * 10).rounded() / 10
    return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
}

// MARK: - 빈 상태

private struct EmptyRecords: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RecordStats.emptyText)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Ink.text)
            Text("점수도 연속 기록도 없어. 있었던 일만 조용히 적어 둬.")
                .font(.system(.subheadline))
                .foregroundStyle(Ink.text2)
        }
        .fixedSize(horizontal: false, vertical: true)
        .card(padding: 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("records.empty")
    }
}

// MARK: - 이번 주 숫자

/// 한 장의 장부: 끝낸 일(큰 숫자) · 끝낸 비율 · 닫은 날 · 식힌 횟수 · 비운 고리
private struct WeekLedger: View {
    var stats: RecordStats
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        let w = stats.week
        VStack(alignment: .leading, spacing: 16) {
            hero
            if let rate = w.rate { RateLine(done: w.done, open: w.open, rate: rate) }
            Hairline()
            if size.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) { ForEach(facts) { FactView(fact: $0) } }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(facts.enumerated()), id: \.element.id) { i, f in
                        if i > 0 { Rectangle().fill(Ink.rule).frame(width: 1).accessibilityHidden(true) }
                        FactView(fact: f).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(padding: 18)
    }

    private var hero: some View {
        let w = stats.week, p = stats.prev
        return HStack(alignment: .lastTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("끝낸 일").font(Typo.label).foregroundStyle(Ink.text2)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(w.done)").font(Typo.num(size: 60, relativeTo: .largeTitle)).foregroundStyle(Ink.text)
                    Text("개").font(.system(.title3, weight: .semibold)).foregroundStyle(Ink.text2)
                }
            }
            Spacer(minLength: 8)
            Text("지난주 \(p.done)개").font(Typo.meta).foregroundStyle(Ink.text3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("이번 주 끝낸 일 \(w.done)개")
        .accessibilityValue("지난주 \(p.done)개")
        .accessibilityIdentifier("records.done")
    }

    private var facts: [Fact] {
        let w = stats.week, p = stats.prev
        var rest = Fact(id: "rests", label: "식힌 횟수", value: w.rests, unit: "번", note: "지난주 \(p.rests)번")
        if let c = w.clarity, let b = w.clarityBefore, let a = w.clarityAfter {
            rest.note = "맑기 \(RecordStats.signed(c))"
            rest.spoken = "식힌 뒤 맑기 평균 \(oneDecimal(b))에서 \(oneDecimal(a))로"
        }
        var dump = Fact(id: "dumped", label: "비운 고리", value: w.dumped, unit: "개", note: "지난주 \(p.dumped)개")
        if let n = w.noise, let b = w.noiseBefore, let a = w.noiseAfter {
            dump.note = "소음 \(RecordStats.signed(n))"
            dump.spoken = "\(w.dumps)번 비웠고, 머리 소음 평균 \(oneDecimal(b))에서 \(oneDecimal(a))로"
        }
        return [Fact(id: "closed", label: "닫은 날", value: w.closed, unit: "일", note: "지난주 \(p.closed)일"), rest, dump]
    }
}

private struct Fact: Identifiable {
    var id: String
    var label: String
    var value: Int
    var unit: String
    var note: String
    /// 화면 읽기에서 note 대신 읽을 긴 말
    var spoken: String? = nil
}

private struct FactView: View {
    var fact: Fact
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fact.label).font(Typo.caption).foregroundStyle(Ink.text2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(fact.value)").font(Typo.num(.title)).foregroundStyle(Ink.text)
                Text(fact.unit).font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.text2)
            }
            Text(fact.note).font(Typo.caption).foregroundStyle(Ink.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fact.label) \(fact.value)\(fact.unit)")
        .accessibilityValue(fact.spoken ?? fact.note)
        .accessibilityIdentifier("records.fact.\(fact.id)")
    }
}

/// 끝낸 것과 남은 것의 막대. 평균은 '견줄 거리'일 뿐 목표가 아니다.
private struct RateLine: View {
    var done: Int
    var open: Int
    var rate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Ink.fill)
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Ink.text.opacity(0.85))
                        .frame(width: max(rate > 0 ? 6 : 0, geo.size.width * rate))
                }
            }
            .frame(height: 8)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("끝낸 \(done) · 남은 \(open)").font(Typo.num(.subheadline, .medium)).foregroundStyle(Ink.text2)
                Spacer(minLength: 8)
                Text(RecordStats.percent(rate)).font(Typo.num(.headline)).foregroundStyle(Ink.text)
            }
            Text(RecordStats.baselineText)
                .font(Typo.caption).foregroundStyle(Ink.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("끝낸 비율 \(RecordStats.percent(rate))")
        .accessibilityValue("끝낸 일 \(done)개, 남은 일 \(open)개. \(RecordStats.baselineText)")
        .accessibilityIdentifier("records.rate")
    }
}

// MARK: - 띠별

private struct PartBars: View {
    var stats: RecordStats

    var body: some View {
        let byPart = stats.week.byPart
        let top = max(1, Part.allCases.map { byPart[$0] ?? 0 }.max() ?? 1)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle(title: "띠별로 끝낸 일")
                Text(stats.topPart.map { "\($0.name)에 가장 많이 끝냈어." } ?? "이번 주엔 아직 끝낸 일이 없어.")
                    .font(.system(.subheadline)).foregroundStyle(Ink.text2)
            }
            VStack(spacing: 10) {
                ForEach(Part.allCases) { p in
                    let n = byPart[p] ?? 0
                    let best = n > 0 && n == top
                    HStack(spacing: 12) {
                        Text(p.name)
                            .font(Typo.serif(17, relativeTo: .body))
                            .foregroundStyle(Ink.text)
                            .frame(minWidth: 40, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Ink.fill)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Ink.text.opacity(best ? 0.9 : 0.38))
                                    .frame(width: n == 0 ? 0 : max(6, geo.size.width * CGFloat(n) / CGFloat(top)))
                            }
                        }
                        .frame(height: 12)
                        Text("\(n)")
                            .font(Typo.num(.body))
                            .foregroundStyle(best ? Ink.text : Ink.text2)
                            .frame(minWidth: 28, alignment: .trailing)
                    }
                    .frame(minHeight: 32)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(p.name) \(n)개")
                }
            }
            .card()
        }
    }
}

// MARK: - 예상 대 실제

/// 집중으로 잰 실제 ÷ 예상. 비율만이 아니라 '30분 잡으면 보통 39분'처럼 분으로 보여 준다 (Kruger & Evans 2004).
private struct FocusSection: View {
    var stats: RecordStats
    /// 견줄 길이 — 설정의 기본 길이
    var unit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "예상 대 실제") {
                if stats.focusCount > 0 {
                    Text("집중 \(stats.focusCount)번").font(Typo.num(.subheadline, .medium)).foregroundStyle(Ink.text3)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                if let r = stats.focusRatio, let advice = stats.focusAdvice {
                    ratio(r, advice: advice)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("집중으로 \(RecordStats.focusMin)번 재면, 예상보다 얼마나 더 걸리는지 보여 줄게.")
                            .font(.system(.body)).foregroundStyle(Ink.text)
                        Text(stats.focusCount == 0 ? "지금 줄에서 ‘시작’을 누르면 걸린 시간을 재." : "지금까지 \(stats.focusCount)번 쟀어.")
                            .font(Typo.meta).foregroundStyle(Ink.text3)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
                if !stats.recentFocus.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(stats.recentFocus.enumerated()), id: \.offset) { _, f in
                            Hairline()
                            RecentFocusRow(log: f)
                        }
                    }
                }
            }
            .card()
            .accessibilityIdentifier("records.focus")
        }
    }

    private func ratio(_ r: Double, advice: String) -> some View {
        let actual = max(1, Int((Double(unit) * r).rounded()))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(oneDecimal(r)).font(Typo.num(size: 44, relativeTo: .largeTitle)).foregroundStyle(Ink.text)
                Text("배").font(.system(.title3, weight: .semibold)).foregroundStyle(Ink.text2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("실제는 예상의 \(oneDecimal(r))배")
            CompareBars(planned: unit, actual: actual)
            Text(advice).font(.system(.body)).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("최근 12주 집중 \(stats.focusCount)번의 중앙값 · \(Fmt.dur(unit))짜리 일 기준")
                .font(Typo.caption).foregroundStyle(Ink.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 예상(빈 막대) 위에 실제(찬 막대)
private struct CompareBars: View {
    var planned: Int
    var actual: Int

    var body: some View {
        let top = CGFloat(max(planned, actual, 1))
        VStack(spacing: 8) {
            row("예상", planned, filled: false, top: top)
            row("실제", actual, filled: true, top: top)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Fmt.ro(Fmt.dur(planned))) 잡으면 보통 \(Fmt.dur(actual)) 걸려")
    }

    private func row(_ name: String, _ minutes: Int, filled: Bool, top: CGFloat) -> some View {
        HStack(spacing: 10) {
            Text(name).font(Typo.caption).foregroundStyle(Ink.text2).frame(minWidth: 28, alignment: .leading)
            GeometryReader { geo in
                let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                let w = max(8, geo.size.width * CGFloat(minutes) / top)
                Group {
                    if filled { shape.fill(Ink.text.opacity(0.85)) } else { shape.strokeBorder(Ink.text2, lineWidth: 1.5) }
                }
                .frame(width: w)
            }
            .frame(height: 14)
            Text(Fmt.dur(minutes)).font(Typo.num(.subheadline, .semibold)).foregroundStyle(Ink.text)
                .frame(minWidth: 56, alignment: .trailing)
        }
    }
}

private struct RecentFocusRow: View {
    var log: FocusLog
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(log.title).font(.system(.subheadline)).foregroundStyle(Ink.text).lineLimit(1)
            Spacer(minLength: 8)
            Text("\(Fmt.dur(log.planned)) → \(Fmt.dur(log.spent))")
                .font(Typo.num(.subheadline, .medium)).foregroundStyle(Ink.text2)
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(log.title)
        .accessibilityValue("예상 \(Fmt.dur(log.planned)), 실제 \(Fmt.dur(log.spent))")
    }
}

// MARK: - 12주 칸

private struct GridSection: View {
    var stats: RecordStats
    var mondayFirst: Bool

    var body: some View {
        let weeks = stride(from: 0, to: stats.grid.count, by: 7).map { Array(stats.grid[$0..<min($0 + 7, stats.grid.count)]) }
        let total = stats.grid.reduce(0) { $0 + $1.count }
        let best = stats.grid.map(\.count).max() ?? 0
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "12주") {
                Text(total == 0 ? "아직 없음" : "모두 \(total)개").font(Typo.num(.subheadline, .medium)).foregroundStyle(Ink.text3)
            }
            VStack(alignment: .leading, spacing: 12) {
                GridChart(weeks: weeks, today: stats.today)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        footnote(best)
                        Spacer(minLength: 8)
                        Legend()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        footnote(best)
                        Legend()
                    }
                }
            }
            .card()
        }
    }

    private func footnote(_ best: Int) -> some View {
        Text(best == 0 ? "끝낸 날마다 칸이 진해져." : "가장 많이 끝낸 날 \(best)개")
            .font(Typo.caption).foregroundStyle(Ink.text3)
            .accessibilityHidden(true)
    }
}

/// 열 = 주 (왼쪽이 오래된 주), 줄 = 요일. 위에 달 이름, 왼쪽에 요일.
private struct GridChart: View {
    var weeks: [[RecordStats.Cell]]
    var today: DayKey
    private let gap: CGFloat = 4

    var body: some View {
        Grid(horizontalSpacing: gap, verticalSpacing: gap) {
            GridRow {
                Color.clear.frame(width: 1, height: 1).gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(weeks.indices, id: \.self) { c in
                    Text(monthLabel(c) ?? "")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(Ink.text3)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            ForEach(0..<7, id: \.self) { r in
                GridRow {
                    Text(weekdayName(r))
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(Ink.text3)
                        .gridColumnAlignment(.leading)
                    ForEach(weeks.indices, id: \.self) { c in
                        if r < weeks[c].count {
                            GridCell(cell: weeks[c][r], today: weeks[c][r].day == today)
                        }
                    }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("12주 동안 날마다 끝낸 일")
        .accessibilityChildren {
            HStack {
                ForEach(weeks.indices, id: \.self) { c in
                    Rectangle()
                        .accessibilityLabel(weekName(c))
                        .accessibilityValue(weekValue(weeks[c]))
                }
            }
        }
        .accessibilityIdentifier("records.grid")
    }

    /// 그 주에 달의 1일이 들어 있으면 그 달 이름. 첫 열은 다음 열이 달을 열지 않을 때만.
    private func monthLabel(_ c: Int) -> String? {
        guard let first = weeks[c].first?.day else { return nil }
        if let one = weeks[c].first(where: { $0.day.d == 1 })?.day { return "\(one.m)월" }
        if c == 0 && !(weeks.count > 1 && weeks[1].contains { $0.day.d == 1 }) { return "\(first.m)월" }
        return nil
    }

    private func weekdayName(_ r: Int) -> String {
        guard let first = weeks.first?.first?.day else { return "" }
        return Fmt.weekday[(first.weekday() - 1 + r) % 7 + 1]
    }

    private func weekName(_ c: Int) -> String {
        guard let first = weeks[c].first?.day else { return "" }
        if weeks[c].contains(where: { $0.day == today }) { return "이번 주" }
        return "\(first.m)월 \(first.d)일 주"
    }

    private func weekValue(_ cells: [RecordStats.Cell]) -> String {
        let n = cells.reduce(0) { $0 + $1.count }
        guard n > 0, let top = cells.max(by: { $0.count < $1.count }) else { return "끝낸 일 없음" }
        return "끝낸 일 \(n)개, 가장 많은 날 \(Fmt.weekday[top.day.weekday()])요일 \(top.count)개"
    }
}

private struct GridCell: View {
    var cell: RecordStats.Cell
    var today: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        shape
            .fill(cell.future ? Ink.fill.opacity(0.35) : Self.color(RecordStats.level(cell.count)))
            .overlay { if today { shape.strokeBorder(Ink.accent, lineWidth: 2) } }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    static func color(_ level: Int) -> Color {
        switch level {
        case 0: Ink.fill
        case 1: Ink.text.opacity(0.22)
        case 2: Ink.text.opacity(0.42)
        case 3: Ink.text.opacity(0.66)
        default: Ink.text.opacity(0.9)
        }
    }
}

private struct Legend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("적음")
            ForEach(0..<5, id: \.self) { l in
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(GridCell.color(l)).frame(width: 10, height: 10)
            }
            Text("많음")
        }
        .font(Typo.caption)
        .foregroundStyle(Ink.text3)
        .fixedSize()
        .accessibilityHidden(true)
    }
}

// MARK: - 끝낸 일 (최근 14일)

private struct HistorySection: View {
    var stats: RecordStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "끝낸 일") {
                Text("최근 \(RecordStats.historyDays)일").font(Typo.meta).foregroundStyle(Ink.text3)
            }
            if stats.history.isEmpty {
                Hint(text: "최근 \(RecordStats.historyDays)일엔 끝낸 일이 없어.")
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(stats.history) { group in
                        DayBlock(group: group, today: stats.today)
                    }
                }
            }
        }
        .accessibilityIdentifier("records.history")
    }
}

private struct DayBlock: View {
    var group: RecordStats.DayGroup
    var today: DayKey

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.day(group.day, today: today))
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(Ink.text)
                Spacer()
                Text("\(group.items.count)개").font(Typo.num(.subheadline, .medium)).foregroundStyle(Ink.text3)
            }
            .padding(.bottom, 6)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ForEach(group.items) { it in
                Hairline()
                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Ink.text3)
                        .accessibilityHidden(true)
                    Text(it.title)
                        .font(.system(.body))
                        .foregroundStyle(Ink.text)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(it.slot)
                        .font(it.time == nil ? Typo.meta : Typo.num(.footnote, .medium))
                        .foregroundStyle(Ink.text3)
                }
                .frame(minHeight: Metric.tap)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
