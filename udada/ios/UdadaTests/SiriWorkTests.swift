import XCTest
@testable import Udada

// Siri 가 앱을 열지 않고 하는 일의 계산 부분: 쏟아낸 말을 나눠 넣기 · 한 문장으로 여러 일 바꾸기.
// 기준: 2026-11-18 (수) 14:20 Asia/Seoul. 규칙 경로(모델 없이)로 본다.

final class SiriWorkTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    private var today: DayKey { DayKey(y: 2026, m: 11, d: 18) }
    private var now: Date { today.date(minute: 14 * 60 + 20, calendar: cal) }

    func testSortPutsEachPieceInItsPlace() {
        let cards = BrainRules.organize("엄마한테 전화하고 내일 은행 가야 되고 월세 오르면 어떡하지", today: today, now: now, calendar: cal)
        let out = SiriWork.sort(cards, today: today, now: now, settings: Settings(), calendar: cal)
        XCTAssertEqual(out.items.count, 3, "세 조각이 하나도 빠지지 않는다")
        XCTAssertEqual(out.rows.map(\.tag), ["지금", "내일 아침", "걱정 상자"])
        XCTAssertEqual(out.items[0].day, today)
        XCTAssertEqual(out.items[1].day, today.adding(days: 1, calendar: cal))
        XCTAssertTrue(out.items[2].worry)
        XCTAssertEqual(out.head, "3개로 나눠 넣었어")
    }

    /// '버리기'로 읽힌 것도 Siri 가 대신 버리지 않는다 — 나중에 함에 남는다
    func testDropIsKeptForLater() {
        let card = DumpSuggestion(text: "헬스장 등록할까 말까", bin: .drop, reason: "", fromAI: false)
        let out = SiriWork.sort([card], today: today, now: now, settings: Settings(), calendar: cal)
        XCTAssertEqual(out.items.count, 1)
        XCTAssertTrue(out.items[0].isLater)
        XCTAssertEqual(out.rows.first?.tag, "나중에 함")
    }

    func testSortNothing() {
        let out = SiriWork.sort([], today: today, now: now, settings: Settings(), calendar: cal)
        XCTAssertTrue(out.items.isEmpty)
        XCTAssertEqual(out.head, "넣을 걸 못 찾았어")
    }

    private func data() -> AppData {
        var d = AppData()
        d.items = [Item(title: "치과", day: today, time: 900), Item(title: "보고서 초안", day: today), Item(title: "장보기", day: today)]
        return d
    }

    func testTellDoesSeveralAndSaysSo() {
        let plan = CommandRules.plan("치과 내일로 미루고 보고서 초안은 끝냈어", data: data(), now: now, calendar: cal)
        let out = SiriWork.tell(plan, today: today)
        XCTAssertEqual(out.steps.map(\.kind), [.move, .done])
        XCTAssertEqual(out.head, "2가지 했어")
        XCTAssertEqual(out.rows.map(\.tag), ["내일", "끝냄"], "약속은 시각을 그대로 들고 내일로 간다")
        XCTAssertTrue(out.spoken.hasPrefix("2가지 했어. ‘치과’ → 내일"), out.spoken)
    }

    /// 지우기는 Siri 에서 하지 않는다 (확인 없이 사라지면 안 된다)
    func testTellNeverDeletes() {
        let plan = CommandRules.plan("장보기는 지워 줘 그리고 보고서 초안은 끝냈어", data: data(), now: now, calendar: cal)
        let out = SiriWork.tell(plan, today: today)
        XCTAssertEqual(out.steps.map(\.kind), [.done])
        XCTAssertTrue(out.rows.contains { $0.tag == "지우기는 앱에서" })
        XCTAssertTrue(out.spoken.contains("지우기는 앱에서"))

        let only = SiriWork.tell(CommandRules.plan("장보기 지워 줘", data: data(), now: now, calendar: cal), today: today)
        XCTAssertTrue(only.steps.isEmpty)
        XCTAssertEqual(only.head, "지우기는 앱에서 확인하고 할게.")
    }

    func testTellMissingTarget() {
        let out = SiriWork.tell(CommandRules.plan("수영 강습 내일로 미뤄 줘", data: data(), now: now, calendar: cal), today: today)
        XCTAssertTrue(out.steps.isEmpty)
        XCTAssertTrue(out.spoken.contains("못 찾았어"))
    }
}
