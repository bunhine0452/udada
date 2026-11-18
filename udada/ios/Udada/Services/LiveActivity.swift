import ActivityKit
import Foundation

/// 잠금 화면·다이내믹 아일랜드의 식히기·집중 시계. 하나만 띄운다 — 새로 띄우기 전에 있던 것을 모두 닫는다.
/// 실시간 현황이 꺼져 있거나 요청이 막히면 조용히 넘어간다.
@MainActor
enum LiveActivity {
    static func startRest(_ kind: RestKind, until end: Date) {
        let now = Date()
        start(.rest(kind, start: now, until: end), stale: end)
    }

    static func startFocus(title: String, started: Date, planned: Int) {
        let state = UdadaActivity.ContentState.focus(title: title, started: started, planned: planned)
        start(state, stale: nil)
    }

    static func end() {
        enqueue { await endAll() }
    }

    // MARK: -

    /// 앞 요청이 끝난 뒤에 돈다 — 빠르게 두 번 불려도 시계가 둘 뜨지 않게.
    private static var last: Task<Void, Never>?

    private static func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = last
        last = Task { @MainActor in
            await previous?.value
            await work()
        }
    }

    private static func start(_ state: UdadaActivity.ContentState, stale: Date?) {
        enqueue {
            await endAll()
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            _ = try? Activity<UdadaActivity>.request(
                attributes: UdadaActivity(),
                content: ActivityContent(state: state, staleDate: stale),
                pushType: nil
            )
        }
    }

    private static func endAll() async {
        for activity in Activity<UdadaActivity>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
