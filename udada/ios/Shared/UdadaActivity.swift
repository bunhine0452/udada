import ActivityKit
import Foundation

/// 잠금 화면·다이내믹 아일랜드의 시계 하나: 식히기(거꾸로 셈) 또는 집중(앞으로 셈).
struct UdadaActivity: ActivityAttributes {
    enum Mode: String, Codable, Hashable { case rest, focus }

    struct ContentState: Codable, Hashable {
        var mode: Mode
        /// 식히기 종류 (rest 일 때)
        var rest: RestKind?
        /// 집중하는 일 (focus 일 때. 사용자 글)
        var title: String
        /// 시작 시각
        var start: Date
        /// rest: 끝나는 시각 · focus: 시작 + 예정 분
        var end: Date
        /// 예정 분
        var planned: Int

        static func rest(_ kind: RestKind, start: Date = Date(), until end: Date) -> ContentState {
            ContentState(mode: .rest, rest: kind, title: kind.name, start: start, end: max(end, start),
                         planned: max(1, Int((end.timeIntervalSince(start) / 60).rounded())))
        }

        static func focus(title: String, started: Date, planned: Int) -> ContentState {
            ContentState(mode: .focus, rest: nil, title: title, start: started,
                         end: started.addingTimeInterval(TimeInterval(max(1, planned) * 60)), planned: max(1, planned))
        }
    }
}
