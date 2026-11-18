import Foundation

// 우다다 v5 데이터 모델. 앱과 위젯 확장이 같이 쓴다 (Foundation 만).
// 새 필드를 더할 때는 init(from:) 에 decodeIfPresent + 기본값을 꼭 넣는다 — 기존 사용자의 저장 파일이 깨지지 않게.

// MARK: - 날짜 키

/// 하루를 가리키는 키. 기기 시간대 기준 yyyy-MM-dd 문자열로 저장한다.
struct DayKey: Hashable, Comparable, Codable, Identifiable, CustomStringConvertible, Sendable {
    let y: Int, m: Int, d: Int

    init(y: Int, m: Int, d: Int) { self.y = y; self.m = m; self.d = d }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(y: c.year!, m: c.month!, d: c.day!)
    }

    static func today(_ now: Date = Date(), calendar: Calendar = .current) -> DayKey { DayKey(now, calendar: calendar) }

    /// 그날 0시
    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// 그날 minute 분의 '벽시계' 시각. 서머타임이 바뀌는 날에도 10:00 은 10:00 (자정부터 흐른 분이 아니라 시·분으로 만든다).
    func date(minute: Int, calendar: Calendar = .current) -> Date {
        let day = minute / 1440, rest = minute % 1440
        let base = day == 0 ? self : adding(days: day, calendar: calendar)
        if let t = calendar.date(from: DateComponents(year: base.y, month: base.m, day: base.d, hour: rest / 60, minute: rest % 60)) { return t }
        return calendar.date(byAdding: .minute, value: minute, to: date(calendar: calendar))!
    }

    func adding(days n: Int, calendar: Calendar = .current) -> DayKey {
        DayKey(calendar.date(byAdding: .day, value: n, to: date(calendar: calendar))!, calendar: calendar)
    }

    /// self 에서 other 까지 며칠 (other 가 뒤면 양수)
    func days(to other: DayKey, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: date(calendar: calendar), to: other.date(calendar: calendar)).day ?? 0
    }

    /// 1 일요일 … 7 토요일
    func weekday(calendar: Calendar = .current) -> Int { calendar.component(.weekday, from: date(calendar: calendar)) }

    /// 이 날이 든 주의 첫날 (월요일 시작이면 월요일)
    func startOfWeek(mondayFirst: Bool = true, calendar: Calendar = .current) -> DayKey {
        let wd = weekday(calendar: calendar)
        let back = mondayFirst ? (wd + 5) % 7 : wd - 1
        return adding(days: -back, calendar: calendar)
    }

    var description: String { String(format: "%04d-%02d-%02d", y, m, d) }
    var id: String { description }

    init?(string s: String) {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        self.init(y: p[0], m: p[1], d: p[2])
    }

    static func < (a: DayKey, b: DayKey) -> Bool { (a.y, a.m, a.d) < (b.y, b.m, b.d) }

    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let k = DayKey(string: s) else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad day \(s)")) }
        self = k
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}

// MARK: - 하루의 세 띠

/// 아침 · 낮 · 저녁. 할 일은 시각 대신 띠에 놓인다 (DAY.md: 시각 없는 일 23% vs 띠·시각 있는 일 50% 완료).
enum Part: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning, afternoon, evening
    var id: String { rawValue }
    var name: String { switch self { case .morning: "아침"; case .afternoon: "낮"; case .evening: "저녁" } }
    var index: Int { Part.allCases.firstIndex(of: self)! }
}

/// 띠의 경계 (분). 기본 06–12 · 12–18 · 18–24.
struct DayParts: Codable, Hashable, Sendable {
    var morningStart = 360
    var afternoonStart = 720
    var eveningStart = 1080
    var dayEnd = 1440

    init() {}

    func range(_ p: Part) -> Range<Int> {
        switch p {
        case .morning: morningStart..<afternoonStart
        case .afternoon: afternoonStart..<eveningStart
        case .evening: eveningStart..<dayEnd
        }
    }

    /// minute 이 속한 띠. 아침 시작 전(새벽)은 아침으로 본다.
    func part(at minute: Int) -> Part {
        if minute >= eveningStart { return .evening }
        if minute >= afternoonStart { return .afternoon }
        return .morning
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let def = DayParts()
        morningStart = try c.decodeIfPresent(Int.self, forKey: .morningStart) ?? def.morningStart
        afternoonStart = try c.decodeIfPresent(Int.self, forKey: .afternoonStart) ?? def.afternoonStart
        eveningStart = try c.decodeIfPresent(Int.self, forKey: .eveningStart) ?? def.eveningStart
        dayEnd = try c.decodeIfPresent(Int.self, forKey: .dayEnd) ?? def.dayEnd
    }
    private enum CodingKeys: String, CodingKey { case morningStart, afternoonStart, eveningStart, dayEnd }
}

// MARK: - 반복

struct RepeatRule: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case daily, weekdays, weekends, weekly, monthly, interval }
    var kind: Kind
    /// weekly: 1 일 … 7 토
    var weekdays: [Int] = []
    /// monthly: 1…31 (그달에 없는 날이면 말일)
    var monthDay: Int? = nil
    /// interval: N일마다
    var every: Int? = nil

    static let daily = RepeatRule(kind: .daily)
    static let weekdaysOnly = RepeatRule(kind: .weekdays)
    static let weekendsOnly = RepeatRule(kind: .weekends)
    static func weekly(_ days: [Int]) -> RepeatRule { RepeatRule(kind: .weekly, weekdays: days.sorted()) }
    static func monthly(_ day: Int) -> RepeatRule { RepeatRule(kind: .monthly, monthDay: day) }
    static func interval(_ n: Int) -> RepeatRule { RepeatRule(kind: .interval, every: max(1, n)) }

    /// start(첫날)부터 시작하는 반복이 day 에 해당하나
    func matches(_ day: DayKey, start: DayKey, calendar: Calendar = .current) -> Bool {
        guard day >= start else { return false }
        let wd = day.weekday(calendar: calendar)
        switch kind {
        case .daily: return true
        case .weekdays: return (2...6).contains(wd)
        case .weekends: return wd == 1 || wd == 7
        case .weekly: return (weekdays.isEmpty ? [start.weekday(calendar: calendar)] : weekdays).contains(wd)
        case .monthly:
            let want = monthDay ?? start.d
            let last = calendar.range(of: .day, in: .month, for: day.date(calendar: calendar))?.count ?? 31
            return day.d == min(want, last)
        case .interval:
            let n = max(1, every ?? 1)
            return start.days(to: day, calendar: calendar) % n == 0
        }
    }

    static let weekdayNames = ["", "일", "월", "화", "수", "목", "금", "토"]

    var label: String {
        switch kind {
        case .daily: return "매일"
        case .weekdays: return "평일"
        case .weekends: return "주말"
        case .weekly:
            if weekdays.isEmpty { return "매주" }
            let order = [2, 3, 4, 5, 6, 7, 1] // 월요일부터 읽는다
            return "매주 " + order.filter(weekdays.contains).map { Self.weekdayNames[$0] }.joined(separator: "·")
        case .monthly: return "매달 \(monthDay ?? 1)일"
        case .interval: return (every ?? 1) == 1 ? "매일" : "\(every ?? 1)일마다"
        }
    }

    init(kind: Kind, weekdays: [Int] = [], monthDay: Int? = nil, every: Int? = nil) {
        self.kind = kind; self.weekdays = weekdays; self.monthDay = monthDay; self.every = every
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        weekdays = try c.decodeIfPresent([Int].self, forKey: .weekdays) ?? []
        monthDay = try c.decodeIfPresent(Int.self, forKey: .monthDay)
        every = try c.decodeIfPresent(Int.self, forKey: .every)
    }
    private enum CodingKeys: String, CodingKey { case kind, weekdays, monthDay, every }
}

// MARK: - 항목

/// 할 일 · 약속 · 걱정 하나.
/// - day == nil && !worry → 나중에 함
/// - worry → 걱정 상자 (걱정 시간에 다시 본다)
/// - time != nil → 약속 (시각이 박힘). nil 이면 띠 안에서 떠 있는 할 일.
/// - repeatRule != nil → 반복 원본. 하루치를 고치거나 끝내면 seriesID 를 단 항목으로 떼어 내고 원본 exceptions 에 그날을 적는다.
struct Item: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var note: String = ""
    var day: DayKey? = nil
    var part: Part = .afternoon
    var time: Int? = nil
    var duration: Int = 30
    var done: Bool = false
    var doneAt: Date? = nil
    var created: Date = Date()
    /// 지난 띠·날에서 조용히 옮겨 온 원래 날
    var movedFrom: DayKey? = nil
    var repeatRule: RepeatRule? = nil
    var exceptions: [DayKey] = []
    var seriesID: UUID? = nil
    var occurrence: DayKey? = nil
    var worry: Bool = false
    /// 오늘의 하나
    var pinned: Bool = false
    /// 집중으로 잰 실제 분
    var spent: Int? = nil
    /// 약속 미리 알림 (분 전). nil 이면 설정 기본값
    var lead: Int? = nil
    /// 비우기에서 들어옴
    var fromDump: Bool = false
    /// 안 끝낸 채 다음 날로 넘어온 횟수 (조용히 옮겨 온 것 + 손으로 뒤로 미룬 것). 끝내거나 풀어 주면 0.
    var moves: Int = 0
    /// '어떻게 할까'를 물은 날 — 그냥 두겠다고 하면 한 주 동안 다시 묻지 않는다
    var stuckAsked: DayKey? = nil

    var isEvent: Bool { time != nil }
    var isLater: Bool { day == nil && !worry }
    var isSeries: Bool { repeatRule != nil }

    init(id: UUID = UUID(), title: String, note: String = "", day: DayKey? = nil, part: Part = .afternoon, time: Int? = nil,
         duration: Int = 30, done: Bool = false, created: Date = Date(), repeatRule: RepeatRule? = nil, worry: Bool = false,
         pinned: Bool = false, lead: Int? = nil, fromDump: Bool = false) {
        self.id = id; self.title = title; self.note = note; self.day = day; self.part = part; self.time = time
        self.duration = duration; self.done = done; self.created = created; self.repeatRule = repeatRule
        self.worry = worry; self.pinned = pinned; self.lead = lead; self.fromDump = fromDump
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        day = try c.decodeIfPresent(DayKey.self, forKey: .day)
        part = try c.decodeIfPresent(Part.self, forKey: .part) ?? .afternoon
        time = try c.decodeIfPresent(Int.self, forKey: .time)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration) ?? 30
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        doneAt = try c.decodeIfPresent(Date.self, forKey: .doneAt)
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        movedFrom = try c.decodeIfPresent(DayKey.self, forKey: .movedFrom)
        repeatRule = try c.decodeIfPresent(RepeatRule.self, forKey: .repeatRule)
        exceptions = try c.decodeIfPresent([DayKey].self, forKey: .exceptions) ?? []
        seriesID = try c.decodeIfPresent(UUID.self, forKey: .seriesID)
        occurrence = try c.decodeIfPresent(DayKey.self, forKey: .occurrence)
        worry = try c.decodeIfPresent(Bool.self, forKey: .worry) ?? false
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        spent = try c.decodeIfPresent(Int.self, forKey: .spent)
        lead = try c.decodeIfPresent(Int.self, forKey: .lead)
        fromDump = try c.decodeIfPresent(Bool.self, forKey: .fromDump) ?? false
        moves = try c.decodeIfPresent(Int.self, forKey: .moves) ?? 0
        stuckAsked = try c.decodeIfPresent(DayKey.self, forKey: .stuckAsked)
    }
    private enum CodingKeys: String, CodingKey {
        case id, title, note, day, part, time, duration, done, doneAt, created, movedFrom, repeatRule, exceptions, seriesID, occurrence, worry, pinned, spent, lead, fromDump, moves, stuckAsked
    }
}

// MARK: - 기록

enum RestKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case breath, far, walk
    var id: String { rawValue }
    var name: String { switch self { case .breath: "숨 고르기"; case .far: "멀리 보기"; case .walk: "걷기" } }
    var minutes: Int { switch self { case .breath: 1; case .far: 3; case .walk: 10 } }
    var how: String {
        switch self {
        case .breath: "코로 두 번 들이쉬고, 입으로 길게 내쉬어."
        case .far: "폰을 엎어 두고, 창밖 가장 먼 곳을 봐."
        case .walk: "폰은 주머니에. 될 수 있으면 밖으로."
        }
    }
    var why: String {
        switch self {
        case .breath: "하루 5분 이 호흡이 명상보다 기분을 더 올렸어 (Balban 2023)"
        case .far: "초록을 40초 본 쪽이 주의를 더 오래 지켰어 (Lee 2015)"
        case .walk: "쉬는 시간이 길수록 회복이 컸고, 폰으로 쉬면 가장 덜 쉬어졌어 (Albulescu 2022)"
        }
    }
    var symbol: String { switch self { case .breath: "wind"; case .far: "mountain.2"; case .walk: "figure.walk" } }
}

/// 식히기 한 번. 맑기는 0–10, 고르지 않았으면 nil.
struct RestLog: Codable, Hashable, Sendable {
    var at: Date
    var kind: RestKind
    var seconds: Int
    var before: Int? = nil
    var after: Int? = nil
}

/// 비우기 한 번. 머리 소음 0–10 전후와 칸별 개수.
struct DumpLog: Codable, Hashable, Sendable {
    var at: Date
    var before: Int
    var after: Int
    var now: Int = 0
    var dated: Int = 0
    var worry: Int = 0
    var dropped: Int = 0
    var total: Int { now + dated + worry + dropped }
}

/// 하루 닫기 한 번.
struct CloseLog: Codable, Hashable, Sendable {
    var day: DayKey
    var at: Date
    var done: Int
    var tomorrow: Int
    var later: Int
    var dropped: Int
}

/// 집중 한 번: 예상과 실제 (분).
struct FocusLog: Codable, Hashable, Sendable {
    var at: Date
    var title: String
    var planned: Int
    var spent: Int
    var finished: Bool
}

/// 지금 돌고 있는 집중 (앱을 다시 열어도 이어진다)
struct ActiveFocus: Codable, Hashable, Sendable {
    var itemID: UUID?
    var title: String
    var planned: Int
    var started: Date
}

// MARK: - 설정

enum Appearance: String, Codable, CaseIterable, Sendable {
    case system, light, dark
    var name: String { switch self { case .system: "기기 설정"; case .light: "밝게"; case .dark: "어둡게" } }
}

/// 앱 테마. 종이 · 먹 · 강조 하나라는 규칙은 같고 색만 다르다 (색은 Shared/Theme.swift 의 Palette).
enum ThemeID: String, Codable, CaseIterable, Identifiable, Sendable {
    case paper, sand, forest, plum, ink
    var id: String { rawValue }
    var name: String {
        switch self {
        case .paper: "종이"
        case .sand: "모래"
        case .forest: "숲"
        case .plum: "자두"
        case .ink: "먹"
        }
    }
    /// 고르는 화면의 한 줄
    var note: String {
        switch self {
        case .paper: "회녹색 종이에 코발트"
        case .sand: "따뜻한 모래 종이에 주홍"
        case .forest: "이끼 낀 종이에 솔잎 초록"
        case .plum: "연보라 종이에 자두"
        case .ink: "무채색, 도장만 붉게"
        }
    }
}

struct Settings: Codable, Hashable, Sendable {
    var parts = DayParts()
    var mondayFirst = true
    /// 띠마다 할 일 묶음 알림 (하루 3번, Fitz 2019)
    var digestOn = true
    var digestTimes = [510, 750, 1110] // 08:30 · 12:30 · 18:30
    var eventAlertOn = true
    var eventLead = 10
    var worryOn = true
    var worryTime = 1290 // 21:30
    var closeReminderOn = false
    var closeTime = 1260 // 21:00
    var calendarOn = false
    var hiddenCalendars: [String] = []
    var haptics = true
    var sounds = true
    var appearance: Appearance = .system
    /// 길이를 안 쓰면 넣는 기본 길이
    var defaultDuration = 30
    /// 기기 안 AI(Apple 지능) 쓰기. 꺼도 규칙으로 같은 흐름이 돈다.
    var aiOn = true
    /// 숏폼 앱 앞에 끼어드는 '잠깐' 화면 (단축어 자동화로 켬)
    var gateOn = true
    /// 내 iCloud 로 iPhone·Mac 을 맞춘다 (이 기기에서만 끄고 켠다)
    var syncOn = true
    /// 앱 테마 (이 기기에서만)
    var theme: ThemeID = .paper

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings.fallback
        parts = try c.decodeIfPresent(DayParts.self, forKey: .parts) ?? d.parts
        mondayFirst = try c.decodeIfPresent(Bool.self, forKey: .mondayFirst) ?? d.mondayFirst
        digestOn = try c.decodeIfPresent(Bool.self, forKey: .digestOn) ?? d.digestOn
        digestTimes = try c.decodeIfPresent([Int].self, forKey: .digestTimes) ?? d.digestTimes
        eventAlertOn = try c.decodeIfPresent(Bool.self, forKey: .eventAlertOn) ?? d.eventAlertOn
        eventLead = try c.decodeIfPresent(Int.self, forKey: .eventLead) ?? d.eventLead
        worryOn = try c.decodeIfPresent(Bool.self, forKey: .worryOn) ?? d.worryOn
        worryTime = try c.decodeIfPresent(Int.self, forKey: .worryTime) ?? d.worryTime
        closeReminderOn = try c.decodeIfPresent(Bool.self, forKey: .closeReminderOn) ?? d.closeReminderOn
        closeTime = try c.decodeIfPresent(Int.self, forKey: .closeTime) ?? d.closeTime
        calendarOn = try c.decodeIfPresent(Bool.self, forKey: .calendarOn) ?? d.calendarOn
        hiddenCalendars = try c.decodeIfPresent([String].self, forKey: .hiddenCalendars) ?? d.hiddenCalendars
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        sounds = try c.decodeIfPresent(Bool.self, forKey: .sounds) ?? d.sounds
        appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? d.appearance
        defaultDuration = try c.decodeIfPresent(Int.self, forKey: .defaultDuration) ?? d.defaultDuration
        aiOn = try c.decodeIfPresent(Bool.self, forKey: .aiOn) ?? d.aiOn
        gateOn = try c.decodeIfPresent(Bool.self, forKey: .gateOn) ?? d.gateOn
        syncOn = try c.decodeIfPresent(Bool.self, forKey: .syncOn) ?? d.syncOn
        theme = (try? c.decodeIfPresent(ThemeID.self, forKey: .theme)) ?? d.theme
    }
    private static let fallback = Settings()
    private enum CodingKeys: String, CodingKey {
        case parts, mondayFirst, digestOn, digestTimes, eventAlertOn, eventLead, worryOn, worryTime, closeReminderOn, closeTime
        case calendarOn, hiddenCalendars, haptics, sounds, appearance, defaultDuration, aiOn, gateOn, syncOn, theme
    }
}

// MARK: - 전체 저장 데이터

struct AppData: Codable, Sendable {
    var version = 5
    var items: [Item] = []
    var rests: [RestLog] = []
    var dumps: [DumpLog] = []
    var closes: [CloseLog] = []
    var focus: [FocusLog] = []
    var settings = Settings()
    var seenIntro = false
    var activeFocus: ActiveFocus? = nil
    /// 마지막으로 '하루 열기' 요약을 본 날
    var briefedDay: DayKey? = nil

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 5
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        rests = try c.decodeIfPresent([RestLog].self, forKey: .rests) ?? []
        dumps = try c.decodeIfPresent([DumpLog].self, forKey: .dumps) ?? []
        closes = try c.decodeIfPresent([CloseLog].self, forKey: .closes) ?? []
        focus = try c.decodeIfPresent([FocusLog].self, forKey: .focus) ?? []
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        seenIntro = try c.decodeIfPresent(Bool.self, forKey: .seenIntro) ?? false
        activeFocus = try c.decodeIfPresent(ActiveFocus.self, forKey: .activeFocus)
        briefedDay = try c.decodeIfPresent(DayKey.self, forKey: .briefedDay)
    }
    private enum CodingKeys: String, CodingKey { case version, items, rests, dumps, closes, focus, settings, seenIntro, activeFocus, briefedDay }
}

// MARK: - 글자 도우미

enum Fmt {
    /// 14:05
    static func hm(_ minute: Int) -> String { String(format: "%02d:%02d", (minute / 60) % 24, minute % 60) }
    /// 30분 · 1시간 · 1시간 30분
    static func dur(_ m: Int) -> String {
        if m < 60 { return "\(m)분" }
        return m % 60 == 0 ? "\(m / 60)시간" : "\(m / 60)시간 \(m % 60)분"
    }
    /// 오후 3시 · 오전 9시 30분 (말로 읽기용)
    static func spoken(_ minute: Int) -> String {
        let h = (minute / 60) % 24, mi = minute % 60
        let ap = h < 12 ? "오전" : "오후"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return mi == 0 ? "\(ap) \(h12)시" : "\(ap) \(h12)시 \(mi)분"
    }
    static let weekday = ["", "일", "월", "화", "수", "목", "금", "토"]

    /// 받침에 맞춘 '으로/로': 아침 → 아침으로, 내일 → 내일로, 오후 → 오후로
    static func ro(_ s: String) -> String {
        guard let last = s.unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else { return s + "로" }
        let jong = (last.value - 0xAC00) % 28
        return s + (jong == 0 || jong == 8 ? "로" : "으로")
    }

    /// 오늘 · 내일 · 모레 · 11월 20일 (금)
    static func day(_ k: DayKey?, today: DayKey) -> String {
        guard let k else { return "나중에" }
        switch today.days(to: k) {
        case 0: return "오늘"
        case 1: return "내일"
        case 2: return "모레"
        case -1: return "어제"
        default: return "\(k.m)월 \(k.d)일 (\(weekday[k.weekday()]))"
        }
    }
}
