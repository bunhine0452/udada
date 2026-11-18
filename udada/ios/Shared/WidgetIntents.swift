import AppIntents
import Foundation
import WidgetKit

// 위젯·제어 센터가 쓰는 동작. 앱과 위젯 확장에 같이 컴파일된다 (위젯 버튼은 확장에서, 앱 열기는 앱에서 돈다).

/// 위젯의 네모 칸: 할 일 하나를 끝내거나 되돌린다. 저장 파일을 직접 고치고, 앱은 다시 활성화될 때 파일을 다시 읽는다.
struct ToggleEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "할 일 끝내기"
    static var description = IntentDescription("위젯에서 할 일을 끝내거나 되돌려.")
    static var isDiscoverable = false

    /// Entry.id — "i:<uuid>" 또는 "o:<seriesUUID>:<yyyy-MM-dd>"
    @Parameter(title: "항목")
    var entryID: String

    init() {}
    init(entryID: String) { self.entryID = entryID }

    func perform() async throws -> some IntentResult {
        guard let source = Self.source(from: entryID) else { return .result() }
        var data = DataFile.load()
        let before = data.items
        data.toggleDone(source, now: Date())
        // 바뀐 게 없으면(항목이 없거나 파일을 못 읽었으면) 쓰지 않는다 — 빈 데이터로 덮어쓰지 않게.
        guard data.items != before else { return .result() }
        DataFile.save(data)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    /// Entry.id → Entry.Source. "e:" (기기 달력)는 .external, 모르는 모양이면 nil.
    static func source(from id: String) -> Entry.Source? {
        let p = id.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard p.count >= 2 else { return nil }
        switch p[0] {
        case "i":
            guard p.count == 2, let u = UUID(uuidString: p[1]) else { return nil }
            return .item(u)
        case "o":
            guard p.count == 3, let u = UUID(uuidString: p[1]), let d = DayKey(string: p[2]) else { return nil }
            return .occurrence(series: u, day: d)
        case "e":
            let rest = String(id.dropFirst(2))
            return rest.isEmpty ? nil : .external(id: rest)
        default:
            return nil
        }
    }
}

/// 제어 센터 버튼: 앱을 udada://<path> 로 연다.
/// 앱을 앞으로 띄운 뒤 OpenURLIntent 로 딥링크를 넘긴다 (iOS 18 제어에서 앱을 특정 화면으로 여는 방법).
struct UdadaControlOpenIntent: AppIntent {
    static var title: LocalizedStringResource = "우다다 열기"
    static var openAppWhenRun = true
    static var isDiscoverable = false

    /// "add" · "dump" · "rest/breath" 처럼 scheme 뒤의 부분
    @Parameter(title: "주소")
    var path: String

    init() {}
    init(path: String) { self.path = path }

    var url: URL { URL(string: "udada://" + path) ?? URL(string: "udada://today")! }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(url))
    }
}
