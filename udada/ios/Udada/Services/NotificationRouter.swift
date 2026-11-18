import Foundation
import UserNotifications

/// 알림을 눌렀을 때 그 화면으로. 앱이 떠 있을 때는 약속 알림만 배너로 보인다 (나머지는 알림 센터에만).
/// 앱 시작 때 `NotificationRouter.install()` 을 한 번 부른다 (첫 화면이 뜨기 전, App.init 에서).
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationRouter()

    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let kind = notification.request.content.userInfo["kind"] as? String
        return kind == PlannedNote.Kind.event.rawValue ? [.banner, .list, .sound] : [.list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let s = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: s) else { return }
        await AppOpener.open(url)
    }
}

/// 앱 안에서 딥링크를 연다. 막 깨어나 Store 가 아직 없으면 잠깐(최대 3초) 기다린다.
enum AppOpener {
    @MainActor
    static func open(_ url: URL) async {
        for _ in 0..<30 {
            if let store = Store.live { store.open(url); return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
