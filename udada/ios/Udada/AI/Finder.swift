import Foundation

// 말로 찾기: "다음 주에 병원 언제였지", "지난주에 끝낸 운동 몇 번" 같은 물음에 답한다.
// 모델(Apple Intelligence)은 물음을 '무엇을 · 언제 · 어떤 것'으로 **읽기만** 하고, 답은 규칙이 내 데이터에서 찾는다.
// 그래서 답에 나오는 일·날짜·개수는 전부 실제 기록이다 — 모델이 지어낼 자리가 없다 (design/AI.md 의 원칙 그대로).
// 모델이 없거나 늦으면 FindRules.read 가 같은 모양의 물음을 낱말 규칙으로 읽는다.

/// 읽어 낸 물음
struct FindQuery: Equatable, Sendable {
    enum Span: String, CaseIterable, Sendable { case any, today, tomorrow, yesterday, thisWeek, nextWeek, lastWeek, thisMonth, lastMonth, upcoming, past }
    enum State: String, CaseIterable, Sendable { case any, open, done }
    enum Kind: String, CaseIterable, Sendable { case any, event, todo, worry, later }

    /// 제목에 들어 있어야 할 낱말 (물음에서 그대로 베낀 것만)
    var words: [String] = []
    var span: Span = .any
    var state: State = .any
    var kind: Kind = .any
    /// "몇 번 · 몇 개"를 물었나 (답 첫 줄을 개수로)
    var counting = false
    /// 모델이 읽었나 (화면의 Apple Intelligence 표시)
    var fromAI = false
}

/// 찾은 것 하나 — 전부 실제 기록에서 온다
struct FindHit: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var day: DayKey?
    var time: Int?
    var part: Part?
    var done: Bool
    var worry: Bool
    var repeating: Bool
    /// 낱말은 안 겹치지만 Apple Intelligence 가 뜻이 맞다고 고른 기록
    var byMeaning = false
}

struct FindAnswer: Equatable, Sendable {
    var query: FindQuery
    /// 규칙이 만든 한 줄 ("다음 주 · 병원 — 11월 18일 (수) 15:00")
    var line: String
    var hits: [FindHit]
}

enum FindRules {
    // MARK: 물음 읽기 (규칙)

    private static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
    private static func has(_ r: NSRegularExpression, _ s: String) -> Bool { r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }

    private static let spans: [(NSRegularExpression, FindQuery.Span)] = [
        (rx(#"다음\s*주|담주|내주"#), .nextWeek), (rx(#"지난\s*주|저번\s*주"#), .lastWeek), (rx(#"이번\s*주|금주"#), .thisWeek),
        (rx(#"지난\s*달|저번\s*달"#), .lastMonth), (rx(#"이번\s*달|이달"#), .thisMonth),
        (rx(#"오늘"#), .today), (rx(#"내일"#), .tomorrow), (rx(#"어제"#), .yesterday),
        (rx(#"앞으로|다가오는|남은\s*(?:약속|일정)|예정"#), .upcoming), (rx(#"예전|그동안|지금까지|여태"#), .past),
    ]
    private static let doneWords = rx(#"끝낸|끝냈|완료|다\s*한|했던|했지|했어|했나|했더라|한\s*거|마친|몇\s*번\s*했"#)
    private static let openWords = rx(#"안\s*끝낸|못\s*끝낸|아직|남은|안\s*한|못\s*한|해야\s*(?:할|하는|되는|돼)|할\s*일|미룬|밀린"#)
    private static let countWords = rx(#"몇\s*(?:번|개|건|가지)|얼마나"#)
    private static let eventWords = rx(#"약속|일정|미팅|회의|예약|몇\s*시"#)
    private static let worryWords = rx(#"걱정|고민"#)
    private static let laterWords = rx(#"나중에|언젠가|미뤄\s*둔"#)
    private static let pastTense = rx(#"였지|였더라|였어|했지|했더라|갔지|갔더라|했었"#)

    /// 물음에서 빼고 남는 것이 찾을 낱말이다
    private static let stop = rx(#"넣어\s*(?:놨\S*|둔)|적어\s*(?:놨\S*|둔)|해\s*(?:놨\S*|둔)|미뤄\s*둔|하려고|관련해서|관련|다녀온|갔다\s*온|잡힌|있었던|같은데|샀던가|했던가|요즘|내가|것들|일들|해치운|며칠\S*|날짜|아직|화요일\S*|월요일\S*|수요일\S*|목요일\S*|금요일\S*|토요일\S*|일요일\S*|모레|이후로?|쯤|보자|다음\s*주|담주|내주|지난\s*주|저번\s*주|이번\s*주|금주|지난\s*달|저번\s*달|이번\s*달|이달|오늘|내일|어제|앞으로|다가오는|예전|그동안|지금까지|여태|언제(?:였지|였더라|야|지|더라)?|뭐(?:가|였지|야|지|있어|있지|있나|더라)?|무슨|어떤|몇\s*(?:번|개|건|가지|시)|얼마나|있어|있지|있나|있었지|있었나|없어|없나|했지|했어|했나|했더라|했던|했었지|끝낸|끝냈지|끝냈어|끝냈나|완료한?|마친|남은|안\s*한|못\s*한|해야\s*(?:할|하는|되는|돼)|할\s*일|약속|일정|걱정|고민|나중에|언젠가|찾아\s*줘|보여\s*줘|알려\s*줘|말해\s*줘|전부|모두|우다다|(?<![^\s])(?:것|거|게|좀|다)(?![^\s])|(?:에서|에는|이야|이지|이었지|에|은|는|이|가|을|를|도|만)(?![^\s])"#)
    /// 한 글자여도 찾는 낱말로 치는 이름씨 ("돈 나갈 일", "차 관련", "책 읽는 거")
    private static let short: Set<String> = ["돈", "차", "책", "물", "집", "약", "옷", "밥", "술", "빵", "방", "표", "빚", "짐", "꽃"]

    /// 낱말 규칙으로 읽는다. 모델이 읽은 것을 검사할 때의 기준이기도 하다.
    static func read(_ text: String) -> FindQuery {
        var q = FindQuery()
        // 풀어 쓴 한글(NFD — 실행 인자·일부 주소에서 온다)은 정규식에 안 걸린다 → 모아 쓴 꼴로
        let t = text.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        q.span = spans.first { has($0.0, t) }?.1 ?? .any
        q.counting = has(countWords, t)
        if has(openWords, t) { q.state = .open } else if has(doneWords, t) { q.state = .done }
        if has(worryWords, t) { q.kind = .worry } else if has(laterWords, t) { q.kind = .later } else if has(eventWords, t) { q.kind = .event }
        // 때를 안 말하고 지난 일처럼 물었으면 ("병원 언제였지") 지난 것에서
        if q.span == .any, has(pastTense, t) { q.span = .past }
        if q.kind == .worry || q.kind == .later { q.span = .any }
        q.words = words(in: t)
        return q
    }

    /// 물음에서 군말을 뺀 낱말 (조사를 뗀다). 최대 3개.
    static func words(in text: String) -> [String] {
        var s = text.precomposedStringWithCanonicalMapping.replacingOccurrences(of: #"[?？!.,·]"#, with: " ", options: .regularExpression)
        // 긴 군말부터 지운다
        for _ in 0..<2 {
            s = stop.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }
        var out: [String] = []
        for w in s.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
            let bare = w.replacingOccurrences(of: #"(?:에서|에는|한테|이랑|랑|으로|로|은|는|이|가|을|를|도|만|에)$"#, with: "", options: .regularExpression)
            if bare.count >= 2 || short.contains(bare), !out.contains(bare) { out.append(bare) }
        }
        return Array(out.prefix(3))
    }

    // MARK: 모델이 읽은 것 검사

    /// 모델의 읽기를 받아들일 만한가: 낱말은 물음에 실제로 있어야 하고, 규칙이 또렷이 읽은 때·상태는 규칙이 이긴다.
    static func checked(model: FindQuery, question: String) -> FindQuery {
        let question = question.precomposedStringWithCanonicalMapping
        let rule = read(question)
        var q = model
        let flat = question.filter { !$0.isWhitespace }
        // 물음에 실제로 있는 낱말만, 군말(언제·약속·이번 주 …)은 뺀다
        q.words = Array(model.words.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { w in (w.count >= 2 || short.contains(w)) && flat.contains(w.filter { !$0.isWhitespace }) && !words(in: w).isEmpty }
            .prefix(3))
        if q.words.isEmpty { q.words = rule.words }
        // 잘하는 칸만 쓴다 (Eval/find: 낱말은 모델 22/24 · 규칙 14/24, 종류는 모델 12/24 · 규칙 24/24)
        q.kind = rule.kind
        q.span = rule.span != .any ? rule.span : model.span
        q.state = rule.state != .any ? rule.state : (model.state == .done ? .done : .any)
        // 걱정 상자 · 나중에 함에는 날짜가 없다
        if q.kind == .worry || q.kind == .later { q.span = .any }
        q.counting = rule.counting
        q.fromAI = true
        return q
    }

    /// 모델이 베껴 온 이름 가운데 후보 목록에 **글자 그대로** 있는 것만. 너무 많이 고르면(후보의 절반 넘게 · 12개 넘게) 뜻을 못 가린 것이니 통째로 안 믿는다.
    static func trusted(_ picked: [String], titles: [String]) -> Set<String> {
        let byNorm = Dictionary(titles.map { (norm($0), $0) }, uniquingKeysWith: { a, _ in a })
        let ok = Set(picked.compactMap { byNorm[norm($0)] })
        guard ok.count <= 12, titles.count < 6 || ok.count * 2 <= titles.count else { return [] }
        return ok
    }

    // MARK: 찾기 (전부 실제 기록에서)

    static func range(_ span: FindQuery.Span, today: DayKey, mondayFirst: Bool = true, calendar: Calendar = .current) -> ClosedRange<DayKey>? {
        let week = today.startOfWeek(mondayFirst: mondayFirst, calendar: calendar)
        let monthStart = DayKey(y: today.y, m: today.m, d: 1)
        func monthEnd(_ k: DayKey) -> DayKey {
            let n = calendar.range(of: .day, in: .month, for: k.date(calendar: calendar))?.count ?? 30
            return DayKey(y: k.y, m: k.m, d: n)
        }
        switch span {
        case .any: return nil
        case .today: return today...today
        case .tomorrow: let t = today.adding(days: 1, calendar: calendar); return t...t
        case .yesterday: let y = today.adding(days: -1, calendar: calendar); return y...y
        case .thisWeek: return week...week.adding(days: 6, calendar: calendar)
        case .nextWeek: let w = week.adding(days: 7, calendar: calendar); return w...w.adding(days: 6, calendar: calendar)
        case .lastWeek: let w = week.adding(days: -7, calendar: calendar); return w...w.adding(days: 6, calendar: calendar)
        case .thisMonth: return monthStart...monthEnd(monthStart)
        case .lastMonth:
            let prev = monthStart.adding(days: -1, calendar: calendar)
            return DayKey(y: prev.y, m: prev.m, d: 1)...prev
        case .upcoming: return today...today.adding(days: 60, calendar: calendar)
        case .past: return today.adding(days: -180, calendar: calendar)...today.adding(days: -1, calendar: calendar)
        }
    }

    private static func norm(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil).filter { !$0.isWhitespace }
    }

    /// 뜻으로 찾기의 후보: 때·상태·종류는 물음에 맞는데 낱말이 안 겹친 기록의 이름 (같은 이름은 한 번, 가까운 날부터, 80개까지).
    /// 모델은 이 목록의 번호만 고른다 — 고를 수 있는 것이 실제 기록뿐이라 지어낼 자리가 없다. 위기 글은 모델에 안 보낸다.
    static func candidates(_ q: FindQuery, data: AppData, today: DayKey, calendar: Calendar = .current) -> [String] {
        guard !q.words.isEmpty else { return [] }
        var all = q
        all.words = []
        let found = Set(hits(q, data: data, today: today, calendar: calendar).map(\.title))
        var out: [String] = []
        for h in hits(all, data: data, today: today, calendar: calendar)
        where !found.contains(h.title) && !out.contains(h.title) && !BrainRules.isCrisis(h.title) {
            out.append(h.title)
            if out.count == 80 { break }
        }
        return out
    }

    /// meaning: 모델이 뜻으로 고른 이름들 (candidates 에서 온 것만). 낱말이 맞은 것 뒤에 놓는다.
    static func hits(_ q: FindQuery, data: AppData, today: DayKey, calendar: Calendar = .current, meaning: Set<String> = []) -> [FindHit] {
        let range = self.range(q.span, today: today, mondayFirst: data.settings.mondayFirst, calendar: calendar)
        let words = q.words.map(norm)
        func literal(_ title: String) -> Bool {
            let t = norm(title)
            // 한 글자 낱말(돈·차·책)은 이름 속 한 마디와 같을 때만 ("차"가 "자동차"·"기차표"에 걸리지 않게)
            let tokens = title.split(whereSeparator: { $0.isWhitespace }).map { norm(String($0)).replacingOccurrences(of: #"(?:은|는|이|가|을|를|도|만|에)$"#, with: "", options: .regularExpression) }
            // 두세 글자 낱말은 이름의 한 마디 안에 있어야 한다 — 띄어쓰기를 지운 글에서 찾으면 "제주"가 "영양제 주문"에 걸린다. 긴 낱말만 띄어쓰기를 넘어 찾는다 (건강검진 ↔ 건강 검진).
            func has(_ w: String) -> Bool { w.count < 2 ? tokens.contains(w) : tokens.contains { $0.contains(w) } || (w.count >= 4 && t.contains(w)) }
            return words.isEmpty || words.allSatisfy(has) || (words.count > 1 && words.contains(where: has))
        }
        func matches(_ title: String) -> Bool { literal(title) || meaning.contains(title) }
        var out: [FindHit] = []
        for it in data.items where matches(it.title) {
            if it.worry {
                guard q.kind == .worry || (q.kind == .any && range == nil && !words.isEmpty), q.state != .done || it.done else { continue }
                out.append(FindHit(id: it.id.uuidString, title: it.title, day: nil, time: nil, part: nil, done: it.done, worry: true, repeating: false))
                continue
            }
            guard q.kind != .worry else { continue }
            if let rule = it.repeatRule {
                // 반복은 범위 안의 날로 펼친다 (범위가 없으면 다음 한 번만)
                guard q.kind != .later, q.state != .done, let start = it.day else { continue }
                if q.kind == .event, it.time == nil { continue }
                if q.kind == .todo, it.time != nil { continue }
                let r = range ?? today...today.adding(days: 30, calendar: calendar)
                var d = max(r.lowerBound, start), n = 0
                while d <= r.upperBound, n < (range == nil ? 1 : 31) {
                    if !it.exceptions.contains(d), rule.matches(d, start: start, calendar: calendar) {
                        out.append(FindHit(id: it.id.uuidString + "@" + d.description, title: it.title, day: d, time: it.time, part: it.part,
                                           done: false, worry: false, repeating: true))
                        n += 1
                    }
                    d = d.adding(days: 1, calendar: calendar)
                }
                continue
            }
            guard let day = it.day else {
                // 나중에 함
                guard q.kind == .later || (q.kind == .any && range == nil), q.state != .done || it.done else { continue }
                out.append(FindHit(id: it.id.uuidString, title: it.title, day: nil, time: nil, part: nil, done: it.done, worry: false, repeating: false))
                continue
            }
            guard q.kind != .later else { continue }
            if let range, !range.contains(day) { continue }
            if q.kind == .event, it.time == nil { continue }
            if q.kind == .todo, it.time != nil { continue }
            if q.state == .done, !it.done { continue }
            if q.state == .open, it.done { continue }
            out.append(FindHit(id: it.id.uuidString, title: it.title, day: day, time: it.time, part: it.part, done: it.done, worry: false,
                               repeating: it.seriesID != nil))
        }
        // 앞으로의 것은 가까운 날부터, 지난 것은 최근부터. 날 없는 것은 맨 뒤.
        let past = q.span == .past || q.span == .lastWeek || q.span == .lastMonth || q.span == .yesterday
        if !meaning.isEmpty { for i in out.indices { out[i].byMeaning = !literal(out[i].title) } }
        return out.sorted { a, b in
            if a.byMeaning != b.byMeaning { return !a.byMeaning }
            switch (a.day, b.day) {
            case (nil, nil): return a.title < b.title
            case (nil, _): return false
            case (_, nil): return true
            case let (x?, y?):
                if x != y { return past ? x > y : x < y }
                return (a.time ?? 1440, a.title) < (b.time ?? 1440, b.title)
            }
        }
    }

    // MARK: 답 한 줄 (규칙)

    static func spanName(_ s: FindQuery.Span) -> String {
        switch s {
        case .any: ""
        case .today: "오늘"
        case .tomorrow: "내일"
        case .yesterday: "어제"
        case .thisWeek: "이번 주"
        case .nextWeek: "다음 주"
        case .lastWeek: "지난주"
        case .thisMonth: "이번 달"
        case .lastMonth: "지난달"
        case .upcoming: "앞으로"
        case .past: "지난"
        }
    }

    static func when(_ h: FindHit, today: DayKey) -> String {
        if h.worry { return "걱정 상자" }
        guard let d = h.day else { return "나중에 함" }
        return Fmt.day(d, today: today) + " " + (h.time.map(Fmt.hm) ?? h.part?.name ?? "")
    }

    /// 낱말로는 못 찾았고 뜻으로 더 찾는 중일 때의 한 줄 — '찾은 게 없어'를 먼저 말했다가 뒤집지 않게
    static func searching(_ a: FindAnswer) -> String {
        (a.line.components(separatedBy: " — ").first ?? "") + " — 낱말은 없어서 뜻으로 찾는 중"
    }

    static func answer(_ q: FindQuery, data: AppData, today: DayKey, calendar: Calendar = .current, meaning: Set<String> = []) -> FindAnswer {
        let hits = self.hits(q, data: data, today: today, calendar: calendar, meaning: meaning)
        var what: [String] = []
        if q.span != .any { what.append(spanName(q.span)) }
        if !q.words.isEmpty { what.append("‘" + q.words.joined(separator: " ") + "’") }
        switch q.kind {
        case .event: what.append("약속")
        case .todo: what.append("할 일")
        case .worry: what.append("걱정")
        case .later: what.append("나중에 함")
        case .any: break
        }
        if q.state == .done { what.append("끝낸 것") } else if q.state == .open { what.append("남은 것") }
        let head = what.isEmpty ? "전체" : what.joined(separator: " · ")
        let line: String
        if hits.isEmpty {
            line = "\(head) — 찾은 게 없어"
        } else if q.counting || hits.count > 1 {
            let done = hits.filter(\.done).count
            line = "\(head) — \(hits.count)개" + (q.state == .any && done > 0 ? " (끝낸 것 \(done)개)" : "")
        } else if hits[0].byMeaning {
            // 이름이 물음의 낱말과 다르니 무엇을 찾았는지도 말한다
            line = "\(head) — ‘\(hits[0].title)’ \(when(hits[0], today: today).trimmingCharacters(in: .whitespaces))"
        } else {
            line = "\(head) — \(when(hits[0], today: today).trimmingCharacters(in: .whitespaces))"
        }
        return FindAnswer(query: q, line: line, hits: Array(hits.prefix(40)))
    }
}
