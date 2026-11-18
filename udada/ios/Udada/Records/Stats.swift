import Foundation

// 기록 탭의 숫자. 순수 계산이라 테스트·하네스가 같이 쓴다 (Foundation 만).
// 숫자는 사실로만 보여 준다 — 목표·연속 기록·점수 없음 (VALUE.md).

struct RecordStats: Equatable {
    /// 한 주의 숫자
    struct Week: Equatable {
        var start: DayKey
        var end: DayKey
        /// 끝낸 일 (doneAt 이 이 주 안. 떼어 낸 반복 하루치 포함)
        var done = 0
        /// 아직 안 끝낸 할 일 (반복 아님 · 약속 아님 · 걱정 아님 · 날이 이 주 안이고 오늘 이전)
        var open = 0
        /// 하루 닫기 횟수
        var closed = 0
        /// 식히기 횟수와 평균 맑기 변화 (after − before, 둘 다 고른 것만)
        var rests = 0
        var clarity: Double? = nil
        /// 비우기 횟수 · 비운 고리 합 · 평균 소음 변화 (after − before, 음수면 조용해짐)
        var dumps = 0
        var dumped = 0
        var noise: Double? = nil
        /// 띠별 끝낸 개수
        var byPart: [Part: Int] = [:]
        /// 식히기 전후 맑기 평균 (둘 다 고른 것만)
        var clarityBefore: Double? = nil
        var clarityAfter: Double? = nil
        /// 비우기 전후 머리 소음 평균
        var noiseBefore: Double? = nil
        var noiseAfter: Double? = nil

        /// 끝낸 비율 0…1. 분모가 0이면 nil
        /// (지난 띠·날의 안 끝낸 일은 오늘로 옮겨 오므로 지난주 비율은 늘 100%처럼 보인다 — 이번 주에만 쓴다)
        var rate: Double? { done + open == 0 ? nil : Double(done) / Double(done + open) }
        var isEmpty: Bool { done == 0 && open == 0 && closed == 0 && rests == 0 && dumps == 0 }
    }

    /// 12주 칸 하나
    struct Cell: Equatable, Identifiable {
        var day: DayKey
        var count: Int
        var future: Bool
        var id: String { day.description }
    }

    /// 끝낸 일 한 줄
    struct Done: Equatable, Identifiable {
        var id: UUID
        var title: String
        var part: Part
        var time: Int?
        var doneAt: Date
        /// "15:00" 또는 "아침"
        var slot: String { time.map(Fmt.hm) ?? part.name }
    }

    struct DayGroup: Equatable, Identifiable {
        var day: DayKey
        var items: [Done]
        var id: String { day.description }
    }

    var today: DayKey
    var week: Week
    var prev: Week
    /// 집중 기록 수 (최근 12주)와 실제 ÷ 예상 중앙값 (3번 이상일 때만)
    var focusCount = 0
    var focusRatio: Double? = nil
    /// 최근 집중 몇 개 (예상이 있는 것, 최근부터) — 숫자가 어디서 왔는지 보여 준다
    var recentFocus: [FocusLog] = []
    /// 84칸, 주 단위 열 (앞 7칸이 가장 오래된 주)
    var grid: [Cell] = []
    /// 최근 14일 끝낸 일, 최근 날부터
    var history: [DayGroup] = []
    /// 기록이 하나도 없음 (새 사용자)
    var isEmpty = true

    /// 플래너 앱 6주 로그의 끝냄 비율 (Halder et al. 2026). 견줄 거리일 뿐 목표가 아니다.
    static let baseline = 0.495
    static let baselineText = "플래너 앱에서도 보통 절반쯤 끝내 (평균 49.5%, Halder 2026)"
    static let emptyText = "아직 기록이 없어. 하나 끝내면 여기 쌓여."
    static let gridWeeks = 12
    static let historyDays = 14
    static let focusMin = 3
    static let recentFocusCount = 3

    // MARK: 계산

    static func compute(_ data: AppData, today: DayKey, calendar: Calendar = .current) -> RecordStats {
        let mondayFirst = data.settings.mondayFirst
        let start = today.startOfWeek(mondayFirst: mondayFirst, calendar: calendar)
        let prevStart = start.adding(days: -7, calendar: calendar)
        let week = computeWeek(data, from: start, today: today, calendar: calendar)
        let prev = computeWeek(data, from: prevStart, today: today, calendar: calendar)

        // 끝낸 날짜별 개수 (한 번만 훑는다)
        var doneByDay: [DayKey: Int] = [:]
        var doneItems: [(DayKey, Done)] = []
        let historyFrom = today.adding(days: -(historyDays - 1), calendar: calendar)
        for it in data.items {
            guard let at = it.doneAt, it.done else { continue }
            let k = DayKey(at, calendar: calendar)
            doneByDay[k, default: 0] += 1
            if k >= historyFrom && k <= today {
                doneItems.append((k, Done(id: it.id, title: it.title, part: it.part, time: it.time, doneAt: at)))
            }
        }

        let gridStart = start.adding(days: -7 * (gridWeeks - 1), calendar: calendar)
        var grid: [Cell] = []
        grid.reserveCapacity(gridWeeks * 7)
        for i in 0..<(gridWeeks * 7) {
            let k = gridStart.adding(days: i, calendar: calendar)
            grid.append(Cell(day: k, count: doneByDay[k] ?? 0, future: k > today))
        }

        let groups = Dictionary(grouping: doneItems, by: { $0.0 })
        let history = groups.keys.sorted(by: >).map { k in
            DayGroup(day: k, items: groups[k]!.map(\.1).sorted { $0.doneAt > $1.doneAt })
        }

        // 집중: 최근 12주, 예상이 있는 것만
        let focusFromDate = gridStart.date(calendar: calendar)
        let measured = data.focus.filter { $0.planned > 0 && $0.at >= focusFromDate }
        let ratios = measured.map { Double($0.spent) / Double($0.planned) }
        let focusRatio = ratios.count >= focusMin ? median(ratios) : nil
        let recentFocus = Array(measured.sorted { $0.at > $1.at }.prefix(recentFocusCount))

        let isEmpty = doneByDay.isEmpty && data.closes.isEmpty && data.rests.isEmpty && data.dumps.isEmpty && data.focus.isEmpty

        return RecordStats(today: today, week: week, prev: prev, focusCount: ratios.count, focusRatio: focusRatio,
                           recentFocus: recentFocus, grid: grid, history: history, isEmpty: isEmpty)
    }

    static func computeWeek(_ data: AppData, from start: DayKey, today: DayKey, calendar: Calendar = .current) -> Week {
        let end = start.adding(days: 6, calendar: calendar)
        let lastPast = min(end, today)
        func inWeek(_ k: DayKey) -> Bool { k >= start && k <= end }
        func inWeek(_ d: Date) -> Bool { inWeek(DayKey(d, calendar: calendar)) }

        var w = Week(start: start, end: end)
        for it in data.items {
            if it.done, let at = it.doneAt {
                if inWeek(at) {
                    w.done += 1
                    w.byPart[it.part, default: 0] += 1
                }
            } else if !it.done, !it.worry, !it.isSeries, it.seriesID == nil, it.time == nil,
                      let d = it.day, d >= start, d <= lastPast {
                w.open += 1
            }
        }
        w.closed = data.closes.filter { inWeek($0.day) }.count

        let rests = data.rests.filter { inWeek($0.at) }
        w.rests = rests.count
        let rated = rests.compactMap { r in r.before.flatMap { b in r.after.map { (b, $0) } } }
        w.clarity = mean(rated.map { Double($0.1 - $0.0) })
        w.clarityBefore = mean(rated.map { Double($0.0) })
        w.clarityAfter = mean(rated.map { Double($0.1) })

        let dumps = data.dumps.filter { inWeek($0.at) }
        w.dumps = dumps.count
        w.dumped = dumps.reduce(0) { $0 + $1.total }
        w.noise = mean(dumps.map { Double($0.after - $0.before) })
        w.noiseBefore = mean(dumps.map { Double($0.before) })
        w.noiseAfter = mean(dumps.map { Double($0.after) })
        return w
    }

    // MARK: 글

    /// 12주 칸 진하기 0…4 (0 = 빈 칸)
    static func level(_ count: Int) -> Int {
        switch count {
        case ..<1: 0
        case 1: 1
        case 2...3: 2
        case 4...5: 3
        default: 4
        }
    }

    /// "11월 9일–15일" · "10월 27일–11월 2일"
    static func range(_ a: DayKey, _ b: DayKey) -> String {
        a.m == b.m ? "\(a.m)월 \(a.d)일–\(b.d)일" : "\(a.m)월 \(a.d)일–\(b.m)월 \(b.d)일"
    }

    var weekRange: String { Self.range(week.start, week.end) }

    /// 54%
    static func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    /// +2.1 · −3 · 0
    static func signed(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        if r == 0 { return "0" }
        let body = r == r.rounded() ? String(Int(abs(r))) : String(format: "%.1f", abs(r))
        return (r > 0 ? "+" : "−") + body
    }

    /// 예상 대 실제 한 줄. 3번 미만이면 nil
    var focusAdvice: String? {
        guard let r = focusRatio else { return nil }
        let x = String(format: "%.1f", (r * 10).rounded() / 10)
        if r >= 1.15 { return "대체로 예상의 \(x)배 걸려. 길이를 넉넉히 잡아 봐." }
        if r <= 0.85 { return "대체로 예상의 \(x)배면 끝나. 길이를 줄여도 돼." }
        return "대체로 예상한 만큼 걸려."
    }

    /// 가장 많이 끝낸 띠 (같으면 앞 띠, 하나도 없으면 nil)
    var topPart: Part? {
        let best = Part.allCases.max { (week.byPart[$0] ?? 0, -$0.index) < (week.byPart[$1] ?? 0, -$1.index) }
        return best.flatMap { (week.byPart[$0] ?? 0) > 0 ? $0 : nil }
    }

    /// 기록 위의 조용한 한 줄 (나중에 기기 안 AI 글로 바뀐다)
    var reflection: String {
        if isEmpty { return Self.emptyText }
        var parts: [String] = []
        if week.done > 0 { parts.append("이번 주엔 \(week.done)개를 끝냈어") }
        else { parts.append("이번 주엔 아직 끝낸 일이 없어") }
        if week.closed > 0 { parts.append("하루를 \(week.closed)번 닫았어") }
        var line = parts.joined(separator: ", ") + "."
        if let p = topPart { line += " \(p.name)에 가장 많이 끝냈어." }
        if week.rests > 0, let c = week.clarity, c > 0 { line += " 식히고 나면 맑기가 평균 \(Self.signed(c)) 올랐어." }
        else if week.rests > 0 { line += " \(week.rests)번 식혔어." }
        return line
    }

    // MARK: 도우미

    static func median(_ xs: [Double]) -> Double? {
        guard !xs.isEmpty else { return nil }
        let s = xs.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    static func mean(_ xs: [Double]) -> Double? {
        xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }
}
