import Foundation

/// 밖에서 받아 둔 것: 공유 확장이 여기에 파일로 넣고, 앱이 열릴 때 꺼내 정리한다 (글 .txt · 그림 .jpg · 녹음은 원래 확장자).
/// 앱 그룹 보관함 안에만 있고, 정리하면 지운다.
enum Inbox {
    static let group = "group.io.github.bunhine0452.udada"

    static var directory: URL {
        let args = ProcessInfo.processInfo.arguments
        var base: URL
        if let i = args.firstIndex(of: "-udDataDir"), i + 1 < args.count {
            base = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        } else if let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            base = u
        } else {
            base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        }
        base.appendPathComponent("inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func fresh(_ ext: String) -> URL {
        directory.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(6)).\(ext)")
    }

    @discardableResult static func put(text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2 else { return false }
        return (try? Data(String(t.prefix(8000)).utf8).write(to: fresh("txt"), options: .atomic)) != nil
    }

    @discardableResult static func put(image data: Data) -> Bool {
        (try? data.write(to: fresh("jpg"), options: .atomic)) != nil
    }

    /// 녹음 파일은 복사해 둔다 (공유가 끝나면 원본에 닿을 수 없다)
    @discardableResult static func put(file url: URL) -> Bool {
        (try? FileManager.default.copyItem(at: url, to: fresh(url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased()))) != nil
    }

    /// 받은 순서대로
    static func items() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func remove(_ urls: [URL]) { for u in urls { try? FileManager.default.removeItem(at: u) } }
}
