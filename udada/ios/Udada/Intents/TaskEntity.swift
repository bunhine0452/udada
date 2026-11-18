import AppIntents
import CoreSpotlight
import CoreTransferable
import Foundation

/// Siri·단축어·Spotlight 가 찾는 할 일 하나. 반복 아닌 열린 항목 (오늘~14일 뒤 + 나중에).
struct TaskEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "할 일", numericFormat: "할 일 \(placeholder: .int)개")
    static let defaultQuery = TaskQuery()

    /// Item.id (UUID 문자열)
    var id: String
    var title: String
    /// 오늘 · 내일 · 11월 20일 (금) · 나중에
    var dayLabel: String
    /// 낮 · 15:00 (나중에면 "")
    var slot: String
    /// udada://day/2026-11-15 · udada://today
    var url: String

    var subtitle: String { slot.isEmpty ? dayLabel : "\(dayLabel) \(slot)" }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)", image: .init(systemName: slot.contains(":") ? "clock" : "square"))
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let a = defaultAttributeSet
        a.title = title
        a.displayName = title
        a.contentDescription = "\(subtitle) · 우다다"
        a.keywords = ["할 일", "우다다", dayLabel] + (slot.isEmpty ? [] : [slot])
        return a
    }
}

extension TaskEntity {
    init(_ it: Item, today: DayKey) {
        id = it.id.uuidString
        title = it.title
        dayLabel = Fmt.day(it.day, today: today)
        slot = it.day == nil ? "" : (it.time.map(Fmt.hm) ?? it.part.name)
        url = it.day.map { "udada://day/\($0)" } ?? "udada://today"
    }

    static let horizon = 14

    /// 찾을 수 있는 열린 할 일: 반복 원본·걱정·끝낸 것 빼고, 오늘~14일 뒤 + 나중에. 가까운 날 → 시각/띠 순, 나중에는 맨 뒤.
    static func all(in data: AppData, now: Date, calendar: Calendar = .current) -> [TaskEntity] {
        let today = DayKey(now, calendar: calendar)
        let last = today.adding(days: horizon, calendar: calendar)
        let open = data.items.filter { it in
            guard !it.done, !it.worry, it.repeatRule == nil else { return false }
            guard let d = it.day else { return true }
            return d >= today && d <= last
        }
        let sorted = open.sorted { a, b in
            switch (a.day, b.day) {
            case (nil, nil): return a.created < b.created
            case (nil, _): return false
            case (_, nil): return true
            case let (x?, y?):
                if x != y { return x < y }
                let ka = a.time ?? data.settings.parts.range(a.part).lowerBound
                let kb = b.time ?? data.settings.parts.range(b.part).lowerBound
                return ka != kb ? ka < kb : a.created < b.created
            }
        }
        return sorted.map { TaskEntity($0, today: today) }
    }

    /// 띄어쓰기·대소문자 무시하고 제목에 들어 있나
    static func matches(_ e: TaskEntity, _ query: String) -> Bool {
        func norm(_ s: String) -> String { s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current).filter { !$0.isWhitespace } }
        let q = norm(query)
        return q.isEmpty || norm(e.title).contains(q)
    }
}

struct TaskQuery: EntityStringQuery {
    func entities(for identifiers: [TaskEntity.ID]) async throws -> [TaskEntity] {
        await MainActor.run {
            let data = IntentData.read()
            let today = IntentData.today
            let want = Set(identifiers)
            // 이미 끝낸 것도 id 로는 찾는다 (끝내기를 두 번 눌러도 이름이 보이게)
            return data.items.filter { want.contains($0.id.uuidString) }.map { TaskEntity($0, today: today) }
        }
    }

    func entities(matching string: String) async throws -> [TaskEntity] {
        await MainActor.run { TaskEntity.all(in: IntentData.read(), now: IntentData.now).filter { TaskEntity.matches($0, string) } }
    }

    func suggestedEntities() async throws -> [TaskEntity] {
        await MainActor.run { Array(TaskEntity.all(in: IntentData.read(), now: IntentData.now).prefix(30)) }
    }
}

/// Spotlight 를 눌렀을 때 그 날로 연다
struct OpenTaskIntent: OpenIntent {
    static let title: LocalizedStringResource = "할 일 열기"
    static let openAppWhenRun = true
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "할 일")
    var target: TaskEntity

    init() {}
    init(target: TaskEntity) { self.target = target }

    @MainActor
    func perform() async throws -> some IntentResult {
        await IntentData.open(target.url)
        return .result()
    }
}

/// Spotlight 색인. 데이터가 바뀐 뒤 불러 주면 1.5초 몰아서 다시 색인한다.
@MainActor
enum SpotlightIndex {
    private static var task: Task<Void, Never>?

    static func refresh(_ data: AppData) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            let entities = TaskEntity.all(in: data, now: IntentData.now)
            let index = CSSearchableIndex.default()
            try? await index.deleteAppEntities(ofType: TaskEntity.self)
            if !entities.isEmpty { try? await index.indexAppEntities(entities) }
            UdadaShortcuts.updateAppShortcutParameters()
        }
    }

    /// Spotlight 결과로 앱이 열렸을 때 (`onContinueUserActivity(CSSearchableItemActionType)`) 갈 주소
    static func url(for activity: NSUserActivity) -> URL? {
        guard let ident = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return nil }
        let uuid = ident.split(whereSeparator: { !$0.isHexDigit && $0 != "-" }).lazy.compactMap { UUID(uuidString: String($0)) }.first
        guard let uuid, let it = IntentData.read().item(uuid) else { return URL(string: "udada://today") }
        return URL(string: it.day.map { "udada://day/\($0)" } ?? "udada://today")
    }
}

/// Siri·Apple Intelligence 가 '화면의 이 할 일'을 글로 받아 갈 수 있게 (다른 앱으로 넘기거나 물을 때)
extension TaskEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: { "\($0.title) — \($0.subtitle)" })
    }
}

enum OnScreen {
    /// Info.plist 의 NSUserActivityTypes 에 있는 이름
    static let taskActivity = "io.github.bunhine0452.udada.task"

    /// 지금 화면에 떠 있는 할 일을 시스템에 알린다 → "이거 내일로 미뤄"처럼 가리켜 말할 수 있다
    static func annotate(_ a: NSUserActivity, itemID: UUID, title: String) {
        a.title = title
        if #available(iOS 18.2, macOS 15.2, *) {
            a.appEntityIdentifier = EntityIdentifier(for: TaskEntity.self, identifier: itemID.uuidString)
        }
        a.isEligibleForHandoff = false
    }
}
