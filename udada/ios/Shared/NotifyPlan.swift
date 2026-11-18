import Foundation

// 알림 계획. 데이터 → 앞으로 걸 알림 목록. 순수 값 계산이라 하네스·테스트가 그대로 돌린다 (Foundation 만).
// 원칙 (Fitz 2019: 알림을 하루 3번 묶어 받은 쪽이 스트레스가 낮았다):
//   (a) 띠 묶음 알림 — settings.digestTimes, 오늘·내일, 그 띠에 안 끝낸 할 일이 있을 때만
//   (b) 약속 — 시각 − (item.lead ?? settings.eventLead), 앞으로 7일 (반복 포함)
//   (c) 걱정 시간 — 걱정 상자가 비어 있지 않을 때, 오늘·내일
//   (d) 하루 닫기 — closeReminderOn 이고 그날 남은 일이 있을 때, 오늘·내일 (이미 닫은 날은 뺀다)
// 지난 시각은 걸지 않는다. 가까운 순 60개까지 (iOS 는 64개를 지킨다). id 는 늘 같은 규칙 ("ud5.") — 다시 걸면 덮어쓴다.

struct PlannedNote: Hashable, Sendable {
    enum Kind: String, Sendable, CaseIterable { case digest, event, worry, close }
    var id: String
    var fire: Date
    var title: String
    var body: String
    var url: String
    var kind: Kind
    /// 알림 묶음 (종류마다 하나)
    var thread: String { NotifyPlan.prefix + kind.rawValue }
}

/// 집중 모드 필터가 정한 것. 앱 그룹 UserDefaults 에 둔다 (앱·위젯이 같이 읽는다).
struct FocusFilterState: Codable, Hashable, Sendable {
    /// 걱정 시간 알림 끄기
    var muteWorry = false
    /// 묶음 알림만 받기 (약속·걱정·닫기 알림은 쉰다)
    var digestOnly = false
    /// 오늘 화면에서 나중에 숨기기
    var hideLater = false

    static let off = FocusFilterState()
    static let storageKey = "ud5.focusFilter"
    /// 바뀌면 NotificationCenter.default 로 알린다 (오늘 화면이 다시 읽게)
    static let didChange = Notification.Name("ud5.focusFilterDidChange")

    static var defaults: UserDefaults? { UserDefaults(suiteName: DataFile.group) }

    static var current: FocusFilterState {
        guard let raw = defaults?.data(forKey: storageKey),
              let s = try? JSONDecoder().decode(FocusFilterState.self, from: raw) else { return .off }
        return s
    }

    func save() {
        guard let raw = try? JSONEncoder().encode(self) else { return }
        FocusFilterState.defaults?.set(raw, forKey: FocusFilterState.storageKey)
    }

    /// 이 종류의 알림을 걸어도 되나
    func allows(_ kind: PlannedNote.Kind) -> Bool {
        if digestOnly && kind != .digest { return false }
        if muteWorry && kind == .worry { return false }
        return true
    }
}

enum NotifyPlan {
    static let prefix = "ud5."
    static let cap = 60
    static let eventDays = 7
    static let dailyDays = 2

    static func make(_ data: AppData, now: Date, calendar: Calendar = .current, focus: FocusFilterState = .current) -> [PlannedNote] {
        let s = data.settings
        let today = DayKey(now, calendar: calendar)
        var out: [PlannedNote] = []

        func add(_ n: PlannedNote) {
            guard n.fire > now, focus.allows(n.kind) else { return }
            out.append(n)
        }

        // (a) 띠 묶음 알림 — 그 시각에 앱을 열었을 때 보일 모습(settle)으로 센다
        if s.digestOn {
            for offset in 0..<dailyDays {
                let day = today.adding(days: offset, calendar: calendar)
                var seen = Set<Part>()
                for minute in s.digestTimes.sorted() where (0..<1440).contains(minute) {
                    let part = s.parts.part(at: minute)
                    guard seen.insert(part).inserted else { continue }
                    let fire = day.date(minute: minute, calendar: calendar)
                    guard fire > now else { continue }
                    var then = data
                    then.settle(now: fire, calendar: calendar)
                    let sheet = DayLogic.sheet(for: day, data: then, now: fire, calendar: calendar)
                    guard let band = sheet.bands.first(where: { $0.part == part }) else { continue }
                    let open = band.todos.filter { !$0.done }
                    guard let first = open.first else { continue }
                    let rest = open.count - 1
                    add(PlannedNote(id: prefix + "digest.\(day).\(part.rawValue)", fire: fire,
                                    title: "\(part.name) · 할 일 \(open.count)개",
                                    body: rest > 0 ? "\(first.title) 외 \(rest)개" : first.title,
                                    url: "udada://today", kind: .digest))
                }
            }
        }

        // (b) 약속
        if s.eventAlertOn {
            for offset in 0..<eventDays {
                let day = today.adding(days: offset, calendar: calendar)
                for e in data.entries(on: day, calendar: calendar) where !e.done && !e.allDay {
                    guard let time = e.time else { continue }
                    let lead = max(0, e.itemID.flatMap { data.item($0)?.lead } ?? s.eventLead)
                    let at = day.date(minute: time, calendar: calendar)
                    let fire = at.addingTimeInterval(TimeInterval(-lead * 60))
                    add(PlannedNote(id: prefix + "event.\(e.id)", fire: fire,
                                    title: "약속",
                                    body: "\(Fmt.hm(time)) \(e.title) · \(lead == 0 ? "지금" : Fmt.dur(lead) + " 뒤")",
                                    url: "udada://day/\(day)", kind: .event))
                }
            }
        }

        // (c) 걱정 시간
        let worries = data.worries.count
        if s.worryOn && worries > 0 {
            for offset in 0..<dailyDays {
                let day = today.adding(days: offset, calendar: calendar)
                add(PlannedNote(id: prefix + "worry.\(day)", fire: day.date(minute: s.worryTime, calendar: calendar),
                                title: "걱정 시간 · \(worries)개",
                                body: "10분만 보고 다시 내려놓자.",
                                url: "udada://worry", kind: .worry))
            }
        }

        // (d) 하루 닫기
        if s.closeReminderOn {
            let closed = Set(data.closes.map(\.day))
            for offset in 0..<dailyDays {
                let day = today.adding(days: offset, calendar: calendar)
                guard !closed.contains(day) else { continue }
                let fire = day.date(minute: s.closeTime, calendar: calendar)
                guard fire > now else { continue }
                var then = data
                then.settle(now: fire, calendar: calendar)
                let left = DayLogic.sheet(for: day, data: then, now: fire, calendar: calendar).leftovers.count
                guard left > 0 else { continue }
                add(PlannedNote(id: prefix + "close.\(day)", fire: fire,
                                title: "하루 닫기",
                                body: "남은 일 \(left)개. 자리만 정하고 닫자.",
                                url: "udada://close", kind: .close))
            }
        }

        out.sort { ($0.fire, $0.id) < ($1.fire, $1.id) }
        return Array(out.prefix(cap))
    }
}
