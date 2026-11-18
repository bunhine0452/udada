import Foundation

extension Store {
    /// 계획에서 고른 줄을 한 번에 적용한다 (되돌리기 한 번). 넣기는 '한 줄 넣기'와 같은 규칙으로 읽는다.
    @discardableResult
    func apply(_ steps: [CommandStep]) -> Int {
        let now = self.now, settings = self.settings
        var n = 0
        var draft = data
        n = CommandRules.apply(steps, to: &draft, now: now) { AddEntryIntent.item(from: $0, now: now, settings: settings) }
        guard n > 0 else { return 0 }
        change(undo: n == 1 ? "한 가지를 바꿨어" : "\(n)가지를 바꿨어") { $0 = draft }
        return n
    }

    /// 쪼갠 걸음을 한 번에 넣는다 (되돌리기 한 번). 큰일 자체는 그대로 둔다.
    @discardableResult
    func addSteps(_ steps: [BreakStep], subject: String) -> Int {
        guard !steps.isEmpty else { return 0 }
        let items = BreakRules.items(steps, subject: subject, duration: settings.defaultDuration, now: now)
        change(undo: "걸음 \(items.count)개를 날에 놓았어") { d in items.forEach { d.add($0) } }
        return items.count
    }
}

// MARK: - 쪼개기 화면의 상태 (iPhone 시트와 Mac 시트가 같이 쓴다)

/// 무엇을 쪼갤지: 큰일의 이름 · 마감(없으면 nil) · 띠
struct SplitRequest: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var due: DayKey?
    var part: Part
}

@MainActor
@Observable
final class BreakdownDraft {
    struct Line: Identifiable {
        let id = UUID()
        var text: String
        var on = true
    }

    let request: SplitRequest
    var subject = ""
    var lines: [Line] = []
    var pace: BreakPace = .daily
    var paces: [BreakPace] = []
    var fromAI = false
    var loading = true
    /// 위기 글이라 나누지 않았다
    var blocked = false

    init(_ request: SplitRequest) { self.request = request }

    func load(_ store: Store) async {
        subject = BreakRules.subject(request.title, now: store.now, parts: store.settings.parts)
        paces = BreakRules.paces(today: store.today, due: request.due)
        pace = paces[0]
        let b = await Brain.shared.breakdown(request.title, now: store.now)
        lines = (b?.steps ?? []).map { Line(text: $0) }
        fromAI = b?.fromAI ?? false
        blocked = b == nil
        loading = false
    }

    private var chosen: [Line] { lines.filter { $0.on && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty } }
    var count: Int { chosen.count }

    /// 켜 둔 걸음만 날에 놓는다 (하나를 끄면 나머지가 다시 고르게 놓인다)
    func placed(_ store: Store) -> [(line: UUID, step: BreakStep)] {
        let c = chosen
        let steps = BreakRules.place(c.map { BrainRules.tidy($0.text) }, pace: pace, today: store.today, due: request.due,
                                     nowPart: store.settings.parts.part(at: minuteOfDay(store.now)), part: request.part)
        return zip(c, steps).map { ($0.id, $1) }
    }

    /// 그 걸음이 놓일 자리 ("내일 · 낮"). 꺼 두었으면 nil.
    func slot(_ line: Line, _ store: Store) -> String? {
        guard let s = placed(store).first(where: { $0.line == line.id })?.step else { return nil }
        return "\(Fmt.day(s.day, today: store.today)) · \(s.part.name)"
    }

    /// 날을 어떻게 놓는지 한 줄. 마감이 모레 이후일 때만 '넘기지 않는다'고 말한다 (오늘·내일 마감에 '하루에 하나'를 고르면 넘겨 이어진다).
    func placeNote(_ store: Store) -> String {
        if let due = request.due, store.today.days(to: due) >= 2 { return "날은 마감 전날까지 끝나게 규칙이 놓아." }
        return pace == .today ? "걸음은 오늘 지금 띠에 놓여." : "걸음은 오늘부터 하루에 하나씩 놓여."
    }

    func apply(_ store: Store) -> Int { store.addSteps(placed(store).map(\.step), subject: subject) }
}
