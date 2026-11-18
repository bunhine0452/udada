import AppIntents
import Foundation

// Siri · 단축어 · Spotlight · 동작 버튼에서 쓰는 우다다 동작들.
// 넣기·묻기·끝내기는 앱을 열지 않고, 식히기·비우기·하루 닫기·잠깐은 앱을 그 화면으로 연다.

// MARK: - 적기

struct AddEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "우다다에 적기"
    static let description: IntentDescription? = IntentDescription("한 줄로 말하면 날짜·시각·띠를 읽어 넣어. 예: 내일 3시 치과")

    @Parameter(title: "적을 것", requestValueDialog: IntentDialog("뭘 적을까?"))
    var text: String

    static var parameterSummary: some ParameterSummary { Summary("\(\.$text) 적기") }

    init() {}
    init(text: String) { self.text = text }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = IntentData.read()
        guard let item = Self.item(from: text, now: IntentData.now, settings: data.settings) else {
            throw $text.needsValueError(IntentDialog("뭘 적을까?"))
        }
        await IntentData.write { $0.add(item) }
        return .result(dialog: IntentDialog(stringLiteral: Self.placed(item, today: IntentData.today)))
    }

    /// 한 줄 → 항목. 날짜가 없으면 오늘, 띠가 없으면 지금 띠 (다른 날이면 아침). '나중에'면 나중에 함.
    static func item(from text: String, now: Date, settings: Settings, calendar: Calendar = .current) -> Item? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let p = Parser.parse(raw, now: now, parts: settings.parts, calendar: calendar)
        let today = DayKey(now, calendar: calendar)
        let day: DayKey? = p.day ?? ((p.later && p.repeatRule == nil) ? nil : today)
        let part: Part
        if let t = p.time { part = settings.parts.part(at: t) }
        else if let bp = p.part { part = bp }
        else if day == today { part = settings.parts.part(at: minuteOfDay(now, calendar: calendar)) }
        else { part = .morning }
        return Item(title: p.title.isEmpty ? raw : p.title, day: day, part: part, time: day == nil ? nil : p.time,
                    duration: p.duration ?? settings.defaultDuration, repeatRule: p.repeatRule)
    }

    /// "내일 15:00에 넣었어 · 치과"
    static func placed(_ it: Item, today: DayKey) -> String {
        if it.isLater { return "나중에 함에 넣었어 · \(it.title)" }
        let when = it.repeatRule?.label ?? Fmt.day(it.day, today: today)
        let slot = it.time.map(Fmt.hm) ?? it.part.name
        return "\(when) \(slot)에 넣었어 · \(it.title)"
    }
}

// MARK: - 지금 뭐 해?

struct NowIntent: AppIntent {
    static let title: LocalizedStringResource = "지금 뭐 해?"
    static let description: IntentDescription? = IntentDescription("다음 약속까지 남은 시간과, 그 안에 들어가는 일 하나를 알려 줘.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let sheet = IntentData.sheet(for: IntentData.today)
        let line = sheet.now
        let spoken = line.map { "\($0.headline). \($0.advice)" } ?? "오늘은 비어 있어."
        return .result(dialog: IntentDialog(stringLiteral: spoken), view: NowSnippet(line: line))
    }
}

// MARK: - 오늘 할 일

struct TodayIntent: AppIntent {
    static let title: LocalizedStringResource = "오늘 할 일"
    static let description: IntentDescription? = IntentDescription("오늘 안 끝낸 할 일을 띠별로 읽어 줘.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let sheet = IntentData.sheet(for: IntentData.today)
        return .result(dialog: IntentDialog(stringLiteral: Self.spoken(sheet)), view: TodaySnippet(sheet: sheet))
    }

    /// "오늘 할 일 4개야. 아침 메일 답장. 낮 보고서 초안, 택배 보내기. 외 1개." (제목은 5개까지)
    static func spoken(_ sheet: DaySheet, limit: Int = 5) -> String {
        let total = sheet.openTodos
        guard total > 0 else {
            let left = sheet.bands.flatMap(\.events).filter { ($0.time ?? 0) > (sheet.now?.minute ?? -1) }.count
            return left > 0 ? "남은 할 일은 없어. 약속은 \(left)개 남았어." : "남은 할 일은 없어. 쉬어도 돼."
        }
        var said = 0
        var parts: [String] = []
        for band in sheet.bands {
            let open = band.todos.filter { !$0.done }
            guard !open.isEmpty, said < limit else { continue }
            let take = open.prefix(limit - said).map(\.title)
            said += take.count
            parts.append("\(band.part.name) " + take.joined(separator: ", "))
        }
        var s = "오늘 할 일 \(total)개야. " + parts.joined(separator: ". ") + "."
        if total > said { s += " 외 \(total - said)개." }
        return s
    }
}

// MARK: - 찾기

struct FindIntent: AppIntent {
    static let title: LocalizedStringResource = "우다다에서 찾기"
    static let description: IntentDescription? = IntentDescription("말하듯 물으면 내 기록에서 찾아 줘. 예: 다음 주에 병원 언제야")

    @Parameter(title: "물음", requestValueDialog: IntentDialog("뭘 찾을까?"))
    var question: String

    static var parameterSummary: some ParameterSummary { Summary("\(\.$question) 찾기") }

    init() {}
    init(question: String) { self.question = question }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let data = IntentData.read()
        var a = await Brain.shared.find(question, data: data, today: IntentData.today)
        // 낱말이 안 겹쳐도 뜻이 맞는 기록까지 (Siri 는 한 번에 답해야 하니 여기서 기다린다)
        if let more = await Brain.shared.findMore(question, answer: a, data: data, today: IntentData.today) { a = more }
        return .result(dialog: IntentDialog(stringLiteral: Self.spoken(a, today: IntentData.today)), view: FindSnippet(answer: a, today: IntentData.today))
    }

    /// "다음 주 병원, 11월 24일 화요일 10시." — 여러 개면 개수와 앞의 셋
    static func spoken(_ a: FindAnswer, today: DayKey) -> String {
        guard !a.hits.isEmpty else { return "찾은 게 없어." }
        if a.hits.count == 1 { return "\(a.hits[0].title), \(FindRules.when(a.hits[0], today: today).trimmingCharacters(in: .whitespaces))." }
        let first = a.hits.prefix(3).map { "\($0.title) \(FindRules.when($0, today: today).trimmingCharacters(in: .whitespaces))" }
        return "\(a.hits.count)개 찾았어. " + first.joined(separator: ", ") + (a.hits.count > 3 ? " 외 \(a.hits.count - 3)개." : ".")
    }
}

// MARK: - 끝내기

struct CompleteEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "할 일 끝내기"
    static let description: IntentDescription? = IntentDescription("고른 할 일을 끝낸 것으로 표시해.")

    @Parameter(title: "할 일", requestValueDialog: IntentDialog("뭘 끝냈어?"))
    var task: TaskEntity

    static var parameterSummary: some ParameterSummary { Summary("\(\.$task) 끝내기") }

    init() {}
    init(task: TaskEntity) { self.task = task }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let id = UUID(uuidString: task.id), IntentData.read().item(id) != nil else {
            return .result(dialog: "그 일은 못 찾았어.")
        }
        let now = IntentData.now
        await IntentData.write { $0.setDone(.item(id), true, now: now) }
        return .result(dialog: IntentDialog(stringLiteral: "‘\(task.title)’ 끝냈어"))
    }
}

// MARK: - 앱을 그 화면으로 여는 것들

enum RestChoice: String, AppEnum {
    case breath, far, walk
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "식히기"
    static let caseDisplayRepresentations: [RestChoice: DisplayRepresentation] = [
        .breath: DisplayRepresentation(title: "숨 고르기", subtitle: "1분", image: .init(systemName: "wind")),
        .far: DisplayRepresentation(title: "멀리 보기", subtitle: "3분", image: .init(systemName: "mountain.2")),
        .walk: DisplayRepresentation(title: "걷기", subtitle: "10분", image: .init(systemName: "figure.walk")),
    ]
}

struct StartRestIntent: AppIntent {
    static let title: LocalizedStringResource = "식히기 시작"
    static let description: IntentDescription? = IntentDescription("숨 고르기 · 멀리 보기 · 걷기 중 하나를 바로 시작해.")
    static let openAppWhenRun = true
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "어떻게", default: .breath)
    var kind: RestChoice

    static var parameterSummary: some ParameterSummary { Summary("\(\.$kind) 시작") }

    init() {}
    init(kind: RestChoice) { self.kind = kind }

    @MainActor
    func perform() async throws -> some IntentResult {
        await IntentData.open("udada://rest/\(kind.rawValue)")
        return .result()
    }
}

struct DumpIntent: AppIntent {
    static let title: LocalizedStringResource = "쏟아내기"
    static let description: IntentDescription? = IntentDescription("머릿속에 도는 것을 다 적고 칸으로 나눠.")
    static let openAppWhenRun = true
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await IntentData.open("udada://dump")
        return .result()
    }
}

struct VoiceDumpIntent: AppIntent {
    static let title: LocalizedStringResource = "말로 쏟아내기"
    static let description: IntentDescription? = IntentDescription("말로 쏟아내면 글자로 받아 적어.")
    static let openAppWhenRun = true
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await IntentData.open("udada://dump/voice")
        return .result()
    }
}

struct CloseDayIntent: AppIntent {
    static let title: LocalizedStringResource = "하루 닫기"
    static let description: IntentDescription? = IntentDescription("오늘 남은 일의 자리를 정하고 하루를 닫아.")
    static let openAppWhenRun = true
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await IntentData.open("udada://close")
        return .result()
    }
}

/// 단축어 개인 자동화 "YouTube·Instagram·TikTok 을 열 때" 에 붙이는 동작.
/// 잠깐 화면이 꺼져 있거나(gateOn) 방금 "그냥 갈래"를 골랐으면(GatePass) 앱을 열지 않고 조용히 끝낸다.
/// iOS 26+: 필요할 때만 앞으로 (dynamic). 그 아래: 앞으로 갈지 한 번 묻는다 (ForegroundContinuableIntent).
struct GateIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "숏폼 앞에 잠깐"
    static let description: IntentDescription? = IntentDescription("숏폼 앱을 열 때 우다다가 먼저 떠서 한 번 묻게 해. 단축어 자동화에 붙여 써.")
    static let openAppWhenRun = false
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        guard Self.shouldGate(gateOn: IntentData.read().settings.gateOn, passOpen: GatePass.isOpen()) else { return .result() }
        if #available(iOS 26.0, *) {
            try await continueInForeground(nil, alwaysConfirm: false)
        } else {
            try await requestToContinueInForeground()
        }
        await IntentData.open("udada://gate")
        return .result()
    }

    static func shouldGate(gateOn: Bool, passOpen: Bool) -> Bool { gateOn && !passOpen }
}
