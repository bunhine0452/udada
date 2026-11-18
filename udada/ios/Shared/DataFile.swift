import Foundation

/// 저장 파일 하나 (JSON). 앱 그룹 컨테이너에 두어 위젯도 같은 파일을 읽는다.
/// 기기 밖으로는 사용자의 개인 iCloud 로만 나간다 (기기 맞추기를 켰을 때 — Udada/Sync/CloudSync.swift).
enum DataFile {
    static let group = "group.io.github.bunhine0452.udada"
    static let name = "udada-v5.json"

    static var directory: URL {
        // -udDataDir <경로> : 확인용으로 저장소를 따로 둔다 (두 기기를 한 Mac 에서 흉내 낼 때)
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-udDataDir"), i + 1 < args.count {
            let u = URL(fileURLWithPath: args[i + 1], isDirectory: true)
            try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
            return u
        }
        #if os(macOS)
        // Mac 은 앱 자기 보관함에 (위젯 확장이 없다)
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Udada", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
        #else
        if let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) { return u }
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
        #endif
    }
    static var url: URL { directory.appendingPathComponent(name) }

    static func load() -> AppData {
        guard let raw = try? Data(contentsOf: url) else { return AppData() }
        do {
            return try JSONDecoder().decode(AppData.self, from: raw)
        } catch {
            // 읽을 수 없는 파일은 지우지 않고 옆에 남겨 둔다 — 빈 데이터로 덮어써 기록을 잃지 않게.
            let broken = directory.appendingPathComponent("udada-v5.broken-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: url, to: broken)
            return AppData()
        }
    }

    static func save(_ data: AppData) {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: url, options: .atomic)
    }

    static func reset() { try? FileManager.default.removeItem(at: url) }

    /// 내보내기용 (읽기 좋은 JSON)
    static func exportData(_ data: AppData) -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return (try? enc.encode(data)) ?? Data()
    }
}
