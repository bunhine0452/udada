import XCTest

/// 기기 두 대와 iCloud 를 흉내 내어 맞추기 규칙(Shared/Sync.swift)을 본다.
/// CloudSync 가 하는 순서 그대로: 보낼 것 찾기 → (충돌이면 나중에 고친 쪽) → 받아서 다시 짓기.
final class SyncTests: XCTestCase {
    /// iCloud: 열쇠 → (글, 고친 때)
    final class Cloud {
        var records: [String: (body: Data, stamp: Date)] = [:]
        /// 기기마다 어디까지 받았나 (바뀐 순서 번호)
        var log: [(key: String, deleted: Bool)] = []
    }

    final class Device {
        var data = AppData()
        var state = SyncState()
        var pendingSaves: Set<String> = []
        var pendingDeletes: Set<String> = []
        var cursor = 0
        let cloud: Cloud
        init(_ cloud: Cloud) { self.cloud = cloud }

        /// 사용자가 앱 안에서 바꿈
        func change(at now: Date, _ body: (inout AppData) -> Void) {
            body(&data)
            note(SyncMerge.outgoing(data, state: &state, now: now, allowDeletes: true, firstTime: false))
        }

        /// 앱 밖(위젯)에서 바뀌었거나 파일이 깨졌다 — 지우기로 치지 않는다
        func reconcile(at now: Date, firstTime: Bool = false) {
            note(SyncMerge.outgoing(data, state: &state, now: now, allowDeletes: false, firstTime: firstTime))
        }

        private func note(_ out: SyncOutbox) {
            pendingSaves.formUnion(out.saves); pendingSaves.subtract(out.deletes)
            pendingDeletes.formUnion(out.deletes); pendingDeletes.subtract(out.saves)
        }

        func push() {
            for key in pendingSaves.sorted() {
                guard let body = state.shadow[key] else { continue }
                let mine = state.stamps[key] ?? .distantPast
                if let server = cloud.records[key], server.stamp >= mine, server.body != body {
                    // 서버 것이 더 나중 → 받아들인다 (serverRecordChanged)
                    _ = SyncMerge.incoming([SyncIncoming(key: key, body: server.body, stamp: server.stamp)], state: &state, pending: [])
                    continue
                }
                cloud.records[key] = (body, mine)
                cloud.log.append((key, false))
            }
            for key in pendingDeletes.sorted() where cloud.records[key] != nil {
                cloud.records[key] = nil
                cloud.log.append((key, true))
            }
            pendingSaves = []; pendingDeletes = []
            data = SyncMerge.rebuilt(data, state: state)
        }

        func pull(at now: Date = Date()) {
            reconcile(at: now)
            let fresh = cloud.log[cursor...]
            cursor = cloud.log.count
            var changes: [SyncIncoming] = []
            for key in Set(fresh.map(\.key)).sorted() {
                if let r = cloud.records[key] { changes.append(SyncIncoming(key: key, body: r.body, stamp: r.stamp)) }
                else { changes.append(SyncIncoming(key: key, body: nil)) }
            }
            let r = SyncMerge.incoming(changes, state: &state, pending: pendingSaves)
            pendingSaves.subtract(r.accepted); pendingDeletes.subtract(r.accepted)
            pendingDeletes.formUnion(r.dropDuplicates)
            data = SyncMerge.rebuilt(data, state: state)
        }

        func sync(at now: Date = Date()) { pull(at: now); push(); pull(at: now) }
    }

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func t(_ s: Double) -> Date { t0.addingTimeInterval(s) }
    private let day = DayKey(y: 2026, m: 11, d: 15)

    private func pair() -> (Cloud, Device, Device) {
        let c = Cloud()
        let a = Device(c), b = Device(c)
        a.reconcile(at: t(0), firstTime: true); a.sync()
        b.reconcile(at: t(0), firstTime: true); b.sync()
        return (c, a, b)
    }

    func testAddOnMacShowsOnPhone() {
        let (_, mac, phone) = pair()
        mac.change(at: t(1)) { $0.add(Item(title: "치과", day: self.day, time: 900)) }
        mac.push(); phone.pull()
        XCTAssertEqual(phone.data.items.map(\.title), ["치과"])
        XCTAssertEqual(phone.data.items.first?.time, 900)
    }

    func testDoneOnPhoneComesBack() {
        let (_, mac, phone) = pair()
        let it = Item(title: "메일 답장", day: day)
        mac.change(at: t(1)) { $0.add(it) }
        mac.push(); phone.pull()
        phone.change(at: t(2)) { $0.setDone(.item(it.id), true, now: self.t(2)) }
        phone.push(); mac.pull()
        XCTAssertEqual(mac.data.item(it.id)?.done, true)
    }

    func testOfflineEditsOnBothSurvive() {
        let (_, mac, phone) = pair()
        mac.change(at: t(1)) { $0.add(Item(title: "보고서", day: self.day)) }
        phone.change(at: t(2)) { $0.add(Item(title: "장보기", day: self.day)) }
        mac.sync(); phone.sync(); mac.sync()
        XCTAssertEqual(Set(mac.data.items.map(\.title)), ["보고서", "장보기"])
        XCTAssertEqual(Set(phone.data.items.map(\.title)), ["보고서", "장보기"])
    }

    func testSameItemLaterEditWins() {
        let (_, mac, phone) = pair()
        let it = Item(title: "기획서", day: day)
        mac.change(at: t(1)) { $0.add(it) }
        mac.push(); phone.pull()
        mac.change(at: t(10)) { $0.update(it.id) { $0.title = "기획서 초안" } }
        phone.change(at: t(20)) { $0.update(it.id) { $0.title = "기획서 최종" } }
        phone.push(); mac.sync(); phone.sync()
        XCTAssertEqual(mac.data.item(it.id)?.title, "기획서 최종")
        XCTAssertEqual(phone.data.item(it.id)?.title, "기획서 최종")
    }

    func testDeleteSpreads() {
        let (cloud, mac, phone) = pair()
        let it = Item(title: "지울 것", day: day)
        mac.change(at: t(1)) { $0.add(it) }
        mac.push(); phone.pull()
        phone.change(at: t(2)) { $0.remove(.item(it.id)) }
        phone.push(); mac.pull()
        XCTAssertTrue(mac.data.items.isEmpty)
        XCTAssertNil(cloud.records["item." + it.id.uuidString])
    }

    /// 파일이 깨져 빈 데이터로 떴을 때: iCloud 를 비우지 않고 되살린다
    func testBrokenFileDoesNotWipeCloud() {
        let (cloud, mac, phone) = pair()
        mac.change(at: t(1)) { d in for n in ["가", "나", "다"] { d.add(Item(title: n, day: self.day)) } }
        mac.push(); phone.pull()
        phone.data = AppData() // 못 읽어서 빈 데이터
        phone.sync(at: t(5))
        XCTAssertEqual(cloud.records.keys.filter { $0.hasPrefix("item.") }.count, 3)
        XCTAssertEqual(phone.data.items.count, 3)
        mac.pull()
        XCTAssertEqual(mac.data.items.count, 3)
    }

    /// 새 기기가 처음 맞출 때: 기본 설정이 쓰던 설정을 덮지 않고, 새 기기에 있던 일은 합쳐진다
    func testFirstSyncKeepsExistingSettingsAndMerges() {
        let cloud = Cloud()
        let phone = Device(cloud)
        phone.data.settings.defaultDuration = 45
        phone.data.settings.parts.morningStart = 300
        phone.data.items = [Item(title: "폰에 있던 일", day: day)]
        phone.reconcile(at: t(0), firstTime: true); phone.sync()

        let mac = Device(cloud)
        mac.data.items = [Item(title: "맥에 있던 일", day: day)]
        mac.reconcile(at: t(100), firstTime: true); mac.sync(); phone.sync()

        XCTAssertEqual(mac.data.settings.defaultDuration, 45)
        XCTAssertEqual(mac.data.settings.parts.morningStart, 300)
        XCTAssertEqual(phone.data.settings.defaultDuration, 45)
        XCTAssertEqual(Set(mac.data.items.map(\.title)), ["폰에 있던 일", "맥에 있던 일"])
        XCTAssertEqual(Set(phone.data.items.map(\.title)), ["폰에 있던 일", "맥에 있던 일"])
    }

    func testSharedSettingsTravelDeviceOnesStay() {
        let (_, mac, phone) = pair()
        mac.change(at: t(1)) { d in
            d.settings.worryTime = 1200
            d.settings.appearance = .dark
            d.settings.aiOn = false
            d.seenIntro = true
        }
        mac.push(); phone.pull()
        XCTAssertEqual(phone.data.settings.worryTime, 1200)
        XCTAssertEqual(phone.data.settings.appearance, .system)
        XCTAssertTrue(phone.data.settings.aiOn)
        XCTAssertFalse(phone.data.seenIntro)
    }

    /// Mac 에서 시작한 집중이 iPhone 에 이어지고, iPhone 에서 끝내면 Mac 도 끝난다
    func testFocusContinuesAcrossDevices() {
        let (_, mac, phone) = pair()
        let it = Item(title: "보고서 초안", day: day)
        mac.change(at: t(1)) { $0.add(it) }
        mac.change(at: t(2)) { $0.activeFocus = ActiveFocus(itemID: it.id, title: it.title, planned: 30, started: self.t(2)) }
        mac.push(); phone.pull()
        XCTAssertEqual(phone.data.activeFocus?.title, "보고서 초안")
        XCTAssertEqual(phone.data.activeFocus?.started, t(2))

        phone.change(at: t(1500)) { d in
            d.activeFocus = nil
            d.focus.append(FocusLog(at: self.t(2), title: it.title, planned: 30, spent: 25, finished: true))
            d.setDone(.item(it.id), true, now: self.t(1500))
        }
        phone.push(); mac.pull()
        XCTAssertNil(mac.data.activeFocus)
        XCTAssertEqual(mac.data.focus.map(\.spent), [25])
        XCTAssertEqual(mac.data.item(it.id)?.done, true)
    }

    func testLogsFromBothDevicesUnion() {
        let (_, mac, phone) = pair()
        mac.change(at: t(1)) { $0.rests.append(RestLog(at: self.t(1), kind: .breath, seconds: 60)) }
        phone.change(at: t(2)) { $0.rests.append(RestLog(at: self.t(2), kind: .walk, seconds: 600)) }
        mac.sync(); phone.sync(); mac.sync()
        XCTAssertEqual(mac.data.rests.map(\.kind), [.breath, .walk])
        XCTAssertEqual(phone.data.rests.map(\.kind), [.breath, .walk])
    }

    /// 두 기기가 같은 반복의 같은 날을 따로 끝내면 둘이 생긴다 → 하나만 남는다
    func testDuplicateOccurrenceCollapses() {
        let (_, mac, phone) = pair()
        let series = Item(title: "물 한 잔", day: day, repeatRule: .daily)
        mac.change(at: t(1)) { $0.add(series) }
        mac.push(); phone.pull()
        mac.change(at: t(2)) { $0.setDone(.occurrence(series: series.id, day: self.day), true, now: self.t(2)) }
        phone.change(at: t(3)) { $0.setDone(.occurrence(series: series.id, day: self.day), true, now: self.t(3)) }
        mac.sync(); phone.sync(); mac.sync(); phone.sync()
        let kids = { (d: AppData) in d.items.filter { $0.seriesID == series.id } }
        XCTAssertEqual(kids(mac.data).count, 1)
        XCTAssertEqual(kids(phone.data).map(\.id), kids(mac.data).map(\.id))
    }

    /// 새 버전이 쓴 모르는 필드가 있어도 '바뀌었다'고 보고 덮어쓰지 않는다
    func testUnknownFieldsAreNotClobbered() throws {
        let (cloud, mac, phone) = pair()
        let it = Item(title: "새 버전이 쓴 일", day: day)
        mac.change(at: t(1)) { $0.add(it) }
        mac.push()
        let key = "item." + it.id.uuidString
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: cloud.records[key]!.body) as? [String: Any])
        obj["futureField"] = "나중 버전"
        let future = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
        cloud.records[key] = (future, t(2))
        cloud.log.append((key, false))
        phone.pull()
        phone.reconcile(at: t(3))
        XCTAssertTrue(phone.pendingSaves.isEmpty)
        phone.push()
        XCTAssertEqual(cloud.records[key]?.body, future)
    }

    func testFlattenBuildRoundTrip() {
        var d = AppData()
        // 만든 때가 같으면 순서를 id 로 가르니, 순서를 견주려면 때를 다르게 준다
        d.items = [Item(title: "가", day: day, time: 600, created: t(1)), Item(title: "걱정", created: t(2), worry: true)]
        d.rests = [RestLog(at: t(1), kind: .far, seconds: 180, before: 3, after: 7)]
        d.closes = [CloseLog(day: day, at: t(2), done: 3, tomorrow: 1, later: 0, dropped: 1)]
        d.activeFocus = ActiveFocus(itemID: nil, title: "집중", planned: 25, started: t(3))
        let back = SyncCodec.build(SyncCodec.flatten(d), keeping: AppData())
        XCTAssertEqual(back.items, d.items)
        XCTAssertEqual(back.rests, d.rests)
        XCTAssertEqual(back.closes, d.closes)
        XCTAssertEqual(back.activeFocus, d.activeFocus)
    }
}
