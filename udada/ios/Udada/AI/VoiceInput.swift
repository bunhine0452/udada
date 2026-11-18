import AVFAudio
import Foundation
import Observation
import Speech

/// 말 → 글자 (한국어). 녹음은 저장하지 않는다.
/// iOS 26+: SpeechAnalyzer + SpeechTranscriber(없으면 DictationTranscriber) — 기기 안 모델, 처음엔 내려받는다.
/// 그 아래 / 모델이 아직 없으면: SFSpeechRecognizer(ko-KR) — 기기 안 인식이 되면 기기 안, 아니면 서버(`usesServer`).
/// 멈췄다 다시 말하면 이어 붙는다. 한 번에 3분까지.
@MainActor
@Observable
final class VoiceInput {
    enum State: Equatable {
        case idle, asking, listening
        case denied(String)
        case unavailable(String)
    }

    enum Recognizer: Equatable { case speechAnalyzer, dictation, onDevice, server }

    private(set) var state: State = .idle
    /// 확정된 글 + 지금 듣고 있는 글 (바로바로 바뀐다)
    var text: String { transcript.text }
    /// 마이크 소리 크기 0…1 (막대 표시용)
    private(set) var level: Double = 0
    /// 이번에 고른 인식기
    private(set) var recognizer: Recognizer?
    /// 서버에서 글자로 바꾸는 중 (기기 안 인식을 못 하는 기기)
    var usesServer: Bool { recognizer == .server }
    /// 이번에 듣기 시작한 뒤 지난 시간 (3분이면 멈춘다)
    private(set) var elapsed: TimeInterval = 0
    /// 3분이 차서 멈췄다
    private(set) var stoppedByLimit = false
    /// 한국어 받아쓰기 모델을 내려받는 중이면 0…1
    private(set) var preparing: Double?

    static let limit: TimeInterval = 180

    private var transcript = Transcript()
    @ObservationIgnored private var engine = AVAudioEngine()
    @ObservationIgnored private var tapped = false
    @ObservationIgnored private var backend: Backend?
    @ObservationIgnored private var part: Int?
    @ObservationIgnored private var token = 0
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private let meter = MeterBox()

    init() {}

    // MARK: - 듣기

    func start() async {
        guard state != .listening, state != .asking else { return }
        token &+= 1
        let my = token
        stoppedByLimit = false
        elapsed = 0
        state = .asking

        guard await Self.micGranted() else {
            return fail(my, .denied("마이크가 꺼져 있어. 설정에서 마이크를 켜 줘."))
        }
        switch await Self.speechAuthorization() {
        case .authorized: break
        case .restricted: return fail(my, .unavailable("이 기기에서는 받아쓰기가 막혀 있어."))
        default: return fail(my, .denied("음성 인식이 꺼져 있어. 설정에서 음성 인식을 켜 줘."))
        }
        guard my == token else { return }

        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try s.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return fail(my, .unavailable("지금은 마이크를 쓸 수 없어. 통화나 다른 녹음이 끝나면 다시 해 줘."))
        }
        let engine = AVAudioEngine()
        self.engine = engine
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            deactivate()
            return fail(my, .unavailable("마이크를 찾지 못했어."))
        }

        let id = transcript.begin()
        var made: Backend?
        if #available(iOS 26, *) { made = await makeAnalyzer(format: format, part: id, download: false) }
        if made == nil, my == token { made = makeLegacy(part: id) }
        if made == nil, my == token, #available(iOS 26, *) { made = await makeAnalyzer(format: format, part: id, download: true) }
        guard my == token else { made?.cancel(); transcript.close(id); return }
        guard let made else {
            transcript.close(id)
            deactivate()
            if state == .asking { state = .unavailable("이 기기에서는 한국어 받아쓰기를 쓸 수 없어.") }
            return
        }

        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tap(feed: made.feed, meter: meter))
        tapped = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            made.cancel()
            transcript.close(id)
            teardown()
            return fail(my, .unavailable("마이크를 켜지 못했어. 잠시 뒤에 다시 해 줘."))
        }
        backend = made
        part = id
        recognizer = made.kind
        startedAt = Date()
        state = .listening
        observeInterruptions()
        startClock()
    }

    /// 듣기를 멈추고 지금까지의 글을 돌려준다. 마지막 몇 마디는 곧 확정돼 `text` 에 반영된다.
    @discardableResult
    func stop() -> String {
        token &+= 1
        guard state == .listening || state == .asking else { return text }
        let b = backend
        backend = nil
        teardown()
        state = .idle
        if let b { Task { await b.finish() } }
        return text
    }

    /// 멈추고 마지막 마디가 확정될 때까지 잠깐(최대 2.5초) 기다린 뒤 글을 돌려준다.
    func finish() async -> String {
        let last = part
        stop()
        if let last {
            for _ in 0..<25 where !transcript.isClosed(last) {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        return text
    }

    /// 듣기를 그만두고 글도 지운다.
    func cancel() {
        token &+= 1
        let b = backend
        backend = nil
        if tapped || state == .listening || state == .asking { teardown() }
        b?.cancel()
        transcript.clear()
        part = nil
        elapsed = 0
        stoppedByLimit = false
        if case .denied = state { return }
        state = .idle
    }

    // MARK: - 결과 받기 (인식기 → 여기)

    fileprivate func receive(_ s: String, final: Bool, part id: Int) {
        if final { transcript.final(s, part: id) } else { transcript.volatile(s, part: id) }
    }
    fileprivate func receiveCumulative(_ s: String, final: Bool, part id: Int) {
        transcript.cumulative(s, final: final, part: id)
    }
    fileprivate func taskEnded(part id: Int) { transcript.taskEnded(part: id) }
    fileprivate func close(part id: Int) { transcript.close(id) }

    // MARK: - 정리

    private func fail(_ my: Int, _ s: State) {
        guard my == token else { return }
        state = s
    }

    private func teardown() {
        clock?.cancel()
        clock = nil
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        engine.stop()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        deactivate()
        level = 0
        startedAt = nil
    }

    private func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startClock() {
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self, self.state == .listening, let t0 = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(t0)
                let v = Double(self.meter.take())
                self.level = max(v, self.level * 0.82)
                if self.elapsed >= Self.limit {
                    self.stoppedByLimit = true
                    self.stop()
                    return
                }
            }
        }
    }

    /// 전화가 오거나(끊김), 이어폰이 빠지거나, 오디오 장치가 바뀌면 멈춘다 — 글은 남긴다.
    private func observeInterruptions() {
        let nc = NotificationCenter.default
        observers = [
            nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
                MainActor.assumeIsolated { _ = self?.stop() }
            },
            nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                guard raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                MainActor.assumeIsolated { _ = self?.stop() }
            },
            nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.stop() }
            },
            nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.stop() }
            },
        ]
    }

    // MARK: - 권한

    nonisolated private static func micGranted() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }

    nonisolated private static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let now = SFSpeechRecognizer.authorizationStatus()
        guard now == .notDetermined else { return now }
        return await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
    }

    // MARK: - 마이크 탭 (오디오 스레드)

    nonisolated private static func tap(feed: @escaping @Sendable (AVAudioPCMBuffer) -> Void, meter: MeterBox) -> AVAudioNodeTapBlock {
        { buffer, _ in
            meter.push(level(of: buffer))
            feed(buffer)
        }
    }

    nonisolated private static func level(of b: AVAudioPCMBuffer) -> Float {
        guard let ch = b.floatChannelData, b.frameLength > 0 else { return 0 }
        let n = Int(b.frameLength)
        var sum: Float = 0
        for i in 0..<n { let v = ch[0][i]; sum += v * v }
        let db = 20 * log10(max(sqrt(sum / Float(n)), 1e-7))
        return min(1, max(0, (db + 55) / 45))
    }

    // MARK: - iOS 26: SpeechAnalyzer

    /// 기기 안 모델이 깔려 있으면 바로 쓴다. 없으면 뒤에서 내려받기만 걸고 nil (이번엔 옛 인식기로).
    /// `download` 이면 내려받기를 기다린다 (옛 인식기도 못 쓸 때).
    @available(iOS 26, *)
    private func makeAnalyzer(format: AVAudioFormat, part id: Int, download: Bool) async -> Backend? {
        let ko = Locale(identifier: "ko-KR")
        let module: any SpeechModule
        let kind: Recognizer
        let locale: Locale
        if SpeechTranscriber.isAvailable, let loc = await SpeechTranscriber.supportedLocale(equivalentTo: ko) {
            module = SpeechTranscriber(locale: loc, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
            kind = .speechAnalyzer
            locale = loc
        } else if let loc = await DictationTranscriber.supportedLocale(equivalentTo: ko) {
            module = DictationTranscriber(locale: loc, preset: .progressiveLongDictation)
            kind = .dictation
            locale = loc
        } else {
            return nil
        }

        // 기기에 모델이 있어도 앱이 언어를 예약하기 전엔 status 가 .supported 로 나온다 (macOS 27 에서 확인) — 먼저 예약
        _ = try? await AssetInventory.reserve(locale: locale)
        switch await AssetInventory.status(forModules: [module]) {
        case .installed:
            break
        case .unsupported:
            return nil
        default:
            guard download else {
                Task { try? await AssetInventory.assetInstallationRequest(supporting: [module])?.downloadAndInstall() }
                return nil
            }
            do {
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                    preparing = 0
                    let poll = Task { [weak self] in
                        while !Task.isCancelled {
                            self?.preparing = request.progress.fractionCompleted
                            try? await Task.sleep(nanoseconds: 200_000_000)
                        }
                    }
                    defer { poll.cancel(); preparing = nil }
                    try await request.downloadAndInstall()
                }
            } catch {
                return nil
            }
        }

        let target = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module], considering: format) ?? format
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [module])
        let results = Task { [weak self] in
            do {
                if let t = module as? SpeechTranscriber {
                    for try await r in t.results { self?.receive(String(r.text.characters), final: r.isFinal, part: id) }
                } else if let d = module as? DictationTranscriber {
                    for try await r in d.results { self?.receive(String(r.text.characters), final: r.isFinal, part: id) }
                }
            } catch {}
            self?.close(part: id)
        }
        do {
            try await analyzer.prepareToAnalyze(in: target)
            try await analyzer.start(inputSequence: stream)
        } catch {
            results.cancel()
            input.finish()
            return nil
        }
        return Backend(
            kind: kind,
            feed: Self.analyzerFeed(input, from: format, to: target),
            finish: {
                input.finish()
                try? await analyzer.finalizeAndFinishThroughEndOfInput()
                _ = await results.value
            },
            cancel: {
                input.finish()
                results.cancel()
                Task { await analyzer.cancelAndFinishNow() }
            })
    }

    /// 마이크 형식 → 분석기 형식으로 바꿔 흘려보낸다 (오디오 스레드).
    @available(iOS 26, *)
    nonisolated private static func analyzerFeed(_ input: AsyncStream<AnalyzerInput>.Continuation, from: AVAudioFormat, to: AVAudioFormat) -> @Sendable (AVAudioPCMBuffer) -> Void {
        guard from != to, let converter = AVAudioConverter(from: from, to: to) else {
            return { input.yield(AnalyzerInput(buffer: $0)) }
        }
        let box = ConverterBox(converter)
        return { buffer in
            let ratio = to.sampleRate / from.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
            guard let out = AVAudioPCMBuffer(pcmFormat: to, frameCapacity: capacity) else { return }
            var fed = false
            var error: NSError?
            box.converter.convert(to: out, error: &error) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true
                status.pointee = .haveData
                return buffer
            }
            if error == nil, out.frameLength > 0 { input.yield(AnalyzerInput(buffer: out)) }
        }
    }

    // MARK: - SFSpeechRecognizer

    private func makeLegacy(part id: Int) -> Backend? {
        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR")), rec.isAvailable else { return nil }
        rec.queue = .main
        let session = LegacySession(rec: rec, owner: self, part: id)
        session.begin()
        return Backend(
            kind: rec.supportsOnDeviceRecognition ? .onDevice : .server,
            feed: { [box = session.box] in box.append($0) },
            finish: { await session.finish() },
            cancel: { session.cancel() })
    }
}

// MARK: - 도우미

/// 인식기 하나를 감싼다: 탭이 흘려보낼 곳, 끝내기(확정 기다림), 버리기.
fileprivate struct Backend {
    let kind: VoiceInput.Recognizer
    let feed: @Sendable (AVAudioPCMBuffer) -> Void
    let finish: @MainActor () async -> Void
    let cancel: @MainActor () -> Void
}

/// 오디오 스레드가 쓰고 메인이 읽는 소리 크기 (마지막으로 읽은 뒤 가장 큰 값)
fileprivate final class MeterBox: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: Float = 0
    func push(_ v: Float) { lock.lock(); peak = max(peak, v); lock.unlock() }
    func take() -> Float { lock.lock(); defer { peak = 0; lock.unlock() }; return peak }
}

fileprivate final class ConverterBox: @unchecked Sendable {
    let converter: AVAudioConverter
    init(_ c: AVAudioConverter) { converter = c }
}

/// 지금 받는 SF 요청 (작업을 갈아 끼우면 탭이 새 요청으로 흘린다)
fileprivate final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    func set(_ r: SFSpeechAudioBufferRecognitionRequest?) { lock.lock(); request = r; lock.unlock() }
    func append(_ b: AVAudioPCMBuffer) { lock.lock(); let r = request; lock.unlock(); r?.append(b) }
    func endAudio() { lock.lock(); let r = request; request = nil; lock.unlock(); r?.endAudio() }
}

/// SFSpeechRecognizer 작업 이어 달리기: 서버 1분 제한 등으로 작업이 끝나도 듣는 중이면 새 작업으로 잇는다.
@MainActor
fileprivate final class LegacySession {
    let box = RequestBox()
    private let rec: SFSpeechRecognizer
    private weak var owner: VoiceInput?
    private let part: Int
    private var task: SFSpeechRecognitionTask?
    private var ending = false
    private var restarts = 0
    private var done = false

    init(rec: SFSpeechRecognizer, owner: VoiceInput, part: Int) {
        self.rec = rec
        self.owner = owner
        self.part = part
    }

    func begin() {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = rec.supportsOnDeviceRecognition
        req.addsPunctuation = true
        req.taskHint = .dictation
        box.set(req)
        task = rec.recognitionTask(with: req, resultHandler: Self.handler(self))
    }

    func finish() async {
        ending = true
        box.endAudio()
        for _ in 0..<30 where !done { try? await Task.sleep(nanoseconds: 100_000_000) }
        if !done { task?.cancel(); end() }
    }

    func cancel() {
        ending = true
        box.set(nil)
        task?.cancel()
        done = true
    }

    nonisolated private static func handler(_ s: LegacySession) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak s] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let segmentEnded = result?.speechRecognitionMetadata != nil
            let failed = error != nil
            let session = s
            DispatchQueue.main.async {
                MainActor.assumeIsolated { session?.receive(text, isFinal: isFinal, segmentEnded: segmentEnded, failed: failed) }
            }
        }
    }

    private func receive(_ text: String?, isFinal: Bool, segmentEnded: Bool, failed: Bool) {
        guard !done else { return }
        if let text { owner?.receiveCumulative(text, final: isFinal || segmentEnded, part: part) }
        guard isFinal || failed else { return }
        owner?.taskEnded(part: part)
        if ending || restarts >= 30 { end(); return }
        restarts += 1
        begin()
    }

    private func end() {
        guard !done else { return }
        done = true
        owner?.close(part: part)
    }
}

// MARK: - 받아쓰기 조립

extension VoiceInput {
    /// 확정된 마디와 아직 바뀌는 마디를 이어 붙인다. 듣기 한 번이 한 칸(part) — 멈췄다 다시 말하면 칸이 늘어나고 줄이 바뀐다.
    /// · SpeechAnalyzer 식: `volatile` 은 지난 확정 뒤의 글 전체를 갈아 끼우고, `final` 은 확정 마디를 덧붙인다.
    /// · SFSpeech 식(`cumulative`): 작업 하나의 글 전체가 매번 온다. 확정되면(마디 끝 포함) 붙이고,
    ///   그 뒤에도 앞부분을 다시 보내면 이미 붙인 앞부분은 떼며, 쉼 뒤에 글이 처음부터 다시 시작돼도 앞 글을 잃지 않는다.
    struct Transcript: Equatable {
        struct Part: Equatable {
            var id: Int
            var finals: [String] = []
            var volatile = ""
            /// 이번 SF 작업에서 이미 확정한 글 (작업 글 전체 기준)
            var committed = ""
            var closed = false
        }

        private(set) var parts: [Part] = []
        private var nextID = 0

        /// 칸 안의 마디는 띄어 쓰고, 멈췄다 다시 말한 칸은 줄을 바꾼다 (생각 하나가 한 줄이 되기 쉽게).
        var text: String {
            parts.map { p in
                (p.finals + [p.volatile])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        }

        mutating func begin() -> Int {
            nextID += 1
            parts.append(Part(id: nextID))
            return nextID
        }

        mutating func volatile(_ s: String, part id: Int) {
            edit(id) { $0.volatile = s }
        }

        mutating func final(_ s: String, part id: Int) {
            edit(id) { p in
                p.finals.append(s)
                p.volatile = ""
            }
        }

        mutating func cumulative(_ s: String, final: Bool, part id: Int) {
            edit(id) { p in
                var t = s
                if !p.committed.isEmpty, t.hasPrefix(p.committed) {
                    t = String(t.dropFirst(p.committed.count))
                } else if Self.restarted(from: p.volatile, to: t) {
                    // 쉼 뒤에 SF 가 확정 표시 없이 글을 처음부터 다시 보냈다 — 앞 글을 확정으로 남긴다
                    p.finals.append(p.volatile)
                }
                if final {
                    p.finals.append(t)
                    p.volatile = ""
                    p.committed = s
                } else {
                    p.volatile = t
                }
            }
        }

        mutating func taskEnded(part id: Int) {
            edit(id) { p in
                if !p.volatile.isEmpty { p.finals.append(p.volatile); p.volatile = "" }
                p.committed = ""
            }
        }

        /// 이 칸은 더 받지 않는다 — 남은 바뀌는 글은 확정으로.
        mutating func close(_ id: Int) {
            edit(id) { p in
                if !p.volatile.isEmpty { p.finals.append(p.volatile); p.volatile = "" }
                p.closed = true
            }
        }

        func isClosed(_ id: Int) -> Bool { parts.first { $0.id == id }?.closed ?? true }

        mutating func clear() { parts = [] }

        private mutating func edit(_ id: Int, _ f: (inout Part) -> Void) {
            guard let i = parts.firstIndex(where: { $0.id == id }), !parts[i].closed else { return }
            f(&parts[i])
        }

        /// 새 글이 앞 글과 첫 글자부터 다르고 절반도 안 되게 짧으면, 고친 게 아니라 새로 시작한 것.
        static func restarted(from old: String, to new: String) -> Bool {
            guard old.count >= 6, !new.isEmpty else { return false }
            return old.first != new.first && new.count * 2 < old.count
        }
    }
}
