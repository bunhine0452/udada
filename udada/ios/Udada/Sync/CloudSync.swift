import CloudKit
import Foundation
import Observation
import os

/// iPhone ↔ Mac 맞추기. 사용자의 **개인 iCloud**(CloudKit private database)에만 올린다 — 개발자도 못 본다.
/// 무엇을 보내고 어떻게 합치는지는 Shared/Sync.swift(순수 규칙), 여기는 CKSyncEngine 에 싣고 내리기만 한다.
/// 낱장 하나 = 레코드 하나(Leaf): recordName = 열쇠, body = JSON 글, stamp = 고친 때.
@MainActor
@Observable
final class CloudSync {
    static let shared = CloudSync()
    static let containerID = "iCloud.io.github.bunhine0452.udada"
    static let zoneID = CKRecordZone.ID(zoneName: "Udada", ownerName: CKCurrentUserDefaultName)
    static let recordType = "Leaf"

    enum Phase: Equatable {
        case off
        /// iCloud 에 로그인돼 있지 않다
        case noAccount
        case syncing
        case ok(Date)
        case failed(String)
    }

    private(set) var phase: Phase = .off
    /// 다른 기기에서 마지막으로 뭔가 온 때 (화면에 '방금 맞췄어'를 띄울 때 쓴다)
    private(set) var lastRemote: Date?

    /// 지금 이 기기의 데이터를 읽는 길 · 합친 결과를 쓰는 길 (앱이 시작할 때 꽂는다)
    @ObservationIgnored var readLocal: @MainActor () -> AppData = { DataFile.load() }
    @ObservationIgnored var writeMerged: @MainActor (AppData) -> Void = { DataFile.save($0) }

    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var disk = Disk()
    @ObservationIgnored private var sendTask: Task<Void, Never>?
    /// 엔진이 받거나 보내는 중인 횟수. 그동안 fetchChanges/sendChanges 를 직접 부르면 CloudKit 이 앱을 멈춘다.
    @ObservationIgnored private var busy = 0
    @ObservationIgnored private lazy var relay = Relay(self)

    /// 파일 하나에 같이 둔다: 맞춰진 모습 · 레코드 꼬리표(서버 버전) · 엔진 상태
    private struct Disk: Codable {
        var state = SyncState()
        var meta: [String: Data] = [:]
        var engine: CKSyncEngine.State.Serialization?
    }

    #if os(macOS)
    /// 이 앱이 iCloud 컨테이너 권한을 갖고 서명됐나
    static let hasICloudEntitlement: Bool = {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-identifiers" as CFString, nil) != nil
    }()
    #endif

    static var fileURL: URL { DataFile.directory.appendingPathComponent("udada-sync.json") }

    /// 테스트·스크린샷 실행(-udReset · -udSeed · -udNoSync)은 절대 iCloud 를 건드리지 않는다.
    static var allowed: Bool {
        let a = ProcessInfo.processInfo.arguments
        #if os(macOS)
        // GitHub 의 nightly 빌드처럼 iCloud 권한 없이 서명된 앱은 이 Mac 에만 저장한다 (권한 없이 CloudKit 을 부르면 앱이 죽는다)
        guard hasICloudEntitlement else { return false }
        #endif
        if a.contains("-udSync") { return true }
        return !a.contains("-udReset") && !a.contains("-udSeed") && !a.contains("-udNoSync")
            && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    /// 앱이 뜰 때 한 번: Store 와 잇는다 (iPhone · Mac 공통)
    static func connect(_ store: Store) {
        let sync = CloudSync.shared
        sync.readLocal = { Store.live?.data ?? DataFile.load() }
        sync.writeMerged = { merged in
            guard let s = Store.live else { DataFile.save(merged); return }
            s.adopt(merged)
            // 받아들이며 자리를 다시 잡은 것(지난 띠 → 지금 띠)이 있으면 돌려보낸다
            CloudSync.shared.localChanged(s.data, allowDeletes: false)
        }
        Store.afterUserChange = { CloudSync.shared.localChanged($0, allowDeletes: true) }
        if store.settings.syncOn { sync.start() }
    }

    // MARK: 켜고 끄기

    func start() {
        guard engine == nil, Self.allowed else { return }
        if let raw = try? Data(contentsOf: Self.fileURL), let d = try? JSONDecoder().decode(Disk.self, from: raw) { disk = d }
        let db = CKContainer(identifier: Self.containerID).privateCloudDatabase
        let e = CKSyncEngine(CKSyncEngine.Configuration(database: db, stateSerialization: disk.engine, delegate: relay))
        engine = e
        phase = .syncing
        Self.trace("start bootstrapped=\(disk.state.bootstrapped)")
        if !disk.state.bootstrapped { bootstrap() } else { localChanged(readLocal(), allowDeletes: false) }
        Task { await checkAccount() }
    }

    /// 끄면 이 기기의 맞춤 상태만 지운다. iCloud 와 다른 기기의 데이터는 그대로다.
    func stop() {
        sendTask?.cancel()
        engine = nil
        busy = 0
        disk = Disk()
        try? FileManager.default.removeItem(at: Self.fileURL)
        phase = .off
    }

    private func bootstrap() {
        guard let engine else { return }
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        let out = SyncMerge.outgoing(readLocal(), state: &disk.state, now: Date(), allowDeletes: false, firstTime: true)
        disk.state.bootstrapped = true
        enqueue(out)
        save()
    }

    private func checkAccount() async {
        let status = try? await CKContainer(identifier: Self.containerID).accountStatus()
        Self.trace("account \(status?.rawValue ?? -1)")
        if let status, status != .available { phase = .noAccount }
    }

    // MARK: 이 기기에서 바뀜

    /// 저장할 때마다 부른다. allowDeletes 는 사용자가 앱 안에서 바꾼 직후에만 true.
    func localChanged(_ data: AppData, allowDeletes: Bool) {
        guard engine != nil else { return }
        let out = SyncMerge.outgoing(data, state: &disk.state, now: Date(), allowDeletes: allowDeletes)
        guard !out.isEmpty else { return }
        enqueue(out)
        save()
    }

    /// 앞으로 올 때처럼 '지금 바로' 양쪽을 맞춘다
    func refresh() {
        guard engine != nil else { return }
        localChanged(readLocal(), allowDeletes: false)
        push(fetchFirst: true)
    }

    private func enqueue(_ out: SyncOutbox) {
        guard let engine, !out.isEmpty else { return }
        // 같은 열쇠에 반대 동작이 남아 있으면 먼저 뺀다 (지웠다 되살렸거나 그 반대)
        engine.state.remove(pendingRecordZoneChanges: out.saves.map { .deleteRecord(Self.id($0)) } + out.deletes.map { .saveRecord(Self.id($0)) })
        engine.state.add(pendingRecordZoneChanges: out.saves.map { .saveRecord(Self.id($0)) } + out.deletes.map { .deleteRecord(Self.id($0)) })
        for k in out.deletes { disk.meta[k] = nil }
        // 엔진이 알아서 보내지만 몇 초 걸린다 — 바로 민다 (0.4초 몰아서)
        push()
    }

    /// 지금 보낸다. 엔진이 일하는 중이면 끝날 때까지 기다렸다가 (엔진도 스스로 보내니 놓쳐도 된다).
    private func push(fetchFirst: Bool = false) {
        sendTask?.cancel()
        sendTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            for _ in 0..<40 {
                guard !Task.isCancelled, let self, let engine = self.engine else { return }
                if self.busy == 0 {
                    do {
                        if fetchFirst { try await engine.fetchChanges() }
                        guard self.busy == 0, !Task.isCancelled else { return }
                        if !engine.state.pendingRecordZoneChanges.isEmpty || !engine.state.pendingDatabaseChanges.isEmpty {
                            try await engine.sendChanges()
                        }
                    } catch { self.note(error) }
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    // MARK: 다른 기기에서 옴

    private func applyRemote(_ changes: [SyncIncoming]) {
        guard let engine, !changes.isEmpty else { return }
        let local = readLocal()
        // 위젯처럼 앱 밖에서 바뀐 것을 먼저 챙긴다 — 그래야 아래에서 다시 지을 때 잃지 않는다
        enqueue(SyncMerge.outgoing(local, state: &disk.state, now: Date(), allowDeletes: false))
        let pendingSaves = Set(engine.state.pendingRecordZoneChanges.compactMap { c -> String? in
            if case .saveRecord(let id) = c { return id.recordName }
            return nil
        })
        let r = SyncMerge.incoming(changes, state: &disk.state, pending: pendingSaves)
        engine.state.remove(pendingRecordZoneChanges: r.accepted.flatMap { [.saveRecord(Self.id($0)), .deleteRecord(Self.id($0))] })
        for c in changes where c.body == nil { disk.meta[c.key] = nil }
        enqueue(SyncOutbox(saves: [], deletes: r.dropDuplicates))
        writeMerged(SyncMerge.rebuilt(local, state: disk.state))
        lastRemote = Date()
        save()
    }

    // MARK: 엔진이 부르는 것

    /// 무엇이 오갔는지만 적는다 (사용자 글은 적지 않는다)
    private static let log = Logger(subsystem: "io.github.bunhine0452.udada", category: "sync")
    private static let traceToFile = ProcessInfo.processInfo.arguments.contains("-udSyncTrace")

    private static func trace(_ line: String) {
        log.notice("\(line, privacy: .public)")
        guard traceToFile else { return }
        let url = DataFile.directory.appendingPathComponent("sync-trace.log")
        let row = Data((String(format: "%.3f ", Date().timeIntervalSince1970) + line + "\n").utf8)
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(row); try? h.close() } else { try? row.write(to: url) }
    }

    fileprivate func handle(_ event: CKSyncEngine.Event) {
        switch event {
        case .stateUpdate: break
        case .sentRecordZoneChanges(let e):
            Self.log.notice("sent saved=\(e.savedRecords.count) deleted=\(e.deletedRecordIDs.count) failed=\(e.failedRecordSaves.map { "\($0.error.code.rawValue)" }.joined(separator: ","), privacy: .public)")
        case .fetchedRecordZoneChanges(let e):
            Self.trace("fetched mod=\(e.modifications.count) del=\(e.deletions.count)")
        case .sentDatabaseChanges(let e):
            Self.log.notice("zones saved=\(e.savedZones.count) failed=\(e.failedZoneSaves.map { "\($0.error.code.rawValue)" }.joined(separator: ","), privacy: .public)")
        default:
            Self.trace("event \(String(describing: event).prefix(60))")
        }
        switch event {
        case .stateUpdate(let e):
            disk.engine = e.stateSerialization
            save()
        case .accountChange(let e):
            switch e.changeType {
            case .signIn:
                disk.state = SyncState(); disk.meta = [:]
                bootstrap()
                phase = .syncing
            case .signOut, .switchAccounts:
                // 이 기기의 데이터는 그대로 두고 맞춤 상태만 버린다. 새 계정으로는 처음부터 다시 맞춘다.
                disk.state = SyncState(); disk.meta = [:]
                save()
                if case .signOut = e.changeType { phase = .noAccount } else { bootstrap() }
            @unknown default: break
            }
        case .fetchedDatabaseChanges(let e):
            for d in e.deletions where d.zoneID == Self.zoneID {
                // iCloud 에서 우다다 데이터가 지워졌다. 사용자가 직접 비웠으면(purged) 다시 올리지 않는다.
                disk.state = SyncState(); disk.meta = [:]
                save()
                if d.reason == .purged { engine = nil; phase = .off } else { bootstrap() }
            }
        case .fetchedRecordZoneChanges(let e):
            var changes: [SyncIncoming] = []
            for m in e.modifications where m.record.recordID.zoneID == Self.zoneID {
                let key = m.record.recordID.recordName
                disk.meta[key] = Self.systemFields(m.record)
                if let c = Self.incoming(m.record) { changes.append(c) }
            }
            for d in e.deletions where d.recordID.zoneID == Self.zoneID {
                changes.append(SyncIncoming(key: d.recordID.recordName, body: nil))
            }
            applyRemote(changes)
        case .sentRecordZoneChanges(let e):
            for r in e.savedRecords { disk.meta[r.recordID.recordName] = Self.systemFields(r) }
            var changes: [SyncIncoming] = []
            var retry: [CKSyncEngine.PendingRecordZoneChange] = []
            for f in e.failedRecordSaves {
                let key = f.record.recordID.recordName
                switch f.error.code {
                case .serverRecordChanged:
                    // 다른 기기가 먼저 고쳤다. 더 나중에 고친 쪽이 이긴다.
                    guard let server = f.error.serverRecord else { continue }
                    disk.meta[key] = Self.systemFields(server)
                    let theirs = (server["stamp"] as? Date) ?? .distantPast
                    if let mine = disk.state.stamps[key], mine > theirs {
                        retry.append(.saveRecord(f.record.recordID))
                    } else if let c = Self.incoming(server) {
                        changes.append(c)
                    }
                case .zoneNotFound, .userDeletedZone:
                    engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
                    retry.append(.saveRecord(f.record.recordID))
                case .unknownItem:
                    // 서버에서는 지워졌는데 여기서 고쳤다 → 고친 것을 살린다
                    disk.meta[key] = nil
                    retry.append(.saveRecord(f.record.recordID))
                default:
                    break // 네트워크·한도 같은 것은 엔진이 다시 보낸다
                }
            }
            if !retry.isEmpty { engine?.state.add(pendingRecordZoneChanges: retry) }
            applyRemote(changes)
            save()
        case .willFetchChanges, .willSendChanges:
            busy += 1
            if phase != .noAccount { phase = .syncing }
        case .didFetchChanges, .didSendChanges:
            busy = max(0, busy - 1)
            if phase != .noAccount, busy == 0 { phase = .ok(Date()) }
        case .didFetchRecordZoneChanges(let e):
            if let err = e.error { note(err) }
        case .sentDatabaseChanges, .willFetchRecordZoneChanges:
            break
        @unknown default:
            break
        }
    }

    fileprivate func nextBatch(_ context: CKSyncEngine.SendChangesContext, engine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = engine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { id in
            await self.record(for: id)
        }
    }

    private func record(for id: CKRecord.ID) -> CKRecord? {
        let key = id.recordName
        guard let body = disk.state.shadow[key] else {
            engine?.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
            return nil
        }
        let record = disk.meta[key].flatMap(Self.restore) ?? CKRecord(recordType: Self.recordType, recordID: id)
        record["body"] = String(decoding: body, as: UTF8.self) as CKRecordValue
        record["stamp"] = (disk.state.stamps[key] ?? Date()) as CKRecordValue
        return record
    }

    // MARK: 작은 도구

    private func note(_ error: Error) {
        Self.trace("sync error \(String(describing: error).prefix(300))")
        let ck = error as? CKError
        if ck?.code == .notAuthenticated { phase = .noAccount; return }
        // 끊긴 것은 엔진이 다시 한다 — 화면에는 알리지 않는다
        if let code = ck?.code, [.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy, .operationCancelled].contains(code) { return }
        if error is CancellationError { return }
        phase = .failed(error.localizedDescription)
    }

    private func save() {
        guard let raw = try? JSONEncoder().encode(disk) else { return }
        try? raw.write(to: Self.fileURL, options: .atomic)
    }

    private static func id(_ key: String) -> CKRecord.ID { CKRecord.ID(recordName: key, zoneID: zoneID) }

    private static func incoming(_ r: CKRecord) -> SyncIncoming? {
        guard let body = r["body"] as? String else { return nil }
        return SyncIncoming(key: r.recordID.recordName, body: Data(body.utf8), stamp: (r["stamp"] as? Date) ?? .distantPast)
    }

    private static func systemFields(_ r: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        r.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    private static func restore(_ data: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        let r = CKRecord(coder: coder)
        coder.finishDecoding()
        return r
    }
}

/// CKSyncEngine 은 아무 스레드에서나 부른다 → 메인으로 넘겨 준다.
private final class Relay: CKSyncEngineDelegate, @unchecked Sendable {
    private weak var owner: CloudSync?
    init(_ owner: CloudSync) { self.owner = owner }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await owner?.handle(event)
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await owner?.nextBatch(context, engine: syncEngine)
    }
}
