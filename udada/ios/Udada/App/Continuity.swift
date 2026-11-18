import Foundation

/// 보고 있는 날을 다른 기기가 이어 연다 (Handoff). iPhone 에서 보던 날이 Mac 독에 뜨고, 그 반대도.
enum Continuity {
    /// Info.plist 의 NSUserActivityTypes 에 있는 이름
    static let dayActivity = "io.github.bunhine0452.udada.today"

    static func fill(_ a: NSUserActivity, day: DayKey, today: DayKey) {
        a.title = day == today ? "우다다 · 오늘" : "우다다 · \(day.m)월 \(day.d)일"
        a.userInfo = ["day": day.description]
        a.requiredUserInfoKeys = ["day"]
        a.isEligibleForHandoff = true
        a.needsSave = true
    }

    static func day(from a: NSUserActivity) -> DayKey? {
        (a.userInfo?["day"] as? String).flatMap(DayKey.init(string:))
    }
}
