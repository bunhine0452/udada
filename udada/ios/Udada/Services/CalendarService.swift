import EventKit
import Foundation

/// 기기 달력(EventKit) 읽기. 읽기만 하고, 바꾸거나 밖으로 보내지 않는다.
@MainActor
final class CalendarService {
    static let shared = CalendarService()

    struct Source: Identifiable, Hashable { var id: String; var title: String; var color: UInt32 }

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?

    private init() {
        // 달력이 바뀌면 (다른 앱에서 약속을 넣거나 지우면) 스스로 다시 읽는다
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            Task { @MainActor in CalendarService.shared.scheduleRefresh() }
        }
    }

    /// 전체 접근이 허락돼 있나
    var authorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    /// 허락을 묻는다 (설정·첫 실행에서 '기기 달력 연결'을 누를 때만)
    func requestAccess() async -> Bool {
        let ok = (try? await store.requestFullAccessToEvents()) ?? false
        if ok { store.reset() }
        if let s = Store.live { refresh(s) }
        return ok
    }

    /// 고를 수 있는 달력들
    func sources() -> [Source] {
        guard authorized else { return [] }
        return store.calendars(for: .event)
            .sorted { ($0.source?.title ?? "", $0.title) < ($1.source?.title ?? "", $1.title) }
            .map { Source(id: $0.calendarIdentifier, title: $0.title, color: Self.hex($0.cgColor)) }
    }

    /// from 부터 days 일 동안의 약속을 Entry(.external)로. hidden 달력은 뺀다.
    func entries(from: DayKey, days: Int, hidden: [String]) -> [Entry] {
        guard authorized, days > 0 else { return [] }
        let hiddenSet = Set(hidden)
        let calendars = store.calendars(for: .event).filter { !hiddenSet.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }

        let cal = Calendar.current
        let last = from.adding(days: days - 1, calendar: cal)
        let start = from.date(calendar: cal)
        let end = from.adding(days: days, calendar: cal).date(calendar: cal)
        let parts = Store.live?.settings.parts ?? DayParts()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)

        var out: [Entry] = []
        for ev in store.events(matching: predicate) {
            guard let s = ev.startDate, let e = ev.endDate else { continue }
            let title = (ev.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let color = ev.calendar.map { Self.hex($0.cgColor) }
            let calName = ev.calendar?.title
            let base = ev.calendarItemIdentifier

            if ev.isAllDay {
                // 여러 날 종일 약속은 날마다 한 줄씩
                let firstDay = max(DayKey(s, calendar: cal), from)
                let lastDay = min(DayKey(e > s ? e.addingTimeInterval(-1) : s, calendar: cal), last)
                guard firstDay <= lastDay else { continue }
                var d = firstDay
                while d <= lastDay {
                    out.append(Entry(source: .external(id: "\(base)@\(d)"), title: title, day: d, part: .morning, time: nil,
                                     duration: 0, done: false, color: color, calendarName: calName, allDay: true))
                    d = d.adding(days: 1, calendar: cal)
                }
            } else {
                let day = DayKey(s, calendar: cal)
                guard day >= from, day <= last else { continue }
                let minute = minuteOfDay(s, calendar: cal)
                let length = Int(e.timeIntervalSince(s) / 60)
                let duration = max(0, min(length, 1440 - minute))
                out.append(Entry(source: .external(id: "\(base)@\(day)"), title: title, day: day, part: parts.part(at: minute),
                                 time: minute, duration: duration, done: false, color: color, calendarName: calName))
            }
        }
        return out
    }

    /// store.external 을 다시 채운다 (켜져 있고 허락됐을 때만). 달력이 바뀌면 스스로 부른다.
    func refresh(_ store: Store) {
        guard store.settings.calendarOn, authorized else {
            if !store.external.isEmpty { store.external = [] }
            return
        }
        store.external = entries(from: store.today.adding(days: -7), days: 60, hidden: store.settings.hiddenCalendars)
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let s = Store.live else { return }
            refresh(s)
        }
    }

    private static func hex(_ cg: CGColor?) -> UInt32 {
        guard let cg else { return 0x8B9691 }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let rgb = cg.converted(to: space, intent: .defaultIntent, options: nil)?.components, rgb.count >= 3 else { return 0x8B9691 }
        let r = rgb[0], g = rgb[1], b = rgb[2]
        func c(_ v: CGFloat) -> UInt32 { UInt32((min(1, max(0, v)) * 255).rounded()) }
        return c(r) << 16 | c(g) << 8 | c(b)
    }
}
