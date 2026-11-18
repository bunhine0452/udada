import AVFoundation
import Foundation
import Speech

// 녹음에서 할 일 찾기: 회의·통화 녹음 파일을 기기 안에서 받아쓰고(SpeechAnalyzer), 받아쓴 글을 '밖에서 받기'(Brain.capture)에 넣는다.
// 녹음도 받아쓴 글도 기기를 떠나지 않고, 저장하지 않는다. 누가 한 말인지는 가리지 못한다 — 나온 줄에서 내 것만 고르는 것은 사용자가 한다.

enum AudioNotes {
    enum Failure: Error { case unsupported, unreadable, empty }

    static func message(_ e: Error) -> String {
        switch e as? Failure {
        case .unsupported: "이 기기에서는 녹음을 기기 안에서 받아쓸 수 없어"
        case .unreadable: "녹음 파일을 열 수 없어"
        default: "녹음에서 말을 못 알아들었어"
        }
    }

    /// 녹음 파일 → 받아쓴 글. 한국어 받아쓰기 모델이 없으면 처음 한 번 내려받는다.
    static func transcribe(_ url: URL) async throws -> String {
        guard #available(iOS 26.0, macOS 26.0, *) else { throw Failure.unsupported }
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "ko-KR")) else { throw Failure.unsupported }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let file = try? AVAudioFile(forReading: url) else { throw Failure.unreadable }
        let module = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) { try await request.downloadAndInstall() }
        let analyzer = SpeechAnalyzer(modules: [module])
        let reading = Task { () -> String in
            var parts: [String] = []
            for try await r in module.results where r.isFinal { parts.append(String(r.text.characters)) }
            return parts.joined(separator: " ")
        }
        do {
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            reading.cancel()
            throw Failure.unreadable
        }
        let text = try await reading.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { throw Failure.empty }
        return text
    }

    static let types = ["m4a", "mp3", "wav", "aiff", "aif", "caf", "aac", "mp4", "m4b"]
    static func isAudio(_ url: URL) -> Bool { types.contains(url.pathExtension.lowercased()) }
}
