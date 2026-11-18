import Foundation

/// '잠깐' 화면에서 "그냥 갈래"를 고르면 잠시(기본 15분) 문을 열어 둔다.
/// 자동화가 숏폼 앱을 열 때마다 다시 불러도 그동안은 끼어들지 않는다 (끝없는 되돌이 막기).
enum GatePass {
    static let key = "gatePassUntil"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: DataFile.group) }

    /// 지금 지나가도 되나 (열어 둔 시간 안인가)
    static func isOpen(now: Date = Date()) -> Bool {
        now.timeIntervalSince1970 < (defaults?.double(forKey: key) ?? 0)
    }

    /// 지금부터 minutes 분 동안 열어 둔다
    static func grant(minutes: Int = 15, now: Date = Date()) {
        defaults?.set(now.addingTimeInterval(TimeInterval(minutes * 60)).timeIntervalSince1970, forKey: key)
    }
}
