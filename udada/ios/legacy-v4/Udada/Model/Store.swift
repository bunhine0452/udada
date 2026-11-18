import Foundation
import UserNotifications

/// UserDefaults 에 JSON 으로. 기기 밖으로 나가지 않는다.
@MainActor
final class Store {
    static let shared = Store()
    private let d = UserDefaults.standard
    private enum K { static let items = "ud4.items", sessions = "ud4.sessions", seen = "ud4.seen", noise = "ud4.noise", worryHour = "ud4.worryHour" }

    init() {
        if ProcessInfo.processInfo.arguments.contains("-udReset") {
            [K.items, K.sessions, K.seen, K.noise, K.worryHour].forEach(d.removeObject)
        }
    }

    var items: [Item] {
        get { load(K.items) ?? [] }
        set { save(newValue, K.items); Reminders.sync(newValue) }
    }
    var sessions: [Session] {
        get { load(K.sessions) ?? [] }
        set { save(newValue, K.sessions) }
    }
    var seenIntro: Bool {
        get { d.bool(forKey: K.seen) }
        set { d.set(newValue, forKey: K.seen) }
    }
    var lastNoise: Int {
        get { d.object(forKey: K.noise) as? Int ?? 6 }
        set { d.set(newValue, forKey: K.noise) }
    }

    /// 지금까지 닫은 고리 (버린 것 포함)
    var closedTotal: Int { sessions.reduce(0) { $0 + $1.total } }
    var open: [Item] { items.filter { !$0.done } }
    /// 오늘 할 것: 지금 칸 + 오늘 안에 때가 오는 날짜 칸
    func today(_ now: Date = Date()) -> [Item] {
        let end = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        return open.filter { $0.bin == .now || ($0.bin == .date && ($0.due ?? .distantFuture) < end) }
            .sorted { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
    }

    func markDone(_ id: UUID) {
        var all = items
        if let i = all.firstIndex(where: { $0.id == id }) { all[i].done = true }
        items = all
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private func save<T: Encodable>(_ value: T, _ key: String) {
        d.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

/// '언제'를 진짜로: 날짜 칸은 그때, 걱정 칸은 매일 걱정 시간(21:30)에 모아서 알림.
enum Reminders {
    static let worryHour = 21, worryMinute = 30
    static let prefix = "ud.item."

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// 알림으로 만들 것만 계산 (테스트용으로 분리)
    static func plan(_ items: [Item], now: Date = Date()) -> [(id: String, date: Date, body: String)] {
        var out: [(String, Date, String)] = []
        for it in items where !it.done && it.bin == .date {
            if let due = it.due, due > now { out.append((prefix + it.id.uuidString, due, "정해 둔 시간이야 · \(it.text)")) }
        }
        let worries = items.filter { !$0.done && $0.bin == .worry }
        if !worries.isEmpty {
            let cal = Calendar.current
            var t = cal.date(bySettingHour: worryHour, minute: worryMinute, second: 0, of: now)!
            if t <= now { t = cal.date(byAdding: .day, value: 1, to: t)! }
            out.append(("ud.worry", t, "걱정 시간 · \(worries.count)개. 10분만 보고 다시 내려놓자."))
        }
        return out
    }

    static func sync(_ items: [Item]) {
        let c = UNUserNotificationCenter.current()
        c.getPendingNotificationRequests { pending in
            c.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) || $0 == "ud.worry" })
            for p in plan(items) {
                let content = UNMutableNotificationContent()
                content.title = "우다다"; content.body = p.body; content.sound = .default
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: p.date)
                c.add(UNNotificationRequest(identifier: p.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }
}
