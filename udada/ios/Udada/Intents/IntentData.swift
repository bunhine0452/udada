import Foundation
import WidgetKit

/// App Intents 가 데이터를 읽고 쓰는 곳. 앱이 떠 있으면 Store 로 (화면·되돌리기와 같은 길),
/// 아니면 파일을 직접 읽고 써서 위젯·알림·Spotlight 를 새로 고친다.
@MainActor
enum IntentData {
    static var now: Date { Store.live?.now ?? Date() }
    static var today: DayKey { DayKey(now) }

    static func read() -> AppData {
        if let s = Store.live { return s.data }
        var d = DataFile.load()
        d.settle(now: now)
        return d
    }

    static func write(_ body: (inout AppData) -> Void) async {
        if let s = Store.live {
            s.change(body)
            return
        }
        var d = DataFile.load()
        d.settle(now: now)
        body(&d)
        DataFile.save(d)
        WidgetCenter.shared.reloadAllTimelines()
        SpotlightIndex.refresh(d)
        await Notifier.rescheduleNow(d, now: now)
    }

    /// 그날의 한 장 (기기 달력 약속 포함)
    static func sheet(for day: DayKey) -> DaySheet {
        if let s = Store.live { return s.sheet(for: day) }
        let d = read()
        let ext = d.settings.calendarOn ? CalendarService.shared.entries(from: day, days: 1, hidden: d.settings.hiddenCalendars) : []
        return DayLogic.sheet(for: day, data: d, external: ext, now: now)
    }

    /// 앱을 열고 그 주소로 (openAppWhenRun 인텐트에서)
    static func open(_ url: String) async {
        guard let u = URL(string: url) else { return }
        await AppOpener.open(u)
    }
}
