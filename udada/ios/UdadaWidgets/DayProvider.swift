import SwiftUI
import WidgetKit

// 오늘 위젯·잠금 화면 위젯이 같이 쓰는 타임라인. 기기 달력(EventKit)은 확장에서 읽지 않는다.

struct WDayEntry: TimelineEntry {
    let date: Date
    let sheet: DaySheet
    let parts: DayParts
    /// 작은 화면(SE 등)의 큰 위젯이면 띠마다 줄을 덜 보인다
    var compact = false
    /// 이 분부터 「하루 닫기」를 내민다 (닫기 알림 1시간 전, 저녁 띠보다 이르지 않게)
    var closeFrom = 1200

    /// 스마트 스택이 이 위젯을 언제 앞으로 올릴지: 약속이 1시간 안이면 가장 높게, 하루를 닫을 때·남은 할 일이 있을 때는 그다음.
    var relevance: TimelineEntryRelevance? {
        guard sheet.isToday, let now = sheet.now else { return nil }
        if let next = now.next, now.gap <= 60 { return TimelineEntryRelevance(score: 100, duration: TimeInterval(max(1, now.gap) * 60)) }
        if now.current != nil { return TimelineEntryRelevance(score: 80, duration: 30 * 60) }
        if wantsClose { return TimelineEntryRelevance(score: 70, duration: 60 * 60) }
        if now.fit != nil { return TimelineEntryRelevance(score: 40, duration: 60 * 60) }
        return TimelineEntryRelevance(score: sheet.openTodos > 0 ? 20 : 0)
    }

    /// 남은 약속이 없고 하루를 닫을 때가 됐다
    var wantsClose: Bool {
        guard let n = sheet.now, n.next == nil, n.current == nil else { return false }
        return n.minute >= closeFrom
    }
}

struct WDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> WDayEntry {
        WSample.entry(now: Date(), compact: Self.isCompact(context))
    }

    func getSnapshot(in context: Context, completion: @escaping (WDayEntry) -> Void) {
        let now = Date()
        let data = DataFile.load()
        Ink.theme = data.settings.theme // 위젯도 고른 테마로
        // 위젯 고르기 화면에서 빈 하루면 예시를 보여 준다
        if context.isPreview && data.items.isEmpty {
            completion(WSample.entry(now: now, compact: Self.isCompact(context)))
        } else {
            completion(WDay.entry(data: data, at: now, compact: Self.isCompact(context)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WDayEntry>) -> Void) {
        let now = Date()
        let data = DataFile.load()
        Ink.theme = data.settings.theme // 위젯도 고른 테마로
        let compact = Self.isCompact(context)
        let entries = WDay.dates(data: data, now: now).map { WDay.entry(data: data, at: $0, compact: compact) }
        let midnight = DayKey(now).adding(days: 1).date()
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    private static func isCompact(_ context: Context) -> Bool {
        context.family == .systemLarge && context.displaySize.height < 350
    }
}

enum WDay {
    static let maxEntries = 20

    /// 그 시각의 하루 한 장. 앱처럼 지난 띠의 안 끝낸 일을 지금 띠로 옮겨 본다 (저장은 안 함).
    static func entry(data: AppData, at date: Date, compact: Bool) -> WDayEntry {
        var d = data
        d.settle(now: date)
        let sheet = DayLogic.sheet(for: DayKey(date), data: d, now: date)
        let closeFrom = max(d.settings.parts.eveningStart, d.settings.closeTime - 60)
        return WDayEntry(date: date, sheet: sheet, parts: d.settings.parts, compact: compact, closeFrom: closeFrom)
    }

    /// 지금 + 앞으로 24시간 안의 띠 경계 · 약속 시작/끝 · 시작 20분 전 · 자정 (최대 20개)
    static func dates(data: AppData, now: Date, calendar: Calendar = .current) -> [Date] {
        let horizon = now.addingTimeInterval(24 * 3600)
        let parts = data.settings.parts
        let today = DayKey(now, calendar: calendar)
        var marks = Set<Date>()
        for offset in 0...1 {
            let day = today.adding(days: offset, calendar: calendar)
            let closeFrom = max(parts.eveningStart, data.settings.closeTime - 60)
            for m in [0, parts.morningStart, parts.afternoonStart, parts.eveningStart, closeFrom] {
                marks.insert(day.date(minute: m, calendar: calendar))
            }
            for e in data.entries(on: day, calendar: calendar) where !e.allDay && !e.done {
                guard let t = e.time else { continue }
                marks.insert(day.date(minute: t - 20, calendar: calendar))
                marks.insert(day.date(minute: t, calendar: calendar))
                marks.insert(day.date(minute: t + e.duration, calendar: calendar))
            }
        }
        let upcoming = marks.filter { $0 > now && $0 <= horizon }.sorted().prefix(maxEntries - 1)
        return [now] + upcoming
    }
}

// MARK: - 링크

enum WLink {
    static let today = URL(string: "udada://today")!
    static let add = URL(string: "udada://add")!
    static let close = URL(string: "udada://close")!
    static func day(_ k: DayKey) -> URL { URL(string: "udada://day/\(k.description)")! }
}

// MARK: - 예시 (위젯 고르기 · 미리보기)

enum WSample {
    static func data(now: Date) -> AppData {
        var d = AppData()
        let t = DayKey(now)
        func mk(_ title: String, _ part: Part, time: Int? = nil, dur: Int = 30, n: Int) -> Item {
            Item(title: title, day: t, part: part, time: time, duration: dur, created: now.addingTimeInterval(Double(n)))
        }
        d.items = [
            mk("메일 답장", .morning, dur: 15, n: 0),
            mk("팀 회의", .morning, time: 600, dur: 60, n: 1),
            mk("보고서 초안", .afternoon, dur: 30, n: 2),
            mk("택배 보내기", .afternoon, dur: 15, n: 3),
            mk("치과", .afternoon, time: 900, dur: 60, n: 4),
            mk("저녁 약속", .evening, time: 1170, dur: 90, n: 5),
            mk("빨래 개기", .evening, dur: 15, n: 6),
        ]
        d.items[0].done = true
        return d
    }

    static func entry(now: Date, compact: Bool = false) -> WDayEntry {
        WDay.entry(data: data(now: now), at: now, compact: compact)
    }

    /// 미리보기용: 오늘 hh:mm
    static func at(_ minute: Int) -> Date { DayKey(Date()).date(minute: minute) }
}
