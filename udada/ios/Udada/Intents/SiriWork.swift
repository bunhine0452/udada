import AppIntents
import SwiftUI

// Siri 가 앱을 열지 않고 하는 '일': 한 문장으로 여러 일 바꾸기(시키기) · 쏟아낸 말을 나눠 넣기(정리).
// 말은 기기 안 Apple Intelligence 가 읽고(없으면 규칙), 실제로 바꾸는 것은 내 기록에 대고 규칙이 한다.
// 지우기는 Siri 에서 하지 않는다 — 확인 없이 사라지면 안 되니 앱의 '말로 하기'에서 미리 보고 한다.

// MARK: - 시키기

struct TellIntent: AppIntent {
    static let title: LocalizedStringResource = "우다다한테 시키기"
    static let description: IntentDescription? = IntentDescription("한 문장으로 여러 일을 바꿔. 예: 치과 내일로 미루고 보고서는 끝냈어, 금요일 7시 저녁 약속 넣어")

    @Parameter(title: "시킬 말", requestValueDialog: IntentDialog("뭘 할까?"))
    var text: String

    static var parameterSummary: some ParameterSummary { Summary("\(\.$text) 시키기") }

    init() {}
    init(text: String) { self.text = text }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let now = IntentData.now, today = IntentData.today
        let data = IntentData.read()
        let plan = await Brain.shared.plan(text, data: data, now: now)
        let out = SiriWork.tell(plan, today: today)
        guard !out.steps.isEmpty else {
            return .result(dialog: IntentDialog(stringLiteral: out.spoken), view: WorkSnippet(head: out.head, rows: out.rows, ai: plan.fromAI))
        }
        if let s = Store.live {
            s.apply(out.steps)
        } else {
            let settings = data.settings
            await IntentData.write { d in
                _ = CommandRules.apply(out.steps, to: &d, now: now) { AddEntryIntent.item(from: $0, now: now, settings: settings) }
            }
        }
        return .result(dialog: IntentDialog(stringLiteral: out.spoken), view: WorkSnippet(head: out.head, rows: out.rows, ai: plan.fromAI))
    }
}

// MARK: - 정리해서 넣기

struct SortIntent: AppIntent {
    static let title: LocalizedStringResource = "우다다로 정리하기"
    static let description: IntentDescription? = IntentDescription("머릿속에 도는 걸 한꺼번에 말하면 한 줄씩 나눠 오늘 · 날짜 · 걱정 상자에 넣어. 예: 엄마한테 전화하고 보고서 쓰고 월세가 걱정이야")

    @Parameter(title: "쏟아낼 말", requestValueDialog: IntentDialog("뭘 정리할까?"))
    var text: String

    static var parameterSummary: some ParameterSummary { Summary("\(\.$text) 정리해서 넣기") }

    init() {}
    init(text: String) { self.text = text }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let now = IntentData.now, today = IntentData.today
        // 위기 낱말이면 아무것도 넣지 않고 상담 전화만 알린다
        if BrainRules.isCrisis(text) {
            let line = BrainRules.crisisAdvice().line
            return .result(dialog: IntentDialog(stringLiteral: line), view: WorkSnippet(head: line, rows: [], ai: false))
        }
        let data = IntentData.read()
        let cards = await Brain.shared.organize(text, today: today, now: now)
        let out = SiriWork.sort(cards, today: today, now: now, settings: data.settings)
        if !out.items.isEmpty {
            if let s = Store.live {
                s.change(undo: "\(out.items.count)개를 나눠 넣었어") { d in out.items.forEach { d.add($0) } }
            } else {
                await IntentData.write { d in out.items.forEach { d.add($0) } }
            }
        }
        return .result(dialog: IntentDialog(stringLiteral: out.spoken),
                       view: WorkSnippet(head: out.head, rows: out.rows, ai: cards.contains(where: \.fromAI)))
    }
}

// MARK: - 계산 (화면 없이 — 테스트가 그대로 부른다)

enum SiriWork {
    struct Row: Hashable { var title: String; var tag: String }

    struct Told {
        var steps: [CommandStep]
        var head: String
        var rows: [Row]
        var spoken: String
    }

    /// 계획에서 Siri 가 바로 해도 되는 줄만 고른다 (찾은 일 · 지우기 아님) + 보여 줄 말
    static func tell(_ plan: CommandPlan, today: DayKey) -> Told {
        let steps = plan.doable.filter { $0.kind != .delete }
        let held = plan.doable.filter { $0.kind == .delete }
        let missed = plan.steps.filter { !$0.ok }
        var rows = steps.map { row($0, today: today) }
        rows += held.map { Row(title: name($0), tag: "지우기는 앱에서") }
        rows += missed.map { Row(title: name($0), tag: "못 찾음") }
        guard !steps.isEmpty else {
            let why = !held.isEmpty ? "지우기는 앱에서 확인하고 할게." : "바꿀 일을 못 찾았어. 적어 둔 이름으로 다시 말해 줘."
            return Told(steps: [], head: why, rows: rows, spoken: why)
        }
        let head = steps.count == 1 ? "한 가지 했어" : "\(steps.count)가지 했어"
        var spoken = head + ". " + steps.prefix(3).map { CommandRules.describe($0, today: today) }.joined(separator: ", ") + "."
        if !held.isEmpty { spoken += " 지우기는 앱에서 확인하고 할게." }
        if !missed.isEmpty { spoken += " \(missed.count)개는 못 찾았어." }
        return Told(steps: steps, head: head, rows: rows, spoken: spoken)
    }

    private static func name(_ s: CommandStep) -> String { s.target.map { "‘\($0.title)’" } ?? s.said }

    private static func row(_ s: CommandStep, today: DayKey) -> Row {
        switch s.kind {
        case .add: return Row(title: s.line, tag: "넣음")
        case .done: return Row(title: name(s), tag: "끝냄")
        case .delete: return Row(title: name(s), tag: "지움")
        case .move:
            if s.later { return Row(title: name(s), tag: "나중에 함") }
            let slot = s.time.map(Fmt.hm) ?? s.part?.name ?? ""
            return Row(title: name(s), tag: (Fmt.day(s.day, today: today) + " " + slot).trimmingCharacters(in: .whitespaces))
        }
    }

    struct Sorted {
        var items: [Item]
        var head: String
        var rows: [Row]
        var spoken: String
    }

    /// 카드 → 항목. 지금은 지금 띠, 날짜는 제안한 날(없으면 나중에 함), 걱정은 걱정 상자.
    /// '버리기' 제안은 Siri 가 대신 버리지 않는다 — 나중에 함에 둔다 (잃는 것보다 남는 것이 낫다).
    static func sort(_ cards: [DumpSuggestion], today: DayKey, now: Date, settings: Settings, calendar: Calendar = .current) -> Sorted {
        var items: [Item] = []
        var rows: [Row] = []
        for (i, c) in cards.enumerated() {
            let parsed = Parser.parse(c.text, now: now, parts: settings.parts, calendar: calendar)
            let bin: DumpBin = c.bin == .drop ? .date : c.bin
            let when: DumpPlan.When? = c.bin == .drop ? .later : DumpPlan.suggestedWhen(c, parsed: parsed)
            guard let item = DumpPlan.item(for: c, bin: bin, when: when, today: today, now: now, settings: settings,
                                           created: now.addingTimeInterval(Double(i) * 0.001), calendar: calendar) else { continue }
            items.append(item)
            let tag: String
            switch bin {
            case .now: tag = "지금"
            case .worry: tag = "걱정 상자"
            default: tag = DumpPlan.label(when ?? .later, time: item.time, today: today)
            }
            rows.append(Row(title: item.title, tag: tag))
        }
        guard !items.isEmpty else {
            return Sorted(items: [], head: "넣을 걸 못 찾았어", rows: [], spoken: "넣을 걸 못 찾았어. 할 일이나 걱정을 말해 줘.")
        }
        let head = items.count == 1 ? "하나 넣었어" : "\(items.count)개로 나눠 넣었어"
        let spoken = head + ". " + rows.prefix(4).map { "\($0.title), \($0.tag)" }.joined(separator: ". ") + "."
        return Sorted(items: items, head: head, rows: rows, spoken: spoken)
    }
}

// MARK: - 결과 조각

/// Siri 결과 안에 뜨는 작은 화면: 한 일의 줄들 + 어디로 갔는지
struct WorkSnippet: View {
    var head: String
    var rows: [SiriWork.Row]
    var ai: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("우다다").font(Typo.serif(15, relativeTo: .subheadline)).foregroundStyle(Ink.text)
                if ai { GAIMark() }
                Spacer()
            }
            Text(head).font(.system(.headline, weight: .bold)).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(rows.prefix(6), id: \.self) { r in
                HStack(spacing: 8) {
                    Text(r.title).font(Typo.row).foregroundStyle(Ink.text).lineLimit(1)
                    Spacer(minLength: 6)
                    GTag(text: r.tag)
                }
            }
            if rows.count > 6 { Text("그리고 \(rows.count - 6)개 더").font(Typo.meta).foregroundStyle(Ink.text3) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.sheet)
    }
}
