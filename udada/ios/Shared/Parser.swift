import Foundation

// 한국어 한 줄 읽기. "내일 3시 치과" · "보고서 30분" · "매주 월수금 아침 운동".
// 규칙 기반이라 예측할 수 있고, 키 입력마다 불러도 될 만큼 빠르다 (정규식은 한 번만 컴파일).
// 읽은 낱말은 표식으로 바꿔 지우고, 남은 글자는 건드리지 않는다 — 제목을 망가뜨리지 않는다.

/// 한 줄에서 읽어 낸 것. 미리보기와 항목 만들기에 쓴다.
struct Parsed: Equatable {
    /// 날짜·시각 낱말을 뺀 제목. 그런 낱말만 썼으면 ""
    var title: String
    /// 날짜·요일 낱말이 있으면 그날 (반복이면 첫날)
    var day: DayKey? = nil
    /// 나중에 · 언젠가 · 시간 날 때
    var later: Bool = false
    /// 0시부터 분 (0..<1440). 있으면 약속
    var time: Int? = nil
    /// 길이 (분, 1...1440)
    var duration: Int? = nil
    /// 시각이 없을 때 띠 낱말
    var part: Part? = nil
    var repeatRule: RepeatRule? = nil
}

enum Parser {
    static func parse(_ text: String, now: Date = Date(), parts: DayParts = DayParts(), calendar: Calendar = .current) -> Parsed {
        var out = Parsed(title: "")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return out }

        var line = Line(" " + trimmed + " ")
        let today = DayKey(now, calendar: calendar)
        let hm = calendar.dateComponents([.hour, .minute], from: now)
        let nowMin = (hm.hour ?? 0) * 60 + (hm.minute ?? 0)
        let todayWD = today.weekday(calendar: calendar)
        // 월요일에 시작하는 주. 일요일에는 이미 다음 주를 '이번 주'로 본다 (일요일의 "다음 주 수요일" = 열흘 뒤).
        let weekStart = today.adding(days: 1, calendar: calendar).startOfWeek(mondayFirst: true, calendar: calendar)
        func inWeek(_ weeks: Int, _ wd: Int) -> DayKey { weekStart.adding(days: weeks * 7 + mondayOffset(wd), calendar: calendar) }

        var day: DayKey?
        var weekdayTarget: Int?
        var rule: RepeatRule?
        var weeklyFromStart = false

        // 나중에
        if line.take(R.later, { _, _ in .cut }) { out.later = true }

        // 반복 — 요일·N일 낱말을 품고 있으니 날짜보다 먼저
        if line.take(R.interval, mark: Line.day, { g, _ in
            let n = g[1].flatMap { Int($0) } ?? ["하루": 1, "이틀": 2, "사흘": 3, "나흘": 4, "격일": 2][g[2] ?? g[3] ?? ""] ?? 0
            guard (1...365).contains(n) else { return .skip }
            rule = n == 1 ? .daily : .interval(n); return .cut
        }) {}
        else if line.take(R.daily, mark: Line.day, { _, _ in rule = .daily; return .cut }) {}
        else if line.take(R.weekends, mark: Line.day, { _, _ in rule = .weekendsOnly; return .cut }) {}
        else if line.take(R.weekdays, mark: Line.day, { _, _ in rule = .weekdaysOnly; return .cut }) {}
        else if line.take(R.monthly, mark: Line.day, { g, _ in
            if let s = g[1] {
                guard let n = Int(s), (1...31).contains(n) else { return .skip }
                rule = .monthly(n)
            } else { rule = .monthly(today.d) }
            return .cut
        }) {}
        else if line.take(R.weeklyPrefix, mark: Line.day, { g, _ in
            if let list = g[1] { rule = .weekly(weekdays(in: list)) } else { weeklyFromStart = true; rule = .weekly([]) }
            return .cut
        }) {}
        else if line.take(R.weeklySuffix, mark: Line.day, { g, _ in
            let days = weekdays(in: g[1] ?? ""); guard !days.isEmpty else { return .skip }
            rule = .weekly(days); return .cut
        }) {}

        // N분 뒤 · N시간 반 뒤 → 지금부터
        if line.take(R.relTime, { g, _ in
            guard let n = number(g[1]) else { return .skip }
            var mins = g[2] == "시간" ? n * 60 : n
            if g[3] != nil { guard g[2] == "시간" else { return .skip }; mins += 30 }
            if let m = g[4].flatMap({ Int($0) }) { guard g[2] == "시간", m < 60 else { return .skip }; mins += m }
            guard mins > 0, mins <= 7 * 1440 else { return .skip }
            let total = nowMin + mins
            day = today.adding(days: total / 1440, calendar: calendar); out.time = total % 1440
            return .cut
        }) {}

        // N일 뒤 · 2주 후 · 한 달 뒤
        if day == nil { line.take(R.relDay, mark: Line.day, { g, _ in
            if let s = g[1], let n = Int(s) {
                guard n > 0, n <= 3650 else { return .skip }
                day = today.adding(days: g[2] == "주" ? n * 7 : n, calendar: calendar); return .cut
            }
            if let s = g[3], let n = Int(s) ?? (s.hasPrefix("한") ? 1 : nil) {
                guard n > 0, n <= 120, let d = calendar.date(byAdding: .month, value: n, to: today.date(calendar: calendar)) else { return .skip }
                day = DayKey(d, calendar: calendar); return .cut
            }
            let words = ["하루": 1, "이틀": 2, "사흘": 3, "나흘": 4, "일주일": 7]
            let w = (g[4] ?? "").replacingOccurrences(of: " ", with: "")
            guard let n = words[w] ?? (w == "한주" ? 7 : nil) else { return .skip }
            day = today.adding(days: n, calendar: calendar); return .cut
        }) }

        // 12월 3일 · 12/3 · 12.3 · 20일
        if day == nil { line.take(R.monthDay, mark: Line.day, { g, _ in
            guard let m = Int(g[2] ?? ""), let d = Int(g[3] ?? "") else { return .skip }
            if let ys = g[1] {
                guard let y = Int(ys), let k = valid(y, m, d, calendar) else { return .skip }
                day = k; return .cut
            }
            guard let k = nextDate(m, d, from: today, calendar) else { return .skip }
            day = k; return .cut
        }) }
        if day == nil { line.take(R.slashDate, mark: Line.day, { g, _ in
            guard let m = Int(g[1] ?? ""), let d = Int(g[2] ?? ""), let k = nextDate(m, d, from: today, calendar) else { return .skip }
            day = k; return .cut
        }) }
        if day == nil { line.take(R.bareDay, mark: Line.day, { g, _ in
            guard let d = Int(g[1] ?? ""), (1...31).contains(d) else { return .skip }
            var y = today.y, m = today.m
            for _ in 0..<13 {
                if let k = valid(y, m, d, calendar), k >= today { day = k; return .cut }
                m += 1; if m > 12 { m = 1; y += 1 }
            }
            return .skip
        }) }

        // 오늘 · 내일 · 모레 · 글피
        if day == nil { line.take(R.dayWord, mark: Line.day, { g, _ in
            let n = ["오늘": 0, "내일": 1, "낼": 1, "모레": 2, "내일모레": 2, "글피": 3][g[1] ?? ""] ?? 0
            day = today.adding(days: n, calendar: calendar); return .cut
        }) }

        // 이번 주 금요일 · 다음 주 수요일 · 주말 · 다음 주
        if day == nil { line.take(R.weekWeekday, mark: Line.day, { g, _ in
            guard let wd = weekdays(in: g[2] ?? "").first else { return .skip }
            let weeks = weekShift(g[1])
            day = (weeks == 0 && wd == 1 && todayWD == 1) ? today : inWeek(weeks, wd)
            return .cut
        }) }
        if day == nil { line.take(R.weekend, mark: Line.day, { g, _ in
            // 지금 주말(일요일이면 어제 토요일)부터 센다
            let sat = todayWD == 1 ? today.adding(days: -1, calendar: calendar) : today.adding(days: 7 - todayWD, calendar: calendar)
            let weeks = weekShift(g[1])
            day = weeks == 0 ? (todayWD == 1 ? today : sat) : sat.adding(days: weeks * 7, calendar: calendar)
            return .cut
        }) }
        if day == nil { line.take(R.nextWeek, mark: Line.day, { g, _ in
            day = inWeek(weekShift(g[1]), 2); return .cut
        }) }

        // 금요일 · 금욜
        if day == nil { line.take(R.weekday, mark: Line.day, { g, _ in
            guard let wd = weekdays(in: g[1] ?? "").first else { return .skip }
            weekdayTarget = wd; return .cut
        }) }

        let explicitDay = day != nil || weekdayTarget != nil || rule != nil
        // '7시 동창 모임', '8시 회식'처럼 저녁에 하는 일이면 오전·오후 표시가 없어도 저녁으로
        let evening = text.range(of: #"회식|모임|동창|술자리|한잔|맥주|소주|와인|파티|데이트|공연|콘서트|영화|뒤풀이|야식|저녁"#, options: .regularExpression) != nil

        // 시각 · 범위
        if out.time == nil {
            if line.take(R.hmRange, { g, _ in
                guard let h1 = Int(g[1] ?? ""), let m1 = Int(g[2] ?? ""), let h2 = Int(g[3] ?? ""), let m2 = Int(g[4] ?? ""),
                      h1 < 24, h2 <= 24, m1 < 60, m2 < 60 else { return .skip }
                let s = h1 * 60 + m1
                var e = h2 * 60 + m2
                if e <= s { e += 1440 }
                guard e - s <= 1440 else { return .skip }
                out.time = s; out.duration = e - s; return .cut
            }) {}
            else if line.take(R.clockRange, { g, _ in
                guard let h1 = Int(g[2] ?? ""), let h2 = Int(g[6] ?? "") else { return .skip }
                let m1 = g[3] != nil ? 30 : Int(g[4] ?? "") ?? 0
                let m2 = g[7] != nil ? 30 : Int(g[8] ?? "") ?? 0
                guard (0...24).contains(h1), (0...24).contains(h2), m1 < 60, m2 < 60 else { return .skip }
                var e: Int
                if let q2 = g[5] {
                    guard let v = clock(h2, m2, qual: q2, explicitDay: true, nowMin: nowMin) else { return .skip }
                    e = v
                } else { e = (h2 % 24) * 60 + m2 }
                var s: Int
                if let q1 = g[1] {
                    guard let v = clock(h1, m1, qual: q1, explicitDay: explicitDay, nowMin: nowMin, evening: evening) else { return .skip }
                    s = v
                } else if g[5] != nil {
                    // 끝에만 오전/오후가 있으면 시작은 끝보다 앞서는 쪽으로
                    let raw = (h1 % 12) * 60 + m1
                    s = raw + 720 < e ? raw + 720 : raw
                } else {
                    guard let v = clock(h1, m1, qual: nil, explicitDay: explicitDay, nowMin: nowMin, evening: evening) else { return .skip }
                    s = v
                }
                if g[5] == nil { var n = 0; while e <= s && n < 2 { e += 720; n += 1 } }
                if e <= s { e += 1440 }
                guard e - s <= 1440 else { return .skip }
                out.time = s; out.duration = e - s; return .cut
            }) {}
            else if line.take(R.clock, { g, _ in
                guard let h = Int(g[2] ?? "") else { return .skip }
                let m = g[3] != nil ? 30 : Int(g[4] ?? "") ?? 0
                guard let v = clock(h, m, qual: g[1], explicitDay: explicitDay, nowMin: nowMin, evening: evening) else { return .skip }
                out.time = v; return .cut
            }) {}
            else if line.take(R.hm, { g, _ in
                guard var h = Int(g[2] ?? ""), let m = Int(g[3] ?? ""), h < 24, m < 60 else { return .skip }
                if let q = g[1], afternoonQuals.contains(q), h < 12 { h += 12 }
                out.time = h * 60 + m; return .cut
            }) {}
            else if line.take(R.noon, { _, _ in out.time = 720; return .cut }) {}
        }

        // 길이
        if out.duration == nil {
            if line.take(R.hours, { g, _ in
                guard let s = g[1] else { return .skip }
                var mins: Int
                if let n = number(s) { mins = n * 60 } else if let f = Double(s) { mins = Int((f * 60).rounded()) } else { return .skip }
                if g[2] != nil { mins += 30 }
                if let m = g[3].flatMap({ Int($0) }) { guard m < 60 else { return .skip }; mins += m }
                guard (1...1440).contains(mins) else { return .skip }
                out.duration = mins; return .cut
            }) {}
            else if line.take(R.minutes, { g, _ in
                guard let n = Int(g[1] ?? ""), (1...1440).contains(n) else { return .skip }
                out.duration = n; return .cut
            }) {}
            else if line.take(R.halfDay, { _, _ in out.duration = 240; return .cut }) {}
        }

        // 띠 낱말 — 조사가 붙었거나 날짜 낱말 바로 뒤일 때만 제목에서 뺀다
        if out.time == nil {
            line.take(R.band, { g, before in
                guard let w = g[1], let p = bandPart[w] else { return .skip }
                out.part = p
                if g[2] == "마다", rule == nil { rule = .daily }
                let afterDay = before.last(where: { !$0.isWhitespace }).map { String($0) == Line.day } ?? false
                return g[2] != nil || afterDay ? .cut : .keep
            })
        }

        // 날짜 정하기
        if let wd = weekdayTarget {
            var n = (wd - todayWD + 7) % 7
            if n == 0, let t = out.time, t < nowMin { n = 7 }
            day = today.adding(days: n, calendar: calendar)
        }
        if var r = rule {
            var start = day ?? today
            if day == nil, let t = out.time, t < nowMin { start = today.adding(days: 1, calendar: calendar) }
            if weeklyFromStart { r = .weekly([start.weekday(calendar: calendar)]) }
            var k = start, n = 0
            while n < 400 && !r.matches(k, start: start, calendar: calendar) { k = k.adding(days: 1, calendar: calendar); n += 1 }
            day = k
            out.repeatRule = r
        }
        out.day = out.later ? nil : day
        if out.later { out.repeatRule = nil }
        out.title = cleanTitle(line.s)
        return out
    }

    /// 여러 줄 붙여넣기 → 줄마다 한 항목. 빈 줄은 버리고 목록 기호를 뗀다.
    static func split(_ text: String) -> [String] {
        text.components(separatedBy: .newlines).compactMap { raw in
            var s = raw.trimmingCharacters(in: .whitespaces)
            for _ in 0..<3 {
                let ns = s as NSString
                guard let m = R.bullet.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { break }
                s = ns.substring(from: m.range.length).trimmingCharacters(in: .whitespaces)
            }
            return s.isEmpty ? nil : s
        }
    }

    // MARK: - 도우미

    private static let afternoonQuals: Set<String> = ["오후", "낮", "점심", "저녁", "밤"]
    private static let bandPart: [String: Part] = [
        "아침": .morning, "오전": .morning, "새벽": .morning,
        "낮": .afternoon, "점심": .afternoon, "오후": .afternoon,
        "저녁": .evening, "밤": .evening,
    ]

    /// H시 M분 → 0시부터 분. 오후류는 +12, 새벽은 그대로, 아무것도 없으면 1–6시는 오후, 지난 7–11시와 저녁 일(모임·회식…)의 7–11시는 저녁으로.
    private static func clock(_ h0: Int, _ m: Int, qual: String?, explicitDay: Bool, nowMin: Int, evening: Bool = false) -> Int? {
        guard (0...24).contains(h0), (0...59).contains(m) else { return nil }
        var h = h0 == 24 ? 0 : h0
        switch qual {
        case "밤"?:
            if h == 12 { h = 0 } else if h >= 5 && h < 12 { h += 12 }
        case let q? where afternoonQuals.contains(q):
            if h < 12 { h += 12 }
        case "오전"?, "아침"?, "새벽"?:
            if h == 12 { h = 0 }
        case nil:
            if (1...6).contains(h) { h += 12 }
            else if (7...11).contains(h) && (evening || (!explicitDay && h * 60 + m < nowMin)) { h += 12 }
        default: break
        }
        guard h < 24 else { return nil }
        return h * 60 + m
    }

    private static let nativeNumbers = ["한": 1, "두": 2, "세": 3, "네": 4, "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9, "열": 10, "열한": 11, "열두": 12]
    private static func number(_ s: String?) -> Int? {
        guard let s else { return nil }
        return Int(s) ?? nativeNumbers[s]
    }

    /// "월수금" · "월요일" · "화, 목" → [2, 4, 6] (1 일 … 7 토)
    private static func weekdays(in s: String) -> [Int] {
        let bare = s.replacingOccurrences(of: "요일", with: "").replacingOccurrences(of: "욜", with: "")
        let names = Array("일월화수목금토")
        return Array(Set(bare.compactMap { c in names.firstIndex(of: c).map { $0 + 1 } })).sorted()
    }

    /// 월요일 0 … 일요일 6
    private static func mondayOffset(_ wd: Int) -> Int { (wd + 5) % 7 }

    private static func weekShift(_ w: String?) -> Int {
        switch w { case "다음"?, "담"?: 1; case "다다음"?: 2; default: 0 }
    }

    private static func valid(_ y: Int, _ m: Int, _ d: Int, _ cal: Calendar) -> DayKey? {
        guard (1...12).contains(m), (1...31).contains(d),
              let date = cal.date(from: DateComponents(year: y, month: m, day: d)) else { return nil }
        let k = DayKey(date, calendar: cal)
        return k.m == m && k.d == d ? k : nil
    }

    /// 올해 그날, 이미 지났으면 내년
    private static func nextDate(_ m: Int, _ d: Int, from today: DayKey, _ cal: Calendar) -> DayKey? {
        for y in today.y...(today.y + 4) {
            if let k = valid(y, m, d, cal), k >= today { return k }
        }
        return nil
    }

    /// 표식을 지우고 공백·쉼표·마침표를 다듬는다. 조사(에·까지·부터)는 읽은 낱말 바로 옆에 홀로 남았을 때만 뗀다.
    private static func cleanTitle(_ s: String) -> String {
        let tokens = s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let isMark = { (t: String) in t == Line.day || t == Line.other }
        let particles: Set<String> = ["에", "에는", "까지", "부터"]
        var kept: [String] = []
        for (i, t) in tokens.enumerated() where !isMark(t) {
            let nearMark = (i > 0 && isMark(tokens[i - 1])) || (i + 1 < tokens.count && isMark(tokens[i + 1]))
            if particles.contains(t) && nearMark { continue }
            kept.append(t)
        }
        let junk = CharacterSet(charactersIn: ",.·、").union(.whitespaces)
        return kept.joined(separator: " ").trimmingCharacters(in: junk)
    }
}

// MARK: - 줄 다루기

private enum Take { case skip, cut, keep }

private struct Line {
    static let day = "\u{1}"   // 날짜·반복 낱말 자리 (띠 낱말이 바로 뒤인지 볼 때 쓴다)
    static let other = "\u{2}" // 그 밖에 읽은 낱말 자리

    var s: String
    init(_ s: String) { self.s = s }

    /// 첫 번째로 받아들여진 일치를 표식으로 바꾼다. f 는 캡처(0 = 전체)와 일치 앞의 글을 받는다.
    @discardableResult
    mutating func take(_ re: NSRegularExpression, mark: String = Line.other, _ f: (_ g: [String?], _ before: String) -> Take) -> Bool {
        let ns = s as NSString
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            let g: [String?] = (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            switch f(g, ns.substring(to: m.range.location)) {
            case .skip: continue
            case .keep: return true
            case .cut:
                s = ns.replacingCharacters(in: m.range, with: " \(mark) ")
                return true
            }
        }
        return false
    }
}

// MARK: - 정규식 (한 번만 만든다)

private enum R {
    static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }

    /// 낱말 왼쪽 경계
    static let L = #"(?<=[\s,!?\x{1}\x{2}])"#
    /// 낱말 오른쪽 경계
    static let E = #"(?=[\s,.!?\x{1}\x{2}])"#
    /// 날짜 낱말 오른쪽 경계 — 띠 낱말이 붙어 와도 된다 (내일저녁)
    static let ED = #"(?=[\s,.!?\x{1}\x{2}]|아침|오전|낮|점심|오후|저녁|밤|새벽)"#
    /// 날짜 뒤 조사
    static let P = #"(?:까지|에는|에도|에|엔|부터|은|는|도|쯤)?"#
    static let Q = #"(오전|오후|아침|낮|점심|저녁|밤|새벽)"#
    static let NUM = #"(\d+|열한|열두|다섯|여섯|일곱|여덟|아홉|한|두|세|네|열)"#
    static let WD = #"[월화수목금토일]"#
    static let HMIN = #"(?:\s*(반)|\s*(\d{1,2})\s*분)?"#

    static let later = rx(L + #"(?:나중에|언젠가는?|시간\s*(?:날\s*때|나면|될\s*때))"# + E)

    static let interval = rx(L + #"(?:(\d+)\s*일\s*마다|(하루|이틀|사흘|나흘)\s*마다|(격일))"# + P + ED)
    static let daily = rx(L + #"(?:매일|날마다)"# + ED)
    static let weekends = rx(L + #"(?:주말마다|매\s*주말|매주\s+주말)"# + P + ED)
    static let weekdays = rx(L + #"(?:평일마다|평일|주중)"# + P + ED)
    static let monthly = rx(L + #"(?:매달|매월)(?:\s*(\d{1,2})\s*일)?(?:마다)?"# + P + ED)
    static let weeklyPrefix = rx(L + #"매주(?:\s*((?:"# + WD + #"(?:요일|욜)?[\s,·・/]*)*"# + WD + #"(?:요일|욜)?))?(?:마다)?"# + P + ED)
    static let weeklySuffix = rx(L + #"((?:"# + WD + #"(?:요일|욜)?[,·・/]?)+)\s*마다"# + P + ED)

    static let relTime = rx(L + NUM + #"\s*(시간|분)(?:\s*(반)|\s*(\d{1,2})\s*분)?\s*(?:뒤|후)(?:에)?"# + E)
    static let relDay = rx(L + #"(?:(\d+)\s*(일|주)|(\d+|한)\s*(?:달|개월)|(하루|이틀|사흘|나흘|일주일|한\s*주))\s*(?:뒤|후)"# + P + ED)

    static let monthDay = rx(L + #"(?:(\d{4})\s*년\s*)?(\d{1,2})\s*월\s*(\d{1,2})\s*일"# + P + ED)
    static let slashDate = rx(L + #"(\d{1,2})[/.](\d{1,2})"# + P + ED)
    static let bareDay = rx(L + #"(\d{1,2})\s*일"# + P + #"(?!\s*(?:뒤|후|전|마다|동안|간|째|정도))"# + ED)
    static let dayWord = rx(L + #"(내일모레|오늘|내일|낼|모레|글피)"# + P + ED)

    static let weekWeekday = rx(L + #"(이번|요번|다음|담|다다음)\s*주\s*("# + WD + #")(?:요일|욜)(?:날)?"# + P + ED)
    static let weekend = rx(L + #"(?:(이번|요번|다음|담|다다음)\s*)?주말"# + P + ED)
    static let nextWeek = rx(L + #"(다음|담|다다음)\s*주"# + P + ED)
    static let weekday = rx(L + "(" + WD + #")(?:요일|욜)(?:날)?"# + P + ED)

    static let hmRange = rx(L + #"(\d{1,2}):(\d{2})\s*[-~–]\s*(\d{1,2}):(\d{2})(?:까지)?"# + E)
    static let clockRange = rx(L + #"(?:"# + Q + #"\s*)?(\d{1,2})(?:\s*시(?!간)"# + HMIN + #")?\s*(?:부터|에서|~|-|–)\s*(?:"# + Q + #"\s*)?(\d{1,2})\s*시(?!간)"# + HMIN + #"(?:까지)?"# + E)
    static let clock = rx(L + #"(?:"# + Q + #"\s*)?(\d{1,2})\s*시(?!간)"# + HMIN + #"(?:에는|에|쯤|경|부터|까지)?"# + E)
    static let hm = rx(L + #"(?:"# + Q + #"\s*)?(\d{1,2}):(\d{2})(?:에는|에|쯤|부터|까지)?"# + E)
    static let noon = rx(L + #"정오(?:에|쯤|부터|까지)?"# + E)

    static let hours = rx(L + #"(\d+\.\d+|"# + String(NUM.dropFirst()) + #"\s*시간(?:\s*(반)|\s*(\d{1,2})\s*분)?(?:\s*(?:동안|정도|쯤|가량)|간)?"# + E)
    static let minutes = rx(L + #"(\d+)\s*분(?:\s*(?:동안|정도|쯤|가량)|간)?"# + E)
    static let halfDay = rx(L + #"반나절(?:\s*동안)?"# + E)

    static let band = rx(L + Q + #"(에는|에|엔|부터|까지|쯤|마다)?"# + E)

    static let bullet = rx(#"^(?:[-•*·▪◦‣–—]\s+|\d{1,3}[.)]\s+|[☐☑✓✔]\s*|\[\s?[xX✓]?\s?\]\s*)"#)
}
