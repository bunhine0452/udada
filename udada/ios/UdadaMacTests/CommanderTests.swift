import XCTest

/// 말로 시키기의 규칙 쪽: 조각 나누기 · 가리킨 일 찾기 · 계획 · 적용.
final class CommanderTests: XCTestCase {
    private let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; return c }()
    private var now: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10))! } // 월요일 10시
    private var today: DayKey { DayKey(now, calendar: cal) }

    private func data() -> AppData {
        var d = AppData()
        d.items = [
            Item(title: "치과", day: today, time: 900), Item(title: "보고서 초안", day: today), Item(title: "메일 답장", day: today),
            Item(title: "장보기", day: today.adding(days: 1, calendar: cal)), Item(title: "여권 갱신", day: nil),
            Item(title: "물 한 잔", day: today.adding(days: -3, calendar: cal), repeatRule: .daily),
        ]
        return d
    }

    private func plan(_ s: String, readings: [CommandReading?]? = nil) -> CommandPlan {
        CommandRules.plan(s, readings: readings, data: data(), now: now, calendar: cal)
    }

    func testOneSentenceManyChanges() {
        let p = plan("치과 내일로 미루고 보고서 초안은 끝냈어, 금요일 3시에 미팅 추가해 줘")
        XCTAssertEqual(p.steps.map(\.kind), [.move, .done, .add])
        XCTAssertEqual(p.steps[0].target?.title, "치과"); XCTAssertEqual(p.steps[0].day, today.adding(days: 1, calendar: cal))
        XCTAssertEqual(p.steps[1].target?.title, "보고서 초안")
        XCTAssertEqual(p.steps[2].line, "금요일 3시에 미팅")
        XCTAssertEqual(p.steps.map { CommandRules.describe($0, today: today) }, ["‘치과’ → 내일", "‘보고서 초안’ 끝냄", "넣기: 금요일 3시에 미팅"])
    }

    func testDeleteLaterAndTimeChange() {
        var p = plan("장보기 지워 줘 그리고 여권 갱신은 다음 주 수요일로 옮겨 줘")
        XCTAssertEqual(p.steps.map(\.kind), [.delete, .move])
        XCTAssertEqual(p.steps[1].target?.title, "여권 갱신"); XCTAssertEqual(p.steps[1].day, today.adding(days: 9, calendar: cal))
        p = plan("치과 4시로 바꿔 줘")
        XCTAssertEqual(p.steps.first?.kind, .move); XCTAssertEqual(p.steps.first?.time, 960); XCTAssertEqual(p.steps.first?.day, today)
        p = plan("메일 답장은 나중에 하는 걸로 미뤄")
        XCTAssertEqual(p.steps.first?.later, true)
        p = plan("보고서 초안 미뤄 줘")
        XCTAssertEqual(p.steps.first?.day, today.adding(days: 1, calendar: cal)); XCTAssertEqual(p.steps.first?.part, .morning)
    }

    /// 없는 일을 가리키면 아무것도 안 한다 — '못 찾음'으로만 보인다
    func testUnknownTargetIsNotInvented() {
        let p = plan("수영 강습 취소해 줘")
        XCTAssertEqual(p.steps.first?.kind, .delete); XCTAssertNil(p.steps.first?.target); XCTAssertEqual(p.doable.count, 0)
        XCTAssertEqual(CommandRules.describe(p.steps[0], today: today), "‘수영 강습’ — 그런 일을 못 찾았어")
        XCTAssertEqual(plan("금요일 3시에 미팅 추가하고 장보기는 지워 줘").steps.first?.line, "금요일 3시에 미팅")
        var d = data()
        XCTAssertEqual(CommandRules.apply(p.steps, to: &d, now: now) { _ in nil }, 0)
        XCTAssertEqual(d.items.count, data().items.count)
    }

    /// 동작 낱말 없이 돌려 말한 것은 모델의 읽기를 쓴다. 단, 가리킨 일이 실제로 있어야 한다.
    func testModelReadingIsUsedOnlyWhenGrounded() {
        var p = plan("치과 진료는 받았어", readings: [CommandReading(kind: .done, target: "치과")])
        XCTAssertEqual(p.steps.first?.kind, .done); XCTAssertEqual(p.steps.first?.target?.title, "치과"); XCTAssertEqual(p.steps.first?.fromAI, true)
        // 모델이 없는 일을 '끝냄'이라 읽으면 넣기로 돌아간다
        p = plan("필라테스 등록", readings: [CommandReading(kind: .done, target: "필라테스")])
        XCTAssertEqual(p.steps.first?.kind, .add); XCTAssertEqual(p.steps.first?.fromAI, false)
        // 또렷한 동작 낱말은 모델보다 규칙이 이긴다
        p = plan("장보기 지워", readings: [CommandReading(kind: .done, target: "장보기")])
        XCTAssertEqual(p.steps.first?.kind, .delete)
    }

    func testApplyChangesData() {
        var d = data()
        let p = CommandRules.plan("치과 내일로 미루고 보고서 초안은 끝냈어, 물 한 잔도 했어, 금요일 3시에 미팅 추가해 줘", data: d, now: now, calendar: cal)
        let n = CommandRules.apply(p.steps, to: &d, now: now) { line in Item(title: line, day: self.today) }
        XCTAssertEqual(n, 4)
        XCTAssertEqual(d.items.first { $0.title == "치과" }?.day, today.adding(days: 1, calendar: cal))
        XCTAssertEqual(d.items.first { $0.title == "보고서 초안" }?.done, true)
        XCTAssertEqual(d.items.filter { $0.title == "물 한 잔" && $0.done && $0.occurrence == today }.count, 1, "반복은 오늘 하루치만 끝낸다")
        XCTAssertTrue(d.items.contains { $0.title == "금요일 3시에 미팅" })
    }

    func testQuestionsAreNotCommands() {
        XCTAssertTrue(CommandRules.isQuestion("다음 주에 병원 언제야?"))
        XCTAssertFalse(CommandRules.looksLikeCommand("오늘 뭐 끝냈지"))
        XCTAssertTrue(CommandRules.looksLikeCommand("치과 내일로 미뤄 줘"))
        XCTAssertFalse(CommandRules.looksLikeCommand("내일 3시 치과"))
    }
}

extension CommanderTests {
    /// 처음 보는 묶음에서 기존 일을 잘못 건드린 두 경우
    func testKeepAndDestination() {
        var p = CommandRules.plan("금요일 저녁 7시에 동창 모임 추가해 줘 그리고 치과는 그대로 둬", readings: [nil, CommandReading(kind: .done, target: "치과")],
                                  data: AppData(), now: Date(timeIntervalSince1970: 1_794_790_800))
        XCTAssertEqual(p.steps.map(\.kind), [.add], "'그대로 둬'는 계획에 넣지 않는다")
        var d = AppData(); var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = c.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10))!
        d.items = [Item(title: "치과", day: DayKey(now, calendar: c), time: 900)]
        p = CommandRules.plan("오늘 치과 못 갈 것 같아 수요일 오전 11시로 바꿔 줘", data: d, now: now, calendar: c)
        XCTAssertEqual(p.steps.first?.kind, .move)
        XCTAssertEqual(p.steps.first?.day, DayKey(now, calendar: c).adding(days: 2, calendar: c)); XCTAssertEqual(p.steps.first?.time, 660)
    }
}
