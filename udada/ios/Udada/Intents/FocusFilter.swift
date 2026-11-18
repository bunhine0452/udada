import AppIntents
import Foundation

/// 집중 모드 필터: 설정 > 집중 모드 > 필터 > 우다다. 켜고 끌 때마다 시스템이 perform 을 부른다.
/// 고른 것은 앱 그룹 UserDefaults(FocusFilterState) 에 두고, 알림을 바로 다시 건다.
struct UdadaFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "우다다 알림 줄이기"
    static let description: IntentDescription? = IntentDescription("이 집중 모드에서 우다다가 덜 말 걸게 해.")

    @Parameter(title: "걱정 시간 알림 끄기", default: false)
    var muteWorry: Bool

    @Parameter(title: "묶음 알림만 받기", default: false)
    var digestOnly: Bool

    @Parameter(title: "오늘 화면에서 나중에 숨기기", default: false)
    var hideLater: Bool

    init() {}

    var state: FocusFilterState { FocusFilterState(muteWorry: muteWorry, digestOnly: digestOnly, hideLater: hideLater) }

    var displayRepresentation: DisplayRepresentation {
        var on: [String] = []
        if digestOnly { on.append("묶음 알림만") } else if muteWorry { on.append("걱정 알림 끔") }
        if hideLater { on.append("나중에 숨김") }
        return DisplayRepresentation(title: "우다다", subtitle: "\(on.isEmpty ? "바꾸는 것 없음" : on.joined(separator: " · "))")
    }

    /// 이미 걸린 알림도 시스템이 꼬리표(filterCriteria = 종류)로 거른다
    var appContext: FocusFilterAppContext {
        let allowed = PlannedNote.Kind.allCases.filter(state.allows).map(\.rawValue)
        guard allowed.count < PlannedNote.Kind.allCases.count else { return FocusFilterAppContext(notificationFilterPredicate: nil) }
        return FocusFilterAppContext(notificationFilterPredicate: NSPredicate(format: "SELF IN %@", allowed))
    }

    func perform() async throws -> some IntentResult {
        state.save()
        await MainActor.run {
            NotificationCenter.default.post(name: FocusFilterState.didChange, object: nil)
        }
        let (data, now) = await MainActor.run { (IntentData.read(), IntentData.now) }
        await Notifier.rescheduleNow(data, now: now)
        return .result()
    }
}
