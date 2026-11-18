import Foundation

// 말로 시키기: "치과 내일로 미루고 보고서는 끝냈어, 금요일 3시에 미팅 추가해" — 한 문장으로 여러 일을 바꾼다.
// 지금까지 배운 대로 짰다 (design/AI.md 11–12절):
//  · 뼈대는 규칙이 자른 조각이다 → 말한 것을 하나도 잃지 않는다.
//  · 모델(Apple Intelligence)은 조각마다 '무슨 동작인지 · 어느 일을 가리키는지'를 읽기만 한다.
//  · 가리킨 일은 실제 기록에서 찾고, 날짜·시각은 Parser 가 읽는다. 못 찾으면 '못 찾음'으로 보여 주고 아무것도 안 한다.
//  · 아무것도 바로 바꾸지 않는다: 계획(CommandPlan)을 먼저 보여 주고, 사용자가 누르면 한 번에 적용한다 (되돌리기 한 번).

struct CommandStep: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable { case add, done, move, delete }
    var id = UUID()
    var kind: Kind
    /// 사용자가 말한 조각 그대로
    var said: String
    /// 가리킨 실제 항목 (add 는 nil). 못 찾았으면 nil 이고 ok == false.
    var target: CommandTarget?
    /// move: 옮길 곳 (day == nil && later 면 나중에 함)
    var day: DayKey? = nil
    var part: Part? = nil
    var time: Int? = nil
    var later = false
    /// add: 넣을 한 줄 (Parser 가 다시 읽는다)
    var line: String = ""
    /// 이 조각의 동작을 모델이 읽었나
    var fromAI = false

    var ok: Bool { kind == .add ? !line.isEmpty : target != nil }

    static func == (a: CommandStep, b: CommandStep) -> Bool {
        a.kind == b.kind && a.said == b.said && a.target == b.target && a.day == b.day && a.part == b.part && a.time == b.time && a.later == b.later && a.line == b.line
    }
}

/// 가리킬 수 있는 실제 항목 하나
struct CommandTarget: Equatable, Sendable {
    var source: Entry.Source
    var title: String
    var day: DayKey?
    var time: Int?
}

struct CommandPlan: Equatable, Sendable {
    var steps: [CommandStep]
    var fromAI: Bool { steps.contains(where: \.fromAI) }
    var doable: [CommandStep] { steps.filter(\.ok) }
}

/// 모델이 조각 하나에 대해 읽은 것 (검사 전)
struct CommandReading: Sendable {
    var kind: CommandStep.Kind
    /// 가리키는 일의 이름 낱말 (조각에서 베낀 것)
    var target: String
}

enum CommandRules {
    private static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
    private static func has(_ r: NSRegularExpression, _ s: String) -> Bool { r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }
    private static func strip(_ r: NSRegularExpression, _ s: String) -> String {
        r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
    }

    // 동작을 또렷이 말한 낱말
    private static let deleteCue = rx(#"지워|지우|삭제|없애|취소(?:해|됐|됨|할)|취소$|빼\s*줘|빼\s*버려|안\s*해도\s*(?:돼|될)|안\s*할\s*(?:래|거)|필요\s*없"#)
    private static let moveCue = rx(#"미뤄|미루|옮겨|옮기|연기|당겨|바꿔|변경|(?:내일|모레|글피|요일|주말|\d\s*일|\d\s*시|\d\s*분|아침|낮|저녁|오전|오후|주)(?:으)?로\s*(?:해\s*줘|하자|할게|해)"#)
    private static let doneCue = rx(#"끝냈|끝났|끝남|완료|다\s*했|마쳤|해치웠|다녀왔|다녀온|갔다\s*왔|갔다\s*온|하고\s*왔|체크해|끝난\s*걸로|한\s*걸로|했어[.!]?$|했음[.!]?$|했다[.!]?$|보냈어[.!]?$|냈어[.!]?$|샀어[.!]?$|왔어[.!]?$|됐어[.!]?$"#)
    private static let addCue = rx(#"추가|넣어|적어|잡아\s*줘|등록|만들어"#)
    /// 건드리지 말라는 말 ("저녁 약속은 그대로 둬") — 계획에서 뺀다
    private static let keepCue = rx(#"그대로|놔\s*둬|냅둬|내버려|유지|건드리지"#)
    /// 물음이면 시키기가 아니라 찾기다
    private static let question = rx(#"\?|뭐|뭘|무슨|어느|언제|몇\s*(?:시|번|개)|뭐\s*(?:있|해|였|지|더라)|있어$|있나$|있지$|보여\s*줘|알려\s*줘|찾아\s*줘|했더라|였지|였더라"#)

    /// 이름을 찾을 때 빼는 말 (동작 · 때 · 군말)
    private static let noise = rx(#"지워\s*줘?|지우기|삭제\s*해?\s*줘?|없애\s*줘?|취소\s*해?\s*줘?|빼\s*줘|미뤄\s*줘?|미루기|미루고|옮겨\s*줘?|옮기고|연기\s*해?\s*줘?|당겨\s*줘?|바꿔\s*줘?|변경\s*해?\s*줘?|끝냈어?|끝났어?|완료\s*했?어?|다\s*했어?|마쳤어?|해치웠어?|다녀왔어?|갔다\s*왔어?|체크\s*해?\s*줘?|추가\s*해?\s*줘?|넣어\s*줘?|적어\s*줘?|잡아\s*줘|등록\s*해?\s*줘?|해\s*줘|했어|했음|안\s*할래|안\s*해도\s*돼|그냥|둘\s*다|전부|모두|이미|대신|그리고|이랑|하고|은|는|이|가|을|를|도|좀|것|거|일정|약속|할\s*일"#)

    static func isQuestion(_ text: String) -> Bool { has(question, text.precomposedStringWithCanonicalMapping) }

    /// 시키는 말로 볼 만한가 (기존 일을 건드리는 동작 낱말이 있다). 아니면 그냥 넣기다.
    static func looksLikeCommand(_ text: String) -> Bool {
        let t = text.precomposedStringWithCanonicalMapping
        return !isQuestion(t) && (has(deleteCue, t) || has(moveCue, t) || has(doneCue, t))
    }

    // MARK: 가리킬 수 있는 항목

    /// 건드릴 수 있는 열린 일: 어제~30일 뒤와 나중에 함, 그리고 오늘·내일의 반복 하루치. 가까운 날이 앞.
    static func candidates(_ data: AppData, today: DayKey, calendar: Calendar = .current) -> [CommandTarget] {
        var out: [CommandTarget] = []
        let lo = today.adding(days: -1, calendar: calendar), hi = today.adding(days: 30, calendar: calendar)
        for it in data.items where !it.done && !it.worry {
            if let rule = it.repeatRule {
                guard let start = it.day else { continue }
                for d in [today, today.adding(days: 1, calendar: calendar)] where !it.exceptions.contains(d) && rule.matches(d, start: start, calendar: calendar) {
                    out.append(CommandTarget(source: .occurrence(series: it.id, day: d), title: it.title, day: d, time: it.time))
                }
            } else if let d = it.day {
                if d >= lo && d <= hi { out.append(CommandTarget(source: .item(it.id), title: it.title, day: d, time: it.time)) }
            } else {
                out.append(CommandTarget(source: .item(it.id), title: it.title, day: nil, time: nil))
            }
        }
        return out.sorted { a, b in
            let da = a.day.map { abs(today.days(to: $0, calendar: calendar)) } ?? 1000
            let db = b.day.map { abs(today.days(to: $0, calendar: calendar)) } ?? 1000
            return (da, a.title) < (db, b.title)
        }
    }

    private static func norm(_ s: String) -> String {
        s.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil).filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    /// 조각(또는 모델이 베낀 이름)이 가리키는 항목. 이름이 통째로 들어 있으면 가장 긴 이름이, 아니면 낱말이 가장 많이 겹치는 것이 이긴다.
    static func resolve(_ words: String, in candidates: [CommandTarget], preferDay: DayKey? = nil) -> CommandTarget? {
        let flat = norm(words)
        guard flat.count >= 2 else { return nil }
        // 1) 이름 전체가 말 속에 있다
        let whole = candidates.filter { let t = norm($0.title); return t.count >= 2 && flat.contains(t) }
        if let best = pick(whole.sorted { norm($0.title).count > norm($1.title).count }, preferDay: preferDay) { return best }
        // 2) 말에서 때 낱말과 군말을 뺀 낱말이 이름 속에 있다 ("오늘 저녁으로 당겨 줘"의 '저녁'이 '저녁 약속'을 가리키지 않게)
        let named = Parser.parse(untagWhen(words.precomposedStringWithCanonicalMapping)).title
        let tokens = strip(noise, named).split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map { norm(String($0)) }.filter { $0.count >= 2 }
        guard !tokens.isEmpty else { return nil }
        var scored: [(CommandTarget, Int)] = []
        for c in candidates {
            let t = norm(c.title)
            let hit = tokens.filter { t.contains($0) }.reduce(0) { $0 + $1.count }
            if hit >= 2 { scored.append((c, hit)) }
        }
        guard let top = scored.map(\.1).max() else { return nil }
        return pick(scored.filter { $0.1 == top }.map(\.0), preferDay: preferDay)
    }

    /// 조각에 이름이 통째로 든 항목들 (같은 이름은 가까운 것 하나). "택배 보내기랑 빨래 개기 둘 다 끝냈어" → 둘.
    static func wholeMatches(_ words: String, in candidates: [CommandTarget]) -> [CommandTarget] {
        let flat = norm(words)
        var seen = Set<String>(), out: [CommandTarget] = []
        for c in candidates {
            let t = norm(c.title)
            guard t.count >= 2, flat.contains(t), seen.insert(t).inserted else { continue }
            out.append(c)
        }
        // 짧은 이름이 긴 이름의 일부면 긴 것만 ("치과"와 "치과 예약")
        return out.filter { a in !out.contains { b in norm(b.title).count > norm(a.title).count && norm(b.title).contains(norm(a.title)) } }
    }

    private static func pick(_ list: [CommandTarget], preferDay: DayKey?) -> CommandTarget? {
        guard let first = list.first else { return nil }
        // 같은 이름이 여러 날에 있으면 말한 날의 것, 아니면 가장 가까운 것 (candidates 가 가까운 순)
        let same = list.filter { norm($0.title) == norm(first.title) }
        if let d = preferDay, let onDay = same.first(where: { $0.day == d }) { return onDay }
        return first
    }

    // MARK: 한 조각 읽기 (규칙)

    static func ruleKind(_ piece: String) -> CommandStep.Kind? {
        if has(deleteCue, piece) { return .delete }
        if has(moveCue, piece) { return .move }
        if has(doneCue, piece) && !has(addCue, piece) { return .done }
        if has(addCue, piece) { return .add }
        return nil
    }

    /// Parser 는 "내일로 · 4시로 · 수요일로"의 '로'를 못 읽는다 → 때 낱말 뒤의 '(으)로'를 뗀다
    static func untagWhen(_ s: String) -> String {
        s.replacingOccurrences(of: #"((?:오늘|내일|모레|글피|요일|주말|다음\s*주|이번\s*주|\d\s*일|\d\s*시|\d\s*분|반|아침|낮|저녁|밤|오전|오후))(?:으로|로)(?=\s|$)"#, with: "$1", options: .regularExpression)
    }

    /// 옮길 곳: '(으)로'가 붙은 때 낱말과 그 앞에 이어진 때 낱말만 읽는다.
    /// "오늘 치과 못 갈 것 같아 수요일 오전 11시로 바꿔 줘" → "수요일 오전 11시" (앞의 '오늘'은 옮길 곳이 아니다)
    static func destination(_ piece: String, now: Date, parts: DayParts, calendar: Calendar) -> Parsed? {
        let words = piece.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let end = words.lastIndex(where: { untagWhen($0) != $0 }) else { return nil }
        var start = end
        let whenish = rx(#"요일|오늘|내일|모레|글피|주말|^다음$|^이번$|^주$|주$|오전|오후|아침|낮|저녁|밤|\d"#)
        while start > 0, has(whenish, words[start - 1]) { start -= 1 }
        let phrase = untagWhen(words[start...end].joined(separator: " "))
        let p = Parser.parse(phrase, now: now, parts: parts, calendar: calendar)
        return p.day != nil || p.time != nil || p.part != nil || p.later ? p : nil
    }

    /// 조각 하나 → 계획의 한 줄. reading 은 모델이 읽은 것 (없으면 규칙만).
    static func step(_ piece: String, reading: CommandReading?, candidates: [CommandTarget], now: Date, parts: DayParts, calendar: Calendar = .current) -> CommandStep {
        let today = DayKey(now, calendar: calendar)
        let parsed = destination(piece, now: now, parts: parts, calendar: calendar) ?? Parser.parse(untagWhen(piece), now: now, parts: parts, calendar: calendar)
        let cue = ruleKind(piece)
        // "메일 답장은 내일로" · "여권 갱신 금요일로 잡아 줘" — 이미 있는 일에 때를 '(으)로' 붙여 말하면 옮기기다
        let hasWhen = parsed.day != nil || parsed.time != nil || parsed.part != nil || parsed.later
        let toWhen = piece != untagWhen(piece)
        let implicitMove = (cue == nil || (cue == .add && has(rx(#"잡아"#), piece))) && hasWhen && toWhen && !wholeMatches(piece, in: candidates).isEmpty
        let rule: CommandStep.Kind? = implicitMove ? .move : cue
        // 또렷이 말한 동작은 규칙이, 아니면 모델이 읽은 것. 둘 다 없으면 넣기.
        var kind = rule ?? reading?.kind ?? .add
        var usedAI = rule == nil && reading != nil && reading?.kind != .add
        // 가리킨 일: 조각 전체로 먼저, 안 되면 모델이 베낀 이름으로
        var target = kind == .add ? nil : resolve(piece, in: candidates)
        if kind != .add, target == nil, let t = reading?.target, !t.isEmpty, norm(piece).contains(norm(t)) {
            target = resolve(t, in: candidates)
            if target != nil { usedAI = true }
        }
        // 동작 낱말 없이 모델만 '끝냄·지우기'라 했는데 가리킨 일이 없으면 넣기로 (없는 일을 지어 고치지 않는다)
        if kind != .add, target == nil, rule == nil { kind = .add; usedAI = false }
        var s = CommandStep(kind: kind, said: piece, target: target, fromAI: usedAI)
        switch kind {
        case .add:
            // 동작 낱말(추가해 줘)은 빼고 넣는다
            s.line = BrainRules.tidy(strip(rx(#"(?:을|를)?\s*(?:추가|등록)\s*(?:하기|해\s*줘|해|줘)?[.!]?$|(?:을|를)?\s*넣기[.!]?$|(?:을|를)?\s*(?:넣어|적어|잡아)\s*줘?[.!]?$|(?:을|를)?\s*만들어\s*줘?[.!]?$"#), piece))
        case .move:
            if parsed.later || (parsed.day == nil && parsed.time == nil && parsed.part == nil && has(rx(#"나중|언젠가"#), piece)) {
                s.later = true
            } else if let d = parsed.day {
                s.day = d; s.part = parsed.part; s.time = parsed.time
            } else if parsed.time != nil || parsed.part != nil {
                // 날은 그대로, 시각·띠만
                s.day = target?.day ?? today; s.part = parsed.part; s.time = parsed.time
            } else {
                // "미뤄 줘"만 말하면 내일 아침
                s.day = (target?.day ?? today).adding(days: 1, calendar: calendar); s.part = .morning
            }
        case .done, .delete:
            break
        }
        return s
    }

    /// 문장 → 계획. readings 는 조각과 같은 순서 (모델이 못 읽었으면 nil).
    static func plan(_ text: String, readings: [CommandReading?]? = nil, data: AppData, now: Date, calendar: Calendar = .current) -> CommandPlan {
        let pieces = self.pieces(text)
        let cands = candidates(data, today: DayKey(now, calendar: calendar), calendar: calendar)
        var used: [Entry.Source] = []
        var steps: [CommandStep] = []
        for (i, p) in pieces.enumerated() {
            // "…은 그대로 둬"는 아무것도 하지 말라는 말이다
            if has(keepCue, p) { continue }
            let r = readings.flatMap { i < $0.count ? $0[i] : nil }
            // 한 문장에서 같은 일을 두 번 가리키지 않는다
            let free = cands.filter { !used.contains($0.source) }
            let s = step(p, reading: r, candidates: free, now: now, parts: data.settings.parts, calendar: calendar)
            // 한 조각이 여러 일을 가리키면 ("택배 보내기랑 빨래 개기 둘 다 끝냈어") 일마다 한 줄
            let many = s.kind == .add ? [] : wholeMatches(p, in: free)
            if many.count >= 2 {
                for t in many { var one = s; one.id = UUID(); one.target = t; steps.append(one); used.append(t.source) }
                continue
            }
            if let t = s.target { used.append(t.source) }
            steps.append(s)
        }
        return CommandPlan(steps: steps)
    }

    /// 시키는 말은 쉼표·'~고'·그리고 에서 끊는다. BrainRules.split 이 '했고 → 했어'처럼 끝을 맺어 준다.
    static func pieces(_ text: String) -> [String] {
        let t = text.precomposedStringWithCanonicalMapping.replacingOccurrences(of: #"[,，、]\s*"#, with: "\n", options: .regularExpression)
        // 동작 낱말만 남은 조각("지워 줘")은 앞 조각에 다시 붙인다 — 쏟아내기용 자르기는 "장보기 | 지워 줘"로 끊는다
        var out: [String] = []
        for p in BrainRules.split(t) {
            let rest = strip(noise, Parser.parse(untagWhen(p)).title).filter { !$0.isWhitespace && !$0.isPunctuation }
            if rest.count < 2, let last = out.popLast() { out.append(last + " " + p) } else { out.append(p) }
        }
        return out
    }

    // MARK: 적용 (사용자가 누른 뒤에만)

    /// 계획을 데이터에 적용한다. 넣을 항목은 make 가 만든다 (앱의 '한 줄 넣기'와 같은 규칙).
    static func apply(_ steps: [CommandStep], to data: inout AppData, now: Date, make: (String) -> Item?) -> Int {
        var n = 0
        for s in steps where s.ok {
            switch s.kind {
            case .add:
                if let it = make(s.line) { data.add(it); n += 1 }
            case .done:
                if let t = s.target { data.setDone(t.source, true, now: now); n += 1 }
            case .delete:
                if let t = s.target { data.remove(t.source); n += 1 }
            case .move:
                guard let t = s.target, let id = data.materialize(t.source) else { continue }
                if s.later {
                    data.move(.item(id), to: nil)
                } else {
                    data.move(.item(id), to: s.day, part: s.part)
                    if let time = s.time {
                        let p = data.settings.parts.part(at: time)
                        data.update(id) { $0.time = time; $0.part = p }
                    }
                }
                n += 1
            }
        }
        return n
    }

    // MARK: 한 줄로 말하기 (화면·Siri 가 같이 쓴다)

    /// "‘치과’ → 내일 아침" · "‘보고서 초안’ 끝냄" · "넣기: 금요일 3시 미팅" · "‘수영’ — 못 찾았어"
    static func describe(_ s: CommandStep, today: DayKey) -> String {
        // 못 찾았을 때는 말한 조각에서 동작 낱말을 뺀 이름으로 보여 준다 ("수영 강습은 취소해 줘" → ‘수영 강습’)
        let spoken = BrainRules.tidy(strip(noise, s.said))
        let name = s.target.map { "‘\($0.title)’" } ?? "‘\(spoken.isEmpty ? s.said : spoken)’"
        guard s.ok else { return "\(name) — 그런 일을 못 찾았어" }
        switch s.kind {
        case .add: return "넣기: \(s.line)"
        case .done: return "\(name) 끝냄"
        case .delete: return "\(name) 지우기"
        case .move:
            if s.later { return "\(name) → 나중에 함" }
            let slot = s.time.map(Fmt.hm) ?? s.part?.name ?? ""
            return "\(name) → \(Fmt.day(s.day, today: today))" + (slot.isEmpty ? "" : " " + slot)
        }
    }
}
