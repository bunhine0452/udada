import Foundation
import UserNotifications

/// 알림 일정. 계산은 NotifyPlan(순수), 여기서는 걸고 지우기만 한다.
@MainActor
enum Notifier {
    /// 알림이 허락돼 있나 (마지막으로 확인한 값)
    static var authorized = false
    private static var pending: Task<Void, Never>?

    /// 허락을 묻는다. 필요할 때만 (처음 날짜 정하기·약속 넣기·설정에서 켤 때).
    static func requestPermission() async -> Bool {
        let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshStatus()
        if ok, let store = Store.live { reschedule(store.data, now: store.now) }
        return ok
    }

    /// 현재 허락 상태를 다시 읽는다
    static func refreshStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        authorized = [.authorized, .provisional, .ephemeral].contains(s.authorizationStatus)
    }

    /// 데이터가 바뀔 때마다 불린다. 앞으로의 알림을 다시 계산해 건다 (0.8초 몰아서).
    static func reschedule(_ data: AppData, now: Date) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await apply(data, now: now)
        }
    }

    /// 바로 다시 건다 (집중 필터처럼 백그라운드에서 짧게 깨어났을 때)
    static func rescheduleNow(_ data: AppData, now: Date) async {
        pending?.cancel()
        pending = nil
        await apply(data, now: now)
    }

    private static func apply(_ data: AppData, now: Date) async {
        let center = UNUserNotificationCenter.current()
        await refreshStatus()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(NotifyPlan.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        guard authorized else { return }

        let calendar = Calendar.current
        let sound = data.settings.sounds
        for note in NotifyPlan.make(data, now: now, calendar: calendar, focus: .current) {
            let content = UNMutableNotificationContent()
            content.title = note.title
            content.body = note.body
            content.threadIdentifier = note.thread
            content.userInfo = ["url": note.url, "kind": note.kind.rawValue]
            // 집중 모드 필터가 시스템에서 거를 때 쓰는 꼬리표 (UdadaFocusFilter.appContext)
            content.filterCriteria = note.kind.rawValue
            if sound { content.sound = .default }
            if note.kind == .event { content.relevanceScore = 1 } else { content.relevanceScore = 0.5 }
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: note.fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: note.id, content: content, trigger: trigger))
        }
    }
}
