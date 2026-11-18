import Foundation

// 하루 한 장의 계산과 변경. 순수 값 연산이라 앱·위젯·테스트가 같이 쓴다.

/// 화면에 보이는 한 줄: 저장된 항목 · 반복의 하루치 · 기기 달력 약속
struct Entry: Identifiable, Hashable, Sendable {
    enum Source: Hashable, Sendable {
        case item(UUID)
        case occurrence(series: UUID, day: DayKey)
        case external(id: String)
    }
    var source: Source
    var title: String
    var note: String = ""
    var day: DayKey
    var part: Part
    var time: Int?
    var duration: Int
    var done: Bool
    var repeating: Bool = false
    var movedFrom: DayKey? = nil
    var pinned: Bool = false
    var fromDump: Bool = false
    /// 기기 달력 색 0xRRGGBB
    var color: UInt32? = nil
    var calendarName: String? = nil
    var allDay: Bool = false
    var created: Date = .distantPast

    var id: String {
        switch source {
        case .item(let u): "i:" + u.uuidString
        case .occurrence(let s, let d): "o:" + s.uuidString + ":" + d.description
        case .external(let e): "e:" + e
        }
    }
    var isEvent: Bool { time != nil }
    var isExternal: Bool { if case .external = source { true } else { false } }
    var itemID: UUID? {
        switch source {
        case .item(let u): u
        case .occurrence(let s, _): s
        case .external: nil
        }
    }
    var end: Int? { time.map { $0 + duration } }
}

/// 띠 하나의 상태
struct Band: Identifiable, Hashable, Sendable {
    var part: Part
    var range: Range<Int>
    var events: [Entry]
    var todos: [Entry]
    /// 오늘이고 이미 지난 띠
    var gone: Bool
    /// 오늘이고 지금 이 띠
    var live: Bool
    /// 지금부터 띠 끝까지, 약속을 뺀 빈 시간
    var free: Int
    /// 안 끝낸 할 일 길이 합
    var planned: Int
    var id: Part { part }
    var overflow: Int { max(0, planned - free) }
    var isEmpty: Bool { events.isEmpty && todos.isEmpty }
    var openTodos: Int { todos.filter { !$0.done }.count }
}

/// 지금 줄: 다음 약속까지 실제로 남은 시간과 거기 들어가는 일 (Tonietto, Malkoc & Nowlis 2019)
struct NowLine: Hashable, Sendable {
    var minute: Int
    var next: Entry?
    var current: Entry?
    var gap: Int
    var fit: Entry?
    var headline: String
    var advice: String
}

struct DaySheet: Hashable, Sendable {
    var day: DayKey
    var isToday: Bool
    var allDay: [Entry]
    var bands: [Band]
    var now: NowLine?
    var openTodos: Int { bands.reduce(0) { $0 + $1.openTodos } }
    var doneTodos: Int { bands.reduce(0) { $0 + $1.todos.filter(\.done).count } }
    var eventCount: Int { bands.reduce(0) { $0 + $1.events.count } }
    var freeTotal: Int { bands.reduce(0) { $0 + $1.free } }
    var plannedTotal: Int { bands.reduce(0) { $0 + $1.planned } }
    var isEmpty: Bool { allDay.isEmpty && bands.allSatisfy(\.isEmpty) }
    /// 할 일이 있었고 전부 끝냈다 (쉼 카드를 띄울 때)
    var allTodosDone: Bool {
        let todos = bands.flatMap(\.todos)
        return !todos.isEmpty && todos.allSatisfy(\.done)
    }
    /// 하루 닫기에서 자리를 정할 것: 오늘 안 끝낸 할 일 (반복의 하루치는 빼고)
    var leftovers: [Entry] { bands.flatMap(\.todos).filter { !$0.done && !$0.repeating } }
}

enum CloseChoice: String, Sendable { case tomorrow, later, drop }

func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
    let c = calendar.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

// MARK: - 읽기

extension AppData {
    func item(_ id: UUID) -> Item? { items.first { $0.id == id } }

    var laterItems: [Item] { items.filter { $0.isLater && !$0.done && !$0.isSeries }.sorted { $0.created < $1.created } }
    var worries: [Item] { items.filter { $0.worry && !$0.done }.sorted { $0.created < $1.created } }

    /// 그날 보일 것. 반복은 하루치로 펼치고, 기기 달력 약속은 external 로 받는다.
    func entries(on day: DayKey, external: [Entry] = [], calendar: Calendar = .current) -> [Entry] {
        var out: [Entry] = []
        for it in items {
            if let rule = it.repeatRule {
                guard let start = it.day, !it.exceptions.contains(day), rule.matches(day, start: start, calendar: calendar) else { continue }
                out.append(Entry(source: .occurrence(series: it.id, day: day), title: it.title, note: it.note, day: day, part: it.part,
                                 time: it.time, duration: it.duration, done: false, repeating: true, pinned: false, created: it.created))
            } else if it.day == day && !it.worry {
                out.append(Entry(source: .item(it.id), title: it.title, note: it.note, day: day, part: it.part, time: it.time,
                                 duration: it.duration, done: it.done, repeating: it.seriesID != nil, movedFrom: it.movedFrom,
                                 pinned: it.pinned, fromDump: it.fromDump, created: it.created))
            }
        }
        out += external.filter { $0.day == day }
        return out
    }

    /// 날마다 무언가 있는지 (달력 점)
    func hasEntries(on day: DayKey, calendar: Calendar = .current) -> Bool {
        items.contains { it in
            if let rule = it.repeatRule, let start = it.day {
                // 매일 하는 할 일(물 한 잔 같은)은 모든 날에 점을 찍어 점이 아무 말도 안 하게 만든다 — 점에서 뺀다
                let everyDay = rule.kind == .daily || (rule.kind == .interval && (rule.every ?? 1) == 1)
                if everyDay && it.time == nil { return false }
                return !it.exceptions.contains(day) && rule.matches(day, start: start, calendar: calendar)
            }
            return it.day == day && !it.worry && !it.done
        }
    }
}

enum DayLogic {
    static func sheet(for day: DayKey, data: AppData, external: [Entry] = [], now: Date = Date(), calendar: Calendar = .current) -> DaySheet {
        let parts = data.settings.parts
        let today = DayKey(now, calendar: calendar)
        let isToday = day == today
        let m = minuteOfDay(now, calendar: calendar)
        let all = data.entries(on: day, external: external, calendar: calendar)
        let allDay = all.filter(\.allDay)
        let timed = all.filter { !$0.allDay }
        let livePart = parts.part(at: m)

        var bands: [Band] = []
        for p in Part.allCases {
            let r = parts.range(p)
            let inP = timed.filter { e in e.time.map { parts.part(at: $0) == p } ?? (e.part == p) }
            let events = inP.filter(\.isEvent).sorted { ($0.time ?? 0, $0.title) < ($1.time ?? 0, $1.title) }
            let todos = inP.filter { !$0.isEvent }.sorted { a, b in
                if a.pinned != b.pinned { return a.pinned }
                return a.created < b.created
            }
            let gone = isToday && r.upperBound <= m
            let live = isToday && livePart == p
            let from = isToday ? max(m, r.lowerBound) : r.lowerBound
            let free = gone ? 0 : max(0, r.upperBound - from - busyMinutes(timed, in: from..<r.upperBound))
            let planned = todos.filter { !$0.done }.reduce(0) { $0 + $1.duration }
            bands.append(Band(part: p, range: r, events: events, todos: todos, gone: gone, live: live, free: free, planned: planned))
        }

        var nowLine: NowLine?
        if isToday {
            let upcoming = timed.filter { ($0.time ?? -1) > m }.sorted { ($0.time ?? 0) < ($1.time ?? 0) }
            let next = upcoming.first
            let current = timed.first { e in e.time.map { $0 <= m && m < $0 + e.duration } ?? false }
            let gap = (next?.time ?? parts.dayEnd) - m
            let liveTodos = bands.first { $0.live }?.todos.filter { !$0.done } ?? []
            // 하루 닫기 시각이 지났고 남은 약속이 없으면 새 일을 권하지 않는다 (안 끝난 일은 저녁 반추와 잠을 해친다 — Syrek 2014)
            let late = next == nil && current == nil && m >= data.settings.closeTime
            let fit = late ? nil : (liveTodos.first { $0.pinned && $0.duration <= gap } ?? liveTodos.first { $0.duration <= gap })
            var headline = next.map { "\($0.title)까지 \(Fmt.dur(gap))" } ?? "남은 약속 없음"
            if let c = current, let end = c.end { headline = "\(c.title) 중 · \(Fmt.dur(max(1, end - m))) 남음" }
            let advice: String
            if current != nil { advice = "끝나면 숨 한 번 쉬고 다음으로." }
            else if late { advice = liveTodos.isEmpty ? "오늘은 여기까지. 푹 쉬어." : "늦었어. 남은 건 하루 닫기로 자리만 정하자." }
            else if let f = fit { advice = "‘\(f.title)’ \(Fmt.dur(f.duration)), 지금 들어가." }
            else if next != nil && gap < 20 { advice = "새로 시작하기엔 짧아. 숨 한 번." }
            else if liveTodos.isEmpty { advice = "비어 있어. 쉬어도 돼." }
            else { advice = "남은 일이 \(Fmt.dur(gap))보다 길어. 조금만 해도 돼." }
            nowLine = NowLine(minute: m, next: next, current: current, gap: gap, fit: fit, headline: headline, advice: advice)
        }
        return DaySheet(day: day, isToday: isToday, allDay: allDay, bands: bands, now: nowLine)
    }

    /// window 안에서 약속이 차지한 분. 띠 경계를 넘는 약속은 걸친 띠마다, 겹치는 약속은 한 번만 센다.
    private static func busyMinutes(_ entries: [Entry], in window: Range<Int>) -> Int {
        let spans = entries.compactMap { e -> Range<Int>? in
            guard let t = e.time else { return nil }
            let lo = max(t, window.lowerBound), hi = min(t + e.duration, window.upperBound)
            return lo < hi ? lo..<hi : nil
        }.sorted { $0.lowerBound < $1.lowerBound }
        var total = 0, reach = window.lowerBound
        for s in spans where s.upperBound > reach {
            total += s.upperBound - max(s.lowerBound, reach)
            reach = s.upperBound
        }
        return total
    }

    /// 나중에 함에 오래 있었나 (버림은 10일째에 굳는다 — Halder 2026)
    static func age(_ item: Item, today: DayKey, calendar: Calendar = .current) -> Int {
        DayKey(item.created, calendar: calendar).days(to: today, calendar: calendar)
    }
}

// MARK: - 바꾸기

extension AppData {
    mutating func add(_ item: Item) { items.append(item) }

    mutating func update(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
    }

    /// 반복의 하루치를 실제 항목으로 떼어 낸다. 이미 항목이면 그 id.
    /// 이미 떼어 낸 하루치면 (위젯·화면이 늦게 갱신돼 같은 하루치가 다시 와도) 그 항목을 돌려준다 — 두 벌 만들지 않는다.
    @discardableResult
    mutating func materialize(_ source: Entry.Source) -> UUID? {
        switch source {
        case .item(let id): return items.contains { $0.id == id } ? id : nil
        case .external: return nil
        case .occurrence(let sid, let day):
            if let have = child(of: sid, on: day) { return have.id }
            guard let si = items.firstIndex(where: { $0.id == sid }) else { return nil }
            var s = items[si]
            if !s.exceptions.contains(day) { s.exceptions.append(day) }
            items[si] = s
            var one = Item(title: s.title, note: s.note, day: day, part: s.part, time: s.time, duration: s.duration, lead: s.lead)
            one.seriesID = sid
            one.occurrence = day
            items.append(one)
            return one.id
        }
    }

    mutating func setDone(_ source: Entry.Source, _ done: Bool, now: Date = Date()) {
        guard let id = materialize(source) else { return }
        update(id) { $0.done = done; $0.doneAt = done ? now : nil }
    }

    mutating func toggleDone(_ source: Entry.Source, now: Date = Date()) {
        if case .item(let id) = source, let it = item(id) { setDone(source, !it.done, now: now) }
        else { setDone(source, true, now: now) }
    }

    /// 다른 날·띠로. day == nil 이면 나중에 함. 약속은 날만 바뀌고 시각은 그대로.
    mutating func move(_ source: Entry.Source, to day: DayKey?, part: Part? = nil) {
        guard let id = materialize(source) else { return }
        let taken = day.map { pinTaken(on: $0, except: id) } ?? false
        update(id) { it in
            if it.day != day && taken { it.pinned = false } // 오늘의 하나는 그날 하나만
            // 손으로 뒤로 미룬 것도 '넘어온 횟수'에 센다. 나중에 함으로 보내면 풀린 것이다.
            if let old = it.day, let day, day > old, !it.done, it.time == nil { it.moves += 1 } else if day == nil { it.moves = 0; it.stuckAsked = nil }
            it.day = day
            it.movedFrom = nil
            it.worry = false
            if day == nil { it.time = nil; it.pinned = false }
            if let part, it.time == nil { it.part = part }
        }
    }

    /// 지우기. 반복의 하루치는 그날만 빼고, wholeSeries 면 원본까지.
    mutating func remove(_ source: Entry.Source, wholeSeries: Bool = false) {
        switch source {
        case .item(let id):
            if wholeSeries, let it = item(id), let sid = it.seriesID ?? (it.isSeries ? it.id : nil) { removeSeries(sid) }
            items.removeAll { $0.id == id }
        case .occurrence(let sid, let day):
            if wholeSeries { removeSeries(sid); return }
            update(sid) { if !$0.exceptions.contains(day) { $0.exceptions.append(day) } }
            if let have = child(of: sid, on: day) { items.removeAll { $0.id == have.id } }
        case .external: break
        }
    }

    /// 반복 원본과 아직 안 끝낸 하루치들. 끝낸 하루치는 기록으로 남긴다.
    private mutating func removeSeries(_ sid: UUID) {
        items.removeAll { $0.id == sid || ($0.seriesID == sid && !$0.done) }
    }

    private func child(of sid: UUID, on day: DayKey) -> Item? { items.first { $0.seriesID == sid && $0.occurrence == day } }

    private func pinTaken(on day: DayKey, except id: UUID) -> Bool { items.contains { $0.day == day && $0.pinned && $0.id != id } }

    /// 오늘의 하나: 그날 하나만
    mutating func pin(_ source: Entry.Source, day: DayKey) {
        guard let id = materialize(source) else { return }
        let was = item(id)?.pinned ?? false
        for i in items.indices where items[i].day == day { items[i].pinned = false }
        update(id) { $0.pinned = !was }
    }

    /// 지난 날·지난 띠의 안 끝낸 할 일을 지금 띠로 조용히 옮긴다. '밀림' 표시 없음 (시각 박은 일도 78%는 늦게 끝난다).
    mutating func settle(now: Date = Date(), calendar: Calendar = .current) {
        let today = DayKey(now, calendar: calendar)
        let cur = settings.parts.part(at: minuteOfDay(now, calendar: calendar))
        for i in items.indices {
            let it = items[i]
            guard !it.done, it.time == nil, !it.worry, it.repeatRule == nil, it.seriesID == nil, let d = it.day else { continue }
            if d < today {
                if it.pinned && pinTaken(on: today, except: it.id) { items[i].pinned = false }
                items[i].movedFrom = it.movedFrom ?? d
                items[i].moves = it.moves + 1
                items[i].day = today
                items[i].part = cur
            } else if d == today && it.part.index < cur.index {
                items[i].part = cur
            }
        }
    }

    // MARK: 여러 번 넘어온 일

    /// 오늘 한 장에서 '어떻게 할까'를 물어볼 일 하나: 세 번 넘게 넘어온, 시각 없는 안 끝낸 일. 가장 많이 넘어온 것부터.
    /// 한 번에 하나만 묻고, 그냥 두겠다고 한 일은 한 주 동안 다시 묻지 않는다 — 밀린 것을 늘어놓아 탓하지 않는다.
    func stuck(today: DayKey, calendar: Calendar = .current) -> Item? {
        items.filter { it in
            guard !it.done, it.day == today, it.time == nil, !it.worry, it.repeatRule == nil, it.seriesID == nil, it.moves >= 3 else { return false }
            if let asked = it.stuckAsked, asked.adding(days: 7, calendar: calendar) > today { return false }
            return true
        }
        .max { ($0.moves, $1.created) < ($1.moves, $0.created) }
    }

    /// 그냥 둘게: 한 주 동안 다시 묻지 않는다
    mutating func keepStuck(_ id: UUID, today: DayKey) {
        update(id) { $0.stuckAsked = today }
    }

    /// 풀렸다 (쪼갰거나 날짜를 박았다): 횟수를 다시 센다
    mutating func settleStuck(_ id: UUID) {
        update(id) { $0.moves = 0; $0.stuckAsked = nil }
    }

    /// 하루 닫기의 한 장
    mutating func apply(_ choice: CloseChoice, to source: Entry.Source, today: DayKey, calendar: Calendar = .current) {
        switch choice {
        case .tomorrow: move(source, to: today.adding(days: 1, calendar: calendar), part: .morning)
        case .later: move(source, to: nil)
        case .drop: remove(source)
        }
    }

    /// 걱정 상자로
    mutating func toWorry(_ source: Entry.Source) {
        guard let id = materialize(source) else { return }
        update(id) { $0.worry = true; $0.day = nil; $0.time = nil; $0.pinned = false }
    }
}
