import CoreGraphics
import Foundation

/// 기기 안 AI(Apple 지능)를 쓰는 곳은 전부 여기를 지난다.
/// - 꺼져 있거나 · 기기가 지원하지 않거나 · 6초 안에 못 끝내거나 · 결과가 검사를 못 넘으면 규칙(BrainRules)으로 같은 모양을 돌려준다 (fromAI = false).
/// - 위기 낱말은 어떤 AI 호출보다 먼저 본다. 위기 글은 모델에 보내지 않는다.
/// - 모델 호출은 메인 스레드 밖에서, 짧은 세션 하나로. 모든 처리는 기기 안에서만.
@MainActor
final class Brain {
    static let shared = Brain()

    enum Status: Equatable { case ready, off, unavailable(String) }

    /// 설정에서 껐으면 .off, 모델이 없으면 .unavailable(이유)
    var status: Status {
        if let store = Store.live, !store.settings.aiOn { return .off }
        return Brain.modelStatus()
    }

    var isReady: Bool { status == .ready }

    private var stepCache: [String: String] = [:]
    private var breakCache: [String: [String]] = [:]
    private var warm: AnyObject?
    private var warmedAt: Date?

    /// 비우기 화면을 열 때 부른다. 모델을 미리 올려 첫 응답을 당긴다 (1분에 한 번만).
    func prewarm() {
        guard isReady else { return }
        if let t = warmedAt, Date().timeIntervalSince(t) < 60 { return }
        warmedAt = Date()
        warm = Brain.warmSession()
    }

    // MARK: 비우기

    /// 쏟아낸 글(말 받아쓰기 포함) → 카드들. 각 줄은 사용자의 낱말로 짧게, 칸·날·띠·길이 제안까지.
    func organize(_ raw: String, today: DayKey, now: Date) async -> [DumpSuggestion] {
        let parts = self.parts
        let pieces = BrainRules.split(raw)
        let rules = pieces.map { BrainRules.suggest($0, today: today, now: now, parts: parts) }
        guard isReady, !rules.isEmpty, !BrainRules.isCrisis(raw) else { return rules }

        // 길면 조각을 몇 개씩 묶어 차례로 보낸다. 시간이 다 되면 남은 묶음은 규칙으로.
        let groups = Brain.groups(raw, pieces: pieces)
        let end = Date().addingTimeInterval(min(14, 6 + 4 * Double(groups.count - 1)))
        var out: [DumpSuggestion] = []
        var useAI = true
        var warm = takeWarm()
        for g in groups {
            let left = end.timeIntervalSinceNow
            let started = Date()
            if useAI, left > 1.5,
               let drafts = await deadline(min(6, left), { [warm] in try await Brain.aiOrganize(g.text, warm: warm) }),
               let ok = BrainRules.finish(drafts, raw: g.text, today: today, now: now, parts: parts) {
                out += ok
            } else {
                // 늦어서 놓쳤으면 다음 묶음도 늦을 테니 규칙으로 간다
                if Date().timeIntervalSince(started) >= min(6, left) - 0.2 { useAI = false }
                out += rules[g.range]
            }
            warm = nil
        }
        return out
    }

    /// 쏟아낸 글 → 카드들을 **흘려서** 준다. 먼저 규칙 카드가 바로 나오고(기다림 없음), 모델이 한 장씩 다듬을 때마다 그 조각의 카드가 바뀐 목록이 다시 온다.
    /// 뼈대는 늘 규칙이 자른 조각이라 도중의 어느 목록을 써도 줄이 빠지지 않는다. 카드의 piece 로 어느 것이 바뀌었는지 안다.
    func organizeStream(_ raw: String, today: DayKey, now: Date) -> AsyncStream<[DumpSuggestion]> {
        let parts = self.parts
        let pieces = BrainRules.split(raw)
        var rules = pieces.map { BrainRules.suggest($0, today: today, now: now, parts: parts) }
        for i in rules.indices { rules[i].piece = i }
        let ready = isReady && !rules.isEmpty && !BrainRules.isCrisis(raw)
        let groups = Brain.groups(raw, pieces: pieces)
        let single = groups.count == 1
        // 모델에는 원문이 아니라 규칙이 자른 줄을 준다 (원문을 주면 더 잃는다 — AI.md 11절)
        let lines = groups.first?.text ?? raw
        let warm = ready && single ? takeWarm() : nil
        return AsyncStream { continuation in
            continuation.yield(rules)
            guard ready else { continuation.finish(); return }
            let task = Task { @MainActor in
                if single {
                    // 한 묶음이면 흘려 받는다 (6초 안에 못 끝내면 그때까지 온 것으로)
                    let final = await self.deadline(6) { [warm] in
                        try await Brain.aiOrganizeStream(lines, warm: warm) { drafts in
                            if let ok = BrainRules.finish(drafts, raw: lines, today: today, now: now, parts: parts) { continuation.yield(ok) }
                        }
                    }
                    if let final, let ok = BrainRules.finish(final, raw: lines, today: today, now: now, parts: parts) { continuation.yield(ok) }
                } else {
                    // 길어서 여러 묶음이면 묶음 단위로 (조각 번호는 다시 매긴다)
                    var out = await self.organize(raw, today: today, now: now)
                    for i in out.indices { out[i].piece = i }
                    continuation.yield(out)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 카드 하나 다시 고르기 (글은 그대로, 칸·날·띠·길이만)
    func suggest(for line: String, today: DayKey, now: Date) async -> DumpSuggestion {
        let parts = self.parts
        let rule = BrainRules.suggest(line, today: today, now: now, parts: parts)
        guard isReady, !BrainRules.isCrisis(line), rule.text.count >= 2,
              let d = await deadline(6, { [text = rule.text] in try await Brain.aiCard(text) }) else { return rule }
        let parsed = Parser.parse(rule.text, now: now, parts: parts)
        let bin = BrainRules.reconcile(BrainRules.trustDrop(d.bin, text: rule.text, rule: rule.bin), parsed: parsed, today: today)
        var s = BrainRules.make(rule.text, bin: bin, parsed: parsed, today: today, now: now, parts: parts, calendar: .current, fromAI: true)
        s.id = rule.id
        return s
    }

    // MARK: 첫 동작

    /// 2분 안에 몸으로 할 수 있는 첫 동작 하나 ("문서 열고 제목만 쓰기"). 제목이 비었으면 nil.
    /// 흔한 갈래(문서·전화·청소…)는 다듬어 둔 문장, 그 밖의 일만 AI 가 쓴다 (하네스: AI 는 흔한 일에 가끔 엉뚱했다).
    func firstStep(for title: String) async -> String? {
        let t = BrainRules.tidy(title)
        guard !t.isEmpty, !BrainRules.isCrisis(t) else { return nil }
        if let known = BrainRules.knownStep(for: t) { return known }
        if let c = stepCache[t] { return c }
        guard isReady, let ai = await deadline(6, { try await Brain.aiFirstStep(t) }),
              let ok = BrainRules.cleanStep(ai, title: t) else { return BrainRules.firstStep(for: t) }
        remember(ok, for: t, in: &stepCache)
        return ok
    }

    // MARK: 쪼개기

    /// 큰일 하나 → 순서대로 놓은 걸음 3~5개. 위기 글이면 nil.
    /// 흔한 갈래(발표·보고서·이사·여행…)는 다듬어 둔 걸음, 처음 보는 일만 모델이 쓰고 규칙이 검사한다 (첫 동작과 같은 이유 — 흔한 일에서 모델이 더 엉뚱했다).
    func breakdown(_ title: String, now: Date) async -> Breakdown? {
        let subject = BreakRules.subject(title, now: now, parts: parts)
        guard subject.count >= 2, !BrainRules.isCrisis(title) else { return nil }
        if let known = BreakRules.knownSteps(for: subject) { return Breakdown(subject: subject, steps: known, fromAI: false) }
        if let c = breakCache[subject] { return Breakdown(subject: subject, steps: c, fromAI: true) }
        guard isReady, let ai = await deadline(8, { try await Brain.aiBreakdown(subject) }),
              let ok = BreakRules.clean(ai, subject: subject) else {
            return Breakdown(subject: subject, steps: BreakRules.fallback(for: subject), fromAI: false)
        }
        if breakCache.count > 32 { breakCache.removeAll() }
        breakCache[subject] = ok
        return Breakdown(subject: subject, steps: ok, fromAI: true)
    }

    // MARK: 하루 열기 · 닫기 · 한 주
    // 사실을 말하는 문장은 규칙이 쓴다. 모델은 빈 하루에 없는 일을 지어내고 개수를 빼먹었다 (하네스, AI.md).
    // 정보를 주는 피드백만 동기를 올린다 (Deci 1999) — 숫자가 정확해야 한다. async 는 부르는 쪽을 바꾸지 않고 모델을 다시 붙일 자리.

    /// 하루 한 장의 사실만으로 한두 문장
    func brief(_ sheet: DaySheet, laterCount: Int, worryCount: Int) async -> String {
        BrainRules.brief(sheet, laterCount: laterCount, worryCount: worryCount)
    }

    func closing(done: Int, moved: Int, dropped: Int, tomorrowFirst: String?) async -> String {
        BrainRules.closing(done: done, moved: moved, dropped: dropped, tomorrowFirst: tomorrowFirst)
    }

    /// 2~3문장: 사실 · 다정하게 · 작은 제안 하나
    func weekly(_ s: WeekStats) async -> String {
        BrainRules.weekly(s)
    }

    // MARK: 걱정

    /// 내 손에 든 게 있나: 있으면 아주 작은 한 걸음, 없으면 걱정 시간까지 기다리게. 위기면 상담 전화.
    func worry(_ text: String) async -> WorryAdvice {
        if BrainRules.isCrisis(text) { return BrainRules.crisisAdvice() }
        let rule = BrainRules.worry(text)
        guard isReady, let ai = await deadline(6, { try await Brain.aiWorry(text) }) else { return rule }
        return BrainRules.finishWorry(inMyHands: ai.inMyHands, step: ai.step)
    }

    // MARK: 사진 보기

    /// 사진 → 한 줄씩. 그림을 볼 수 있는 모델이면 포스터·안내문에서 일정을 찾아 날짜와 이름을 묶고(검사는 BrainRules.lines),
    /// 아니면 글자 인식으로 읽은 줄을 그대로 돌려준다. 어느 쪽이든 이 줄들이 비우기 정리로 들어간다.
    func readPhoto(_ image: CGImage, ocr: [String]) async -> (lines: [String], fromAI: Bool) {
        let text = ocr.joined(separator: "\n")
        // 표가 있으면 칸 구조로 먼저 읽는다 (문서 인식 — 모델이 없어도 된다). 주간표·날짜 칸이 비는 표는 줄을 따라 읽으면 깨진다.
        let table = await TextScan.tableLines(in: image, now: Store.live?.now ?? Date())
        if table.count >= 2 { return (table, false) }
        guard isReady, Brain.canSeeImages(), !ocr.isEmpty, !BrainRules.isCrisis(text),
              let seen = await deadline(12, { try await Brain.aiSeePhoto(image, ocr: text) }) else { return (ocr, false) }
        let lines = BrainRules.lines(from: seen, ocr: ocr, now: Store.live?.now ?? Date())
        return lines.isEmpty ? (ocr, false) : (lines, true)
    }

    // MARK: 밖에서 받기

    /// 남이 보낸 글(메시지 · 메일 · 공지 · 받아쓴 녹음) → 내가 챙길 일정·할 일의 줄. 이 줄들이 비우기 정리로 들어간다.
    /// 뼈대는 규칙이 고른 문장이고(때가 읽히거나 부탁하는 말), 모델은 놓친 일을 보태고 긴 글에서 군말을 거른다 — 검사는 CaptureRules.
    func capture(_ text: String, now: Date) async -> (lines: [String], fromAI: Bool) {
        let rule = CaptureRules.lines(text, now: now)
        let short = String(text.prefix(1800))
        guard isReady, short.count >= 4, !BrainRules.isCrisis(text),
              let found = await deadline(8, { try await Brain.aiCapture(short) }) else { return (rule, false) }
        let model = CaptureRules.lines(from: found, source: text, now: now)
        let lines = CaptureRules.blend(rule: rule, model: model, now: now)
        return (lines, lines != rule)
    }

    // MARK: 말로 시키기

    /// 문장 → 계획 (아직 아무것도 바꾸지 않는다). 모델은 줄마다 동작과 가리킨 이름을 읽고, 실제 항목 찾기·날짜 읽기는 규칙이 한다.
    func plan(_ text: String, data: AppData, now: Date) async -> CommandPlan {
        let pieces = CommandRules.pieces(text)
        guard isReady, !pieces.isEmpty, pieces.count <= 12, !BrainRules.isCrisis(text),
              let readings = await deadline(6, { try await Brain.aiCommand(pieces) }) else {
            return CommandRules.plan(text, data: data, now: now)
        }
        return CommandRules.plan(text, readings: readings, data: data, now: now)
    }

    // MARK: 받은 약속에 답장

    /// 규칙이 쓴 답장을 Apple Intelligence 가 받은 글의 말투에 맞춰 다시 쓴다. 검사(ReplyRules.vet)를 넘은 문장만 바꾼다 — 못 넘으면 규칙 문장 그대로.
    func polish(_ check: ReplyCheck) async -> [ReplyDraft] {
        let rule = ReplyRules.drafts(check)
        guard isReady, !BrainRules.isCrisis(check.offer.message),
              let written = await deadline(8, { [facts = ReplyRules.facts(check)] in try await Brain.aiReply(facts) }) else { return rule }
        return rule.map { d in
            guard let raw = written[d.kind], let ok = ReplyRules.vet(raw, kind: d.kind, check: check) else { return d }
            return ReplyDraft(kind: d.kind, text: ok, fromAI: true)
        }
    }

    // MARK: 한 주 풀기

    /// "이번 주 너무 빡빡해" → 옮길 안 (아직 아무것도 바꾸지 않는다). 모델이 도구로 한 주를 직접 보고 고르고, 규칙이 실제 기록·빈 시간에 대어 검사한다.
    /// 모델의 안으로 다 안 풀리면 남은 만큼은 규칙이 채운다. 모델이 없거나 늦으면 규칙만으로 같은 모양의 안이 나온다. onTrace 로 보는 과정을 흘린다.
    func replan(_ text: String, data: AppData, external: [Entry] = [], now: Date, onTrace: @escaping @Sendable (ReplanTrace) -> Void = { _ in }) async -> ReplanResult {
        let snap = ReplanRules.snapshot(data: data, external: external, now: now)
        let ask = ReplanRules.read(text, snapshot: snap)
        let log = ReplanLog(onTrace: onTrace)
        var fromModel: [ReplanMove] = []
        var raw: [String] = []
        var kept = ask
        if isReady, !snap.todos.isEmpty, !BrainRules.isCrisis(text),
           let picked = await deadline(25, { () async throws -> (later: [Int], keep: [Int]) in
               do { return try await Brain.aiReplan(text, snapshot: snap, log: log) }
               catch { log.fail("\(error)"); throw error }
           }) {
            raw = ["미룸 " + picked.later.map(String.init).joined(separator: ","), "지킴 " + picked.keep.map(String.init).joined(separator: ",")]
            // 사용자가 지키라고 한 일은 모델이 미루자고 해도 지킨다. 모델이 지키자고 한 일은 규칙이 채울 때도 건드리지 않는다.
            // (날을 통째로 비우라고 했으면 모델의 '지킴'은 듣지 않는다 — 사용자가 다 옮기라고 한 것이다)
            if !ask.clear { kept.keep.formUnion(picked.keep.filter { n in !picked.later.contains(n) }) }
            fromModel = ReplanRules.choose(later: picked.later.filter { !ask.keep.contains($0) }, snapshot: snap, ask: ask)
        }
        // 모델이 도구를 안 불렀으면 규칙이 본 것을 과정으로 보여 준다
        if log.calls == 0 { ReplanRules.traces(snap, ask: ask).forEach(onTrace) }
        // 모델이 고른 것으로 다 안 풀리면 남은 만큼은 규칙이 채운다 (모델이 지키자고 한 일은 빼고)
        var moves = ReplanRules.fill(snapshot: snap, ask: kept, already: fromModel)
        if ReplanRules.overflow(ReplanRules.apply(moves, to: snap.cells), ask: ask) > 0, kept.keep != ask.keep {
            // 모델이 지키자고 한 일까지 옮겨야 풀리는 만큼은 '꺼 둔 선택지'로만 싣는다 — 넘침을 숫자로만 풀려고 때가 걸린 일을 미루지 않는다
            let more = ReplanRules.fill(snapshot: snap, ask: ask, already: moves)
            moves = more.map { m in var m = m; if !moves.contains(where: { $0.id == m.id }) { m.optional = true }; return m }
        }
        return ReplanResult(snapshot: snap, ask: ask, moves: moves, fromAI: !fromModel.isEmpty, toolCalls: log.calls, proposed: raw + (log.error.map { ["오류 " + $0] } ?? []))
    }

    // MARK: 말로 찾기

    /// 물음 → 답. 모델은 물음을 읽기만 하고(무엇을·언제·어떤 것), 찾기와 답 한 줄은 규칙이 실제 기록으로 한다.
    func find(_ question: String, data: AppData, today: DayKey) async -> FindAnswer {
        FindRules.answer(await readQuestion(question), data: data, today: today)
    }

    /// 뜻으로 넓히기: 낱말이 안 겹친 기록 가운데 물음과 뜻이 맞는 것을 모델이 목록에서 **베껴** 고른다 ("병원 가는 거" → 치과 · 내과 검진).
    /// 고를 수 있는 것이 실제 기록뿐이고, 때·상태·종류는 이미 규칙이 걸렀다. 더 찾은 게 없거나 모델이 없으면 nil — 화면은 낱말로 찾은 답 그대로.
    func findMore(_ question: String, answer: FindAnswer, data: AppData, today: DayKey) async -> FindAnswer? {
        let titles = FindRules.candidates(answer.query, data: data, today: today)
        // 낱말로 하나도 못 찾았을 때만 넓힌다. 낱말이 맞은 물음에서 넓힌 것은 틀린 것이 맞는 것보다 많았다 (네 묶음: 틀림 8 · 맞음 4).
        guard isReady, answer.hits.isEmpty, !titles.isEmpty, !BrainRules.isCrisis(question),
              let picked = await deadline(10, { try await Brain.aiPick(question, titles: titles, need: 3) }) else { return nil }
        let meaning = FindRules.trusted(picked, titles: titles)
        guard !meaning.isEmpty else { return nil }
        var q = answer.query
        q.fromAI = true
        return FindRules.answer(q, data: data, today: today, meaning: meaning)
    }

    /// 물음 읽기만 (평가에서 따로 잰다)
    func readQuestion(_ question: String) async -> FindQuery {
        let rule = FindRules.read(question)
        guard isReady, !BrainRules.isCrisis(question), let ai = await deadline(4, { try await Brain.aiFind(question) }) else { return rule }
        return FindRules.checked(model: ai, question: question)
    }

    // MARK: 한 줄 읽기 도우미

    /// Parser 가 시각을 못 찾았는데 때 낱말이 남아 있을 때만 (세 시 · 크리스마스 · 퇴근하고 · 다음 달 둘째 주 화요일). 아니면 nil.
    func assistParse(_ text: String, now: Date) async -> Parsed? {
        let parts = self.parts
        guard BrainRules.needsAssist(Parser.parse(text, now: now, parts: parts)) else { return nil }
        if let p = BrainRules.assistParse(text, now: now, parts: parts) { return p }
        guard isReady, !BrainRules.isCrisis(text),
              let w = await deadline(6, { [today = DayKey(now)] in try await Brain.aiWhen(text, today: today) }), w.count == 2 else { return nil }
        return BrainRules.applyWhen(phrase: w[0], canonical: w[1], to: text, now: now, parts: parts)
    }

    // MARK: - 안쪽

    private var parts: DayParts { Store.live?.settings.parts ?? DayParts() }

    private func takeWarm() -> AnyObject? {
        defer { warm = nil }
        return warm
    }

    private func remember(_ value: String, for key: String, in cache: inout [String: String]) {
        if cache.count > 64 { cache.removeAll() }
        cache[key] = value
    }

    /// 규칙으로 자른 조각을 한 줄씩 보낸다 (AI 가 끝맺음·칸에 집중하게). 길면 6개씩 묶는다 (맥락 창 · 6초 안에 들게).
    private static func groups(_ raw: String, pieces: [String]) -> [(text: String, range: Range<Int>)] {
        let size = pieces.count <= 8 && raw.count <= 400 ? max(1, pieces.count) : 6
        // 실험(-udEvalRaw): 한 묶음이면 규칙이 자른 줄 대신 원문을 그대로 준다
        if ProcessInfo.processInfo.arguments.contains("-udEvalRaw"), pieces.count <= size { return [(raw, 0..<pieces.count)] }
        return stride(from: 0, to: pieces.count, by: size).map { i in
            let r = i..<min(i + size, pieces.count)
            return (pieces[r].joined(separator: "\n"), r)
        }
    }

    /// work 를 메인 밖에서 돌리고 seconds 안에 못 끝내거나 실패하면 nil. 늦게 온 결과는 버린다.
    private func deadline<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async throws -> T) async -> T? {
        let race = Race<T>()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (c: CheckedContinuation<T?, Never>) in race.start(c, seconds: seconds, work: work) }
        } onCancel: {
            race.finish(nil)
        }
    }
}

/// 일과 시계 중 먼저 끝난 쪽만 이어 준다
private final class Race<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?
    private var worker: Task<Void, Never>?
    private var finished = false

    func start(_ c: CheckedContinuation<T?, Never>, seconds: Double, work: @escaping @Sendable () async throws -> T) {
        lock.lock()
        if finished { lock.unlock(); c.resume(returning: nil); return }
        continuation = c
        lock.unlock()
        let w = Task.detached(priority: .userInitiated) { [self] in finish(try? await work()) }
        lock.lock()
        if finished { lock.unlock(); w.cancel() } else { worker = w; lock.unlock() }
        Task.detached { [self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0.1, seconds) * 1_000_000_000))
            finish(nil)
        }
    }

    func finish(_ value: T?) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let c = continuation, w = worker
        continuation = nil
        worker = nil
        lock.unlock()
        if value == nil { w?.cancel() }
        c?.resume(returning: value)
    }
}
