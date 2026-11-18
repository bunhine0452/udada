import Foundation

// 기기 사이 맞추기의 규칙 (Foundation 만 — 테스트·Mac·iPhone 이 같이 쓴다).
//
// 저장 파일 하나(AppData)를 '열쇠 → JSON' 낱장으로 편다. 낱장 하나가 iCloud 레코드 하나다.
//   item.<uuid>     할 일 · 약속 · 걱정 하나
//   rest.<ms> · dump.<ms> · focus.<ms> · close.<yyyy-MM-dd>   기록 (덧붙기만 한다)
//   settings        기기끼리 같아야 하는 설정 (띠 시각 · 알림 시각 · 기본 길이)
//   nowfocus        지금 돌고 있는 집중 — Mac 에서 시작하면 iPhone 에서 이어진다
// 기기마다 다른 것(화면 밝기 · 진동 · 기기 달력 · AI 스위치 · 소개 봤는지)은 펴지 않는다.
//
// 합치는 규칙: 낱장마다 '마지막에 고친 쪽이 이긴다'. 지우기는 사용자가 앱 안에서 지웠을 때만 퍼진다 —
// 파일이 깨졌거나 비어서 없어 보이는 것은 지우기로 치지 않고 되살린다.

/// 기기끼리 같이 쓰는 설정
struct SharedSettings: Codable, Equatable, Sendable {
    var parts = DayParts()
    var mondayFirst = true
    var digestOn = true
    var digestTimes = [510, 750, 1110]
    var eventAlertOn = true
    var eventLead = 10
    var worryOn = true
    var worryTime = 1290
    var closeReminderOn = false
    var closeTime = 1260
    var defaultDuration = 30

    init(_ s: Settings) {
        parts = s.parts; mondayFirst = s.mondayFirst; digestOn = s.digestOn; digestTimes = s.digestTimes
        eventAlertOn = s.eventAlertOn; eventLead = s.eventLead; worryOn = s.worryOn; worryTime = s.worryTime
        closeReminderOn = s.closeReminderOn; closeTime = s.closeTime; defaultDuration = s.defaultDuration
    }

    func apply(to s: inout Settings) {
        s.parts = parts; s.mondayFirst = mondayFirst; s.digestOn = digestOn; s.digestTimes = digestTimes
        s.eventAlertOn = eventAlertOn; s.eventLead = eventLead; s.worryOn = worryOn; s.worryTime = worryTime
        s.closeReminderOn = closeReminderOn; s.closeTime = closeTime; s.defaultDuration = defaultDuration
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SharedSettings(Settings())
        parts = try c.decodeIfPresent(DayParts.self, forKey: .parts) ?? d.parts
        mondayFirst = try c.decodeIfPresent(Bool.self, forKey: .mondayFirst) ?? d.mondayFirst
        digestOn = try c.decodeIfPresent(Bool.self, forKey: .digestOn) ?? d.digestOn
        digestTimes = try c.decodeIfPresent([Int].self, forKey: .digestTimes) ?? d.digestTimes
        eventAlertOn = try c.decodeIfPresent(Bool.self, forKey: .eventAlertOn) ?? d.eventAlertOn
        eventLead = try c.decodeIfPresent(Int.self, forKey: .eventLead) ?? d.eventLead
        worryOn = try c.decodeIfPresent(Bool.self, forKey: .worryOn) ?? d.worryOn
        worryTime = try c.decodeIfPresent(Int.self, forKey: .worryTime) ?? d.worryTime
        closeReminderOn = try c.decodeIfPresent(Bool.self, forKey: .closeReminderOn) ?? d.closeReminderOn
        closeTime = try c.decodeIfPresent(Int.self, forKey: .closeTime) ?? d.closeTime
        defaultDuration = try c.decodeIfPresent(Int.self, forKey: .defaultDuration) ?? d.defaultDuration
    }
    private enum CodingKeys: String, CodingKey {
        case parts, mondayFirst, digestOn, digestTimes, eventAlertOn, eventLead, worryOn, worryTime, closeReminderOn, closeTime, defaultDuration
    }
}

/// AppData ↔ 낱장
enum SyncCodec {
    static let settingsKey = "settings"
    static let focusKey = "nowfocus"
    /// 기기마다 하나뿐인 낱장. 처음 맞출 때는 iCloud 에 이미 있는 쪽이 이긴다 (새 기기의 기본값이 덮지 않게).
    static let singletons: Set<String> = [settingsKey, focusKey]

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private static let decoder = JSONDecoder()

    private static func ms(_ d: Date) -> String { String(Int64((d.timeIntervalSince1970 * 1000).rounded())) }
    private static func enc<T: Encodable>(_ v: T) -> Data { (try? encoder.encode(v)) ?? Data() }
    private static func dec<T: Decodable>(_ t: T.Type, _ d: Data) -> T? { try? decoder.decode(t, from: d) }

    static func key(_ item: Item) -> String { "item." + item.id.uuidString }

    static func flatten(_ d: AppData) -> [String: Data] {
        var out: [String: Data] = [:]
        for it in d.items { out[key(it)] = enc(it) }
        for r in d.rests { out["rest." + ms(r.at)] = enc(r) }
        for r in d.dumps { out["dump." + ms(r.at)] = enc(r) }
        for r in d.focus { out["focus." + ms(r.at)] = enc(r) }
        for r in d.closes { out["close." + r.day.description] = enc(r) }
        out[settingsKey] = enc(SharedSettings(d.settings))
        if let f = d.activeFocus { out[focusKey] = enc(f) }
        return out
    }

    /// 다른 버전의 앱이 쓴 낱장도 지금 모델로 읽었다 다시 써서 견준다 — 모르는 필드 때문에 '바뀌었다'고 보지 않게.
    static func normalize(_ key: String, _ data: Data) -> Data? {
        switch key.split(separator: ".").first.map(String.init) ?? key {
        case "item": return dec(Item.self, data).map(enc)
        case "rest": return dec(RestLog.self, data).map(enc)
        case "dump": return dec(DumpLog.self, data).map(enc)
        case "focus": return dec(FocusLog.self, data).map(enc)
        case "close": return dec(CloseLog.self, data).map(enc)
        case settingsKey: return dec(SharedSettings.self, data).map(enc)
        case focusKey: return dec(ActiveFocus.self, data).map(enc)
        default: return nil
        }
    }

    /// 낱장들로 AppData 를 다시 짓는다. 기기마다 다른 값은 local 것을 그대로 둔다.
    static func build(_ records: [String: Data], keeping local: AppData) -> AppData {
        var out = local
        var items: [UUID: Item] = [:]
        var rests: [RestLog] = [], dumps: [DumpLog] = [], focus: [FocusLog] = [], closes: [CloseLog] = []
        var active: ActiveFocus?
        for (key, data) in records {
            switch key.split(separator: ".").first.map(String.init) ?? key {
            case "item": if let v = dec(Item.self, data) { items[v.id] = v }
            case "rest": if let v = dec(RestLog.self, data) { rests.append(v) }
            case "dump": if let v = dec(DumpLog.self, data) { dumps.append(v) }
            case "focus": if let v = dec(FocusLog.self, data) { focus.append(v) }
            case "close": if let v = dec(CloseLog.self, data) { closes.append(v) }
            case settingsKey: dec(SharedSettings.self, data)?.apply(to: &out.settings)
            case focusKey: active = dec(ActiveFocus.self, data)
            default: break
            }
        }
        // 있던 것은 있던 순서 그대로, 새로 온 것은 만든 순서로 뒤에
        var ordered: [Item] = local.items.compactMap { items.removeValue(forKey: $0.id) }
        ordered += items.values.sorted { ($0.created, $0.id.uuidString) < ($1.created, $1.id.uuidString) }
        out.items = ordered
        out.rests = rests.sorted { $0.at < $1.at }
        out.dumps = dumps.sorted { $0.at < $1.at }
        out.focus = focus.sorted { $0.at < $1.at }
        out.closes = closes.sorted { ($0.day, $0.at) < ($1.day, $1.at) }
        out.activeFocus = active
        return out
    }

    /// 두 기기가 같은 반복의 같은 날을 따로 떼어 냈으면 둘이 생긴다 → id 가 큰 쪽 열쇠를 돌려준다 (지울 것).
    static func duplicateChildren(in records: [String: Data]) -> [String] {
        var seen: [String: String] = [:] // series+day → 남길 열쇠
        var drop: [String] = []
        for key in records.keys.sorted() where key.hasPrefix("item.") {
            guard let data = records[key], let it = dec(Item.self, data), let s = it.seriesID, let o = it.occurrence else { continue }
            let slot = s.uuidString + "@" + o.description
            if seen[slot] != nil { drop.append(key) } else { seen[slot] = key }
        }
        return drop
    }
}

/// 이 기기가 마지막으로 알고 있는 '맞춰진 모습'. 파일 하나로 저장한다.
struct SyncState: Codable, Sendable {
    /// 열쇠 → 낱장 (지금 이 기기에 있는 것. 보낼 것이 남았으면 아직 iCloud 와 다를 수 있다)
    var shadow: [String: Data] = [:]
    /// 열쇠 → 마지막으로 고친 때 (고친 기기의 시계)
    var stamps: [String: Date] = [:]
    /// 처음 맞추기를 끝냈나
    var bootstrapped = false

    init() {}
}

/// 한 번 견준 결과: iCloud 로 보낼 것
struct SyncOutbox: Equatable, Sendable {
    var saves: [String] = []
    var deletes: [String] = []
    var isEmpty: Bool { saves.isEmpty && deletes.isEmpty }
}

/// iCloud 에서 온 낱장 하나 (body == nil 이면 지워짐)
struct SyncIncoming: Sendable {
    var key: String
    var body: Data?
    var stamp: Date

    init(key: String, body: Data?, stamp: Date = .distantPast) { self.key = key; self.body = body; self.stamp = stamp }
}

enum SyncMerge {
    /// 이 기기의 지금 데이터를 state 와 견줘 보낼 것을 찾고 state 를 따라오게 한다.
    /// - allowDeletes: 앱 안에서 사용자가 바꾼 직후에만 true. false 면 없어진 것은 지우기로 치지 않는다 (reconcile 이 되살린다).
    /// - firstTime: 처음 맞출 때. 하나뿐인 낱장(설정·집중)은 아주 옛날 것으로 표시해 iCloud 쪽이 이기게 한다.
    static func outgoing(_ data: AppData, state: inout SyncState, now: Date, allowDeletes: Bool, firstTime: Bool = false) -> SyncOutbox {
        let cur = SyncCodec.flatten(data)
        var out = SyncOutbox()
        for (key, body) in cur {
            if let old = state.shadow[key], old == body || SyncCodec.normalize(key, old) == body { continue }
            // 처음 맞출 때 '집중 없음'·기본 설정이 iCloud 것을 덮지 않게: 하나뿐인 낱장은 가장 옛날로
            state.shadow[key] = body
            state.stamps[key] = (firstTime && SyncCodec.singletons.contains(key)) ? .distantPast : now
            out.saves.append(key)
        }
        if allowDeletes {
            for key in state.shadow.keys where cur[key] == nil {
                state.shadow[key] = nil
                state.stamps[key] = nil
                out.deletes.append(key)
            }
        }
        out.saves.sort(); out.deletes.sort()
        return out
    }

    /// iCloud 에서 온 것을 state 에 넣는다. pending = 아직 못 보낸 이 기기의 변경 열쇠.
    /// 돌려주는 것: 받아들인 열쇠(보낼 목록에서 뺄 것)와, 겹쳐서 지워야 할 열쇠.
    static func incoming(_ changes: [SyncIncoming], state: inout SyncState, pending: Set<String>) -> (accepted: [String], dropDuplicates: [String]) {
        var accepted: [String] = []
        for c in changes {
            guard let body = c.body else {
                // 지우기는 이긴다 (다른 기기에서 사용자가 지웠다)
                state.shadow[c.key] = nil
                state.stamps[c.key] = nil
                accepted.append(c.key)
                continue
            }
            if pending.contains(c.key), let mine = state.stamps[c.key], mine > c.stamp { continue }
            state.shadow[c.key] = body
            state.stamps[c.key] = c.stamp
            accepted.append(c.key)
        }
        let dupes = SyncCodec.duplicateChildren(in: state.shadow)
        for k in dupes { state.shadow[k] = nil; state.stamps[k] = nil }
        return (accepted, dupes)
    }

    /// state 대로 이 기기의 데이터를 다시 짓는다
    static func rebuilt(_ local: AppData, state: SyncState) -> AppData { SyncCodec.build(state.shadow, keeping: local) }
}
