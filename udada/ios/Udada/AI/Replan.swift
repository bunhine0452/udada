import Foundation

// 한 주 풀기: "이번 주 너무 빡빡해" → 넘치는 칸의 할 일을 빈 칸으로 옮기는 안.
// 모델은 도구로 한 주를 직접 보고(BrainPrompts 의 seeWeek · seeTodos) 무엇을 어디로 옮길지 고른다.
// 여기 있는 규칙은 ① 한 주의 짐을 사실대로 펼치고 ② 모델의 안을 실제 기록·빈 시간에 대어 검사하고 ③ 모델이 없거나 틀렸을 때 같은 모양의 안을 낸다.
// 아무것도 바로 바꾸지 않는다 — 화면이 안을 보여 주고 사용자가 눌러야 옮긴다. Foundation 만 쓴다 (Mac 테스트가 그대로 돌린다).

/// 하루의 한 칸: 빈 시간과 넣은 일
struct ReplanCell: Hashable, Sendable {
    var day: DayKey
    var part: Part
    /// 약속을 뺀 빈 시간 (오늘이면 지금부터)
    var free: Int
    /// 안 끝낸 할 일 길이 합
    var planned: Int
    var gone: Bool
    /// 넘치는 시간. 이미 지난 칸은 세지 않는다 (거기 남은 일은 하루 닫기가 다룬다)
    var overflow: Int { gone ? 0 : max(0, planned - free) }
    var room: Int { gone ? 0 : max(0, free - planned) }
}

/// 옮길 수 있는 할 일 하나. n 은 모델과 주고받는 번호다 (이름을 베끼게 하지 않고 번호로 가리킨다).
struct ReplanTodo: Hashable, Sendable, Identifiable {
    var n: Int
    var entry: Entry
    /// 지금까지 넘어온 횟수
    var moves: Int
    var id: String { entry.id }
}

/// 앞으로 7일의 사실
struct ReplanSnapshot: Sendable {
    var today: DayKey
    var days: [DayKey]
    var cells: [ReplanCell]
    var todos: [ReplanTodo]

    func cell(_ day: DayKey, _ part: Part) -> ReplanCell? { cells.first { $0.day == day && $0.part == part } }
    var overflow: Int { cells.reduce(0) { $0 + $1.overflow } }

    /// "오늘(수 18일)" · "내일(목 19일)" · "금 20일"
    func label(_ d: DayKey) -> String {
        let base = "\(Fmt.weekday[d.weekday()]) \(d.d)일"
        switch today.days(to: d) {
        case 0: return "오늘(\(base))"
        case 1: return "내일(\(base))"
        default: return base
        }
    }

    /// 사람이 읽는 짧은 이름: "오늘 낮" · "목 저녁"
    func short(_ d: DayKey, _ p: Part) -> String {
        let day: String
        switch today.days(to: d) {
        case 0: day = "오늘"
        case 1: day = "내일"
        default: day = Fmt.weekday[d.weekday()] + "요일"
        }
        return day + " " + p.name
    }

    /// 모델·사용자가 말한 날 낱말 → 이 한 주의 날. "오늘" · "내일" · "모레" · "목" · "목요일" · "20일"
    func day(named raw: String) -> DayKey? {
        let s = raw.precomposedStringWithCanonicalMapping
        if s.contains("오늘") { return today }
        if s.contains("내일") { return days.first { today.days(to: $0) == 1 } }
        if s.contains("모레") { return days.first { today.days(to: $0) == 2 } }
        if let m = s.range(of: #"(\d{1,2})일"#, options: .regularExpression), let n = Int(s[m].dropLast()) {
            if let hit = days.first(where: { $0.d == n }) { return hit }
        }
        for d in days.dropFirst() where s.contains(Fmt.weekday[d.weekday()] + "요일") { return d }
        // 한 글자 요일은 맨 앞에 있을 때만 ("목", "목 20일") — "일"은 날짜의 '일'과 헷갈리니 '요일'이 붙었을 때만
        if let first = s.first, first != "일" { return days.first { Fmt.weekday[$0.weekday()] == String(first) } }
        return nil
    }
}

/// 사용자가 한 말에서 읽은 것
struct ReplanAsk: Hashable, Sendable {
    /// 덜어 낼 날 (비어 있으면 한 주에서 넘치는 칸 전부)
    var focus: [DayKey] = []
    /// "비워 줘": 그날의 옮길 수 있는 일을 전부 다른 날로
    var clear = false
    /// 건드리지 말라고 한 일의 번호
    var keep: Set<Int> = []
}

/// 옮길 안 하나
struct ReplanMove: Identifiable, Hashable, Sendable {
    var todo: ReplanTodo
    var day: DayKey
    var part: Part
    var why: String
    var fromAI: Bool
    /// 모델이 그 자리에서 해야 한다고 본 일이라, 꺼 둔 채로만 보여 주는 옮김 (사용자가 켜면 옮긴다)
    var optional = false
    var id: String { todo.id }
}

/// 보는 과정 한 줄 (화면이 차례로 보여 준다)
struct ReplanTrace: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable { case week, todos, plan, note }
    var id = UUID()
    var kind: Kind
    var text: String
    /// 모델이 도구를 불러서 본 것인가
    var fromAI = false
}

struct ReplanResult: Sendable {
    var snapshot: ReplanSnapshot
    var ask: ReplanAsk
    var moves: [ReplanMove]
    var fromAI: Bool
    /// 모델이 도구를 부른 횟수 (0 이면 규칙만)
    var toolCalls = 0
    /// 모델이 낸 안 그대로 (검사 전 — 평가에서 무엇이 왜 떨어졌는지 본다)
    var proposed: [String] = []

    /// 처음에 켜 둘 옮김 (꺼 둔 선택지는 뺀다)
    var defaults: Set<String> { Set(moves.filter { !$0.optional }.map(\.id)) }

    func after(_ chosen: Set<String>? = nil) -> [ReplanCell] {
        let on = chosen ?? defaults
        return ReplanRules.apply(moves.filter { on.contains($0.id) }, to: snapshot.cells)
    }
}

enum ReplanRules {
    // MARK: 사실 펼치기

    /// 오늘부터 7일: 칸마다 빈 시간·넣은 일, 그리고 옮길 수 있는 할 일(안 끝냄 · 반복 아님)에 번호를 붙인다
    static func snapshot(data: AppData, external: [Entry] = [], now: Date, calendar: Calendar = .current) -> ReplanSnapshot {
        let today = DayKey(now, calendar: calendar)
        let days = (0..<7).map { today.adding(days: $0, calendar: calendar) }
        var cells: [ReplanCell] = []
        var todos: [ReplanTodo] = []
        let moved = Dictionary(data.items.map { ($0.id, $0.moves) }, uniquingKeysWith: { a, _ in a })
        for d in days {
            let sheet = DayLogic.sheet(for: d, data: data, external: external, now: now, calendar: calendar)
            for b in sheet.bands {
                cells.append(ReplanCell(day: d, part: b.part, free: b.free, planned: b.planned, gone: b.gone))
                for e in b.todos where !e.done && !e.repeating && !e.isExternal {
                    todos.append(ReplanTodo(n: todos.count + 1, entry: e, moves: e.itemID.flatMap { moved[$0] } ?? 0))
                }
            }
        }
        return ReplanSnapshot(today: today, days: days, cells: cells, todos: todos)
    }

    // MARK: 말 읽기

    private static let cues = try! NSRegularExpression(pattern: "빡빡|벅차|버거|너무 많|넘쳐|넘치|다 못 ?해|못 ?하겠|다시 짜|풀어 ?줘|비워 ?줘|비워줘|덜어 ?줘|좀 덜어|여유가 없|숨 ?막|감당")
    private static let clearCue = try! NSRegularExpression(pattern: "비워|비우|아무것도 못|아무것도 안|쉬고 싶|쉴래|통째로")
    private static let keepCue = try! NSRegularExpression(pattern: "꼭|반드시|그대로|건드리지|빼고|말고|놔둬|놔 둬|남겨")

    private static func has(_ rx: NSRegularExpression, _ s: String) -> Bool { rx.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }

    /// 한 주를 풀어 달라는 말인가 (넣기 줄 · 말로 하기가 이 화면으로 보낼지 가린다)
    static func looksLikeReplan(_ text: String) -> Bool { has(cues, text.precomposedStringWithCanonicalMapping) }

    /// 어느 날을 · 비울지 · 무엇을 지킬지. 요일을 안 말했으면 한 주 전체에서 넘치는 칸을 본다.
    static func read(_ text: String, snapshot s: ReplanSnapshot) -> ReplanAsk {
        let t = text.precomposedStringWithCanonicalMapping
        var ask = ReplanAsk()
        if t.contains("오늘") { ask.focus.append(s.today) }
        if t.contains("내일"), let d = s.day(named: "내일") { ask.focus.append(d) }
        if t.contains("모레"), let d = s.day(named: "모레") { ask.focus.append(d) }
        for d in s.days.dropFirst(1) where t.contains(Fmt.weekday[d.weekday()] + "요일") && !ask.focus.contains(d) { ask.focus.append(d) }
        ask.clear = !ask.focus.isEmpty && has(clearCue, t)
        // 이름이 말에 나오고 지키라는 낱말이 있으면 그 일은 그대로 둔다
        if has(keepCue, t) {
            for todo in s.todos where mentions(t, todo.entry.title) { ask.keep.insert(todo.n) }
        }
        return ask
    }

    /// 말에 그 일의 이름(또는 이름의 두 글자 넘는 낱말)이 나오나
    static func mentions(_ text: String, _ title: String) -> Bool {
        if text.contains(title) { return true }
        return title.split(separator: " ").contains { $0.count >= 2 && text.contains($0) }
    }

    // MARK: 안 검사

    /// 모델이 미뤄도 된다고 고른 번호를 차례로 놓아 본다. 넘치는 칸(또는 비우라는 날)의 일만, 가장 가까운 넉넉한 칸으로.
    /// 없는 번호 · 지키라고 한 일 · 오늘의 하나 · 넘치지 않는 칸의 일은 건너뛴다. 넘침이 풀리면 그 칸에서는 더 안 옮긴다.
    static func choose(later: [Int], snapshot s: ReplanSnapshot, ask: ReplanAsk) -> [ReplanMove] {
        var cells = s.cells
        var out: [ReplanMove] = []
        for n in later.prefix(12) {
            guard out.count < 8, let todo = s.todos.first(where: { $0.n == n }), !out.contains(where: { $0.id == todo.id }),
                  let i = cells.firstIndex(where: { $0.day == todo.entry.day && $0.part == todo.entry.part }) else { continue }
            let inScope = ask.focus.isEmpty || ask.focus.contains(todo.entry.day)
            guard inScope, ask.clear || cells[i].overflow > 0, let (d, p) = target(for: todo, cells: cells, snapshot: s, ask: ask),
                  let m = place(todo, day: d, part: p, why: why(cells[i], snapshot: s, ask: ask), cells: &cells, ask: ask, fromAI: true) else { continue }
            out.append(m)
        }
        return out
    }

    private static func why(_ c: ReplanCell, snapshot s: ReplanSnapshot, ask: ReplanAsk) -> String {
        ask.clear ? "\(s.short(c.day, c.part).split(separator: " ")[0])을 비우려고" : "\(s.short(c.day, c.part))이 \(Fmt.dur(c.overflow)) 넘쳐서"
    }

    /// 한 건을 놓아 본다. 되면 칸의 짐을 고치고 옮김을 돌려준다.
    private static func place(_ todo: ReplanTodo, day: DayKey, part: Part, why: String, cells: inout [ReplanCell], ask: ReplanAsk, fromAI: Bool) -> ReplanMove? {
        let e = todo.entry
        guard !ask.keep.contains(todo.n), !e.pinned, !(e.day == day && e.part == part),
              let from = cells.firstIndex(where: { $0.day == e.day && $0.part == e.part }),
              let to = cells.firstIndex(where: { $0.day == day && $0.part == part }), !cells[to].gone else { return nil }
        // 덜어 낼 까닭이 있어야 한다: 넘치는 칸이거나, 덜어 달라고 한 날이거나
        let helps = cells[from].overflow > 0 || ask.focus.contains(e.day)
        // 비우려는 날로는 옮기지 않는다. 받는 칸은 넘치면 안 된다.
        guard helps, !(ask.clear && ask.focus.contains(day)), cells[to].room >= e.duration else { return nil }
        cells[from].planned -= e.duration
        cells[to].planned += e.duration
        return ReplanMove(todo: todo, day: day, part: part, why: why, fromAI: fromAI)
    }

    // MARK: 규칙 대체 · 모자란 만큼 채우기

    /// 넘치는 칸(또는 비우라는 날)에서 덜어 빈 칸으로 놓는다. already 는 이미 정한 옮김 — 그 뒤의 짐에서 이어서 푼다.
    static func fill(snapshot s: ReplanSnapshot, ask: ReplanAsk, already: [ReplanMove] = []) -> [ReplanMove] {
        var cells = apply(already, to: s.cells)
        var out = already
        let scope = ask.focus.isEmpty ? s.days : ask.focus
        for day in scope {
            for part in Part.allCases {
                guard let i = cells.firstIndex(where: { $0.day == day && $0.part == part }) else { continue }
                // 이 칸에서 옮길 수 있는 일: 긴 것부터 (적게 옮기고 푼다). 여러 번 넘어온 일은 뒤로 — 또 미루지 않게.
                let here = s.todos.filter { t in t.entry.day == day && t.entry.part == part && !t.entry.pinned && !ask.keep.contains(t.n) && !out.contains { $0.id == t.id } }
                    .sorted { ($0.moves, -$0.entry.duration) < ($1.moves, -$1.entry.duration) }
                for todo in here {
                    guard out.count < 8, ask.clear || cells[i].overflow > 0 else { break }
                    guard let (d, p) = target(for: todo, cells: cells, snapshot: s, ask: ask) else { continue }
                    if let m = place(todo, day: d, part: p, why: why(cells[i], snapshot: s, ask: ask), cells: &cells, ask: ask, fromAI: false) { out.append(m) }
                }
            }
        }
        return out
    }

    /// 가장 가까운 넉넉한 칸: 같은 날 뒤쪽 칸 → 다음 날부터 같은 칸 먼저. 비우려는 날은 건너뛴다.
    private static func target(for todo: ReplanTodo, cells: [ReplanCell], snapshot s: ReplanSnapshot, ask: ReplanAsk) -> (DayKey, Part)? {
        let e = todo.entry
        var order: [(DayKey, Part)] = []
        if !(ask.clear && ask.focus.contains(e.day)) {
            order += Part.allCases.filter { $0.index > e.part.index }.map { (e.day, $0) }
        }
        for d in s.days where d > e.day && !(ask.clear && ask.focus.contains(d)) {
            order += ([e.part] + Part.allCases.filter { $0 != e.part }).map { (d, $0) }
        }
        return order.first { d, p in cells.contains { $0.day == d && $0.part == p && !$0.gone && $0.room >= e.duration } }
    }

    // MARK: 옮긴 뒤의 짐 · 말

    static func apply(_ moves: [ReplanMove], to cells: [ReplanCell]) -> [ReplanCell] {
        var c = cells
        for m in moves {
            if let from = c.firstIndex(where: { $0.day == m.todo.entry.day && $0.part == m.todo.entry.part }) { c[from].planned -= m.todo.entry.duration }
            if let to = c.firstIndex(where: { $0.day == m.day && $0.part == m.part }) { c[to].planned += m.todo.entry.duration }
        }
        return c
    }

    /// 보려는 범위에서 넘치는 시간 (분)
    static func overflow(_ cells: [ReplanCell], ask: ReplanAsk) -> Int {
        cells.filter { ask.focus.isEmpty || ask.focus.contains($0.day) }.reduce(0) { $0 + $1.overflow }
    }

    /// 결과 한 줄. 숫자는 전부 여기서 센다 (모델이 쓰지 않는다).
    static func headline(_ r: ReplanResult, chosen: Set<String>? = nil) -> String {
        let s = r.snapshot
        let on = chosen ?? r.defaults
        let picked = r.moves.filter { on.contains($0.id) }
        let before = overflow(s.cells, ask: r.ask), after = overflow(r.after(chosen), ask: r.ask)
        if r.moves.isEmpty {
            if before == 0 && !r.ask.clear { return "넘치는 칸이 없어. 이대로 괜찮아." }
            return "옮길 자리를 못 찾았어. 나중에 함으로 내리거나 큰일을 쪼개 보는 건 어때?"
        }
        if picked.isEmpty { return "고른 게 없어. 옮길 일을 눌러 골라." }
        if r.ask.clear, let d = r.ask.focus.first {
            let ids = Set(picked.map(\.id))
            let rest = s.todos.filter { $0.entry.day == d && !ids.contains($0.id) }
            let held = rest.filter { r.ask.keep.contains($0.n) || $0.entry.pinned }.count
            if rest.isEmpty { return "\(picked.count)개를 옮기면 \(s.short(d, .morning).split(separator: " ")[0])이 비어." }
            if held == rest.count { return "\(picked.count)개를 옮길게. 지키기로 한 \(held)개는 그대로 둬." }
            return "\(picked.count)개를 옮길게. \(rest.count - held)개는 자리가 없어 남아."
        }
        if before > 0 {
            if after == 0 { return "\(picked.count)개를 옮기면 넘치는 칸이 없어져." }
            let held = r.moves.contains { $0.optional && !on.contains($0.id) }
            return "\(picked.count)개를 옮기면 넘치는 시간이 \(Fmt.dur(before)) → \(Fmt.dur(after))." + (held ? " 남은 건 그 자리에서 해야 해 보여서 그대로 뒀어." : "")
        }
        return "\(picked.count)개를 옮길게."
    }

    /// 규칙이 본 것을 과정 줄로 (모델 없이도 같은 화면)
    static func traces(_ s: ReplanSnapshot, ask: ReplanAsk) -> [ReplanTrace] {
        let over = s.cells.filter { $0.overflow > 0 && (ask.focus.isEmpty || ask.focus.contains($0.day)) }
        let week = over.isEmpty ? "한 주를 훑어봤어. 넘치는 칸은 없어."
                                : "한 주를 훑어봤어. " + over.prefix(3).map { "\(s.short($0.day, $0.part)) \(Fmt.dur($0.overflow)) 넘침" }.joined(separator: " · ")
        let roomy = s.cells.filter { !$0.gone && $0.room >= 60 }.max { $0.room < $1.room }
        var out = [ReplanTrace(kind: .week, text: week)]
        if let roomy { out.append(ReplanTrace(kind: .todos, text: "옮길 수 있는 일 \(s.todos.count)개 · 가장 넉넉한 칸은 \(s.short(roomy.day, roomy.part)) (\(Fmt.dur(roomy.room)))")) }
        return out
    }

    // MARK: 도구가 돌려주는 글 (모델이 읽는다)

    /// seeWeek: 날마다 한 줄. 지난 칸은 뺀다.
    static func weekText(_ s: ReplanSnapshot, days: Int = 7) -> String {
        s.days.prefix(max(1, min(7, days))).map { d in
            let parts = s.cells.filter { $0.day == d && !$0.gone }.map { c in
                c.overflow > 0 ? "\(c.part.name) 빈 \(Fmt.dur(c.free)) 할 일 \(Fmt.dur(c.planned)) → \(Fmt.dur(c.overflow)) 넘침"
                               : "\(c.part.name) 빈 \(Fmt.dur(c.room)) 남음"
            }
            return "\(s.label(d)): " + (parts.isEmpty ? "지나감" : parts.joined(separator: " / "))
        }.joined(separator: "\n")
    }

    /// seeTodos: 그날의 옮길 수 있는 일을 번호와 함께
    static func todosText(_ s: ReplanSnapshot, day: DayKey) -> String {
        let list = s.todos.filter { $0.entry.day == day }
        guard !list.isEmpty else { return "\(s.label(day)): 옮길 수 있는 할 일이 없어." }
        return "\(s.label(day))의 할 일\n" + list.map { t in
            var bits = ["\(t.n)번 \(t.entry.title)", t.entry.part.name, Fmt.dur(t.entry.duration)]
            if t.entry.pinned { bits.append("오늘의 하나(옮기지 마)") }
            if t.moves >= 2 { bits.append("\(t.moves)번 넘어옴") }
            return bits.joined(separator: " · ")
        }.joined(separator: "\n")
    }
}
