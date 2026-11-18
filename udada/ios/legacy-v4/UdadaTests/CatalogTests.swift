import XCTest
@testable import Udada

final class SorterTests: XCTestCase {
    func testSuggestions() {
        XCTAssertEqual(Sorter.suggest("다음 달 월세 오르면 어떡하지").bin, .worry)
        XCTAssertEqual(Sorter.suggest("헬스 등록할까 말까").bin, .drop)
        XCTAssertEqual(Sorter.suggest("엄마한테 전화").bin, .now)
        let r = Sorter.suggest("레포트 금요일까지 3장")
        XCTAssertEqual(r.bin, .date); XCTAssertEqual(r.when, .tomorrow)
        XCTAssertEqual(Sorter.suggest("주말에 대청소").when, .weekend)
        XCTAssertEqual(Sorter.suggest("오늘 밤 빨래 개기 전에 정리").when, .tonight)
    }

    private func date(_ s: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; f.timeZone = .current
        return f.date(from: s)!
    }
    private func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; f.timeZone = .current
        return f.string(from: d)
    }

    func testWhenDue() {
        // 2026-11-06 은 금요일
        let fri = date("2026-11-06 14:00")
        XCTAssertEqual(fmt(When.tonight.due(from: fri)), "2026-11-06 19:00")
        XCTAssertEqual(fmt(When.tomorrow.due(from: fri)), "2026-11-07 09:00")
        XCTAssertEqual(fmt(When.weekend.due(from: fri)), "2026-11-07 10:00")
        XCTAssertEqual(fmt(When.nextWeek.due(from: fri)), "2026-11-09 09:00")
        // 저녁 7시가 지났으면 오늘 저녁 = 1시간 뒤
        XCTAssertEqual(fmt(When.tonight.due(from: date("2026-11-06 20:30"))), "2026-11-06 21:30")
        // 토요일 오후면 '이번 주말'은 다음 토요일, 월요일이면 '다음 주'는 다음 월요일
        XCTAssertEqual(fmt(When.weekend.due(from: date("2026-11-07 15:00"))), "2026-11-14 10:00")
        XCTAssertEqual(fmt(When.nextWeek.due(from: date("2026-11-09 08:00"))), "2026-11-16 09:00")
    }

    func testReminderPlan() {
        let now = date("2026-11-06 14:00")
        let items = [
            Item(text: "레포트", bin: .date, when: .tomorrow, due: When.tomorrow.due(from: now)),
            Item(text: "끝난 거", bin: .date, when: .tonight, due: When.tonight.due(from: now), done: true),
            Item(text: "월세", bin: .worry),
            Item(text: "전화", bin: .now),
        ]
        let p = Reminders.plan(items, now: now)
        XCTAssertEqual(p.count, 2, "날짜 1개(끝난 건 제외) + 걱정 시간 1개")
        XCTAssertTrue(p.contains { $0.body.contains("레포트") && fmt($0.date) == "2026-11-07 09:00" })
        XCTAssertTrue(p.contains { $0.id == "ud.worry" && fmt($0.date) == "2026-11-06 21:30" && $0.body.contains("1개") })
        XCTAssertEqual(fmt(Reminders.plan(items, now: date("2026-11-06 22:00")).first { $0.id == "ud.worry" }!.date), "2026-11-07 21:30")
    }

    func testFormatting() {
        XCTAssertEqual(signed(3), "+3"); XCTAssertEqual(signed(-2), "-2"); XCTAssertEqual(signed(-1.25), "-1.3")
        XCTAssertEqual(Noise.word(9), "터질 듯"); XCTAssertEqual(Noise.word(1), "조용함")
    }

    func testBreathCycle() {
        XCTAssertEqual(BreathGauge.phase(0.5).0, 0)
        XCTAssertEqual(BreathGauge.phase(2.5).0, 1)
        XCTAssertEqual(BreathGauge.phase(5).0, 2)
        XCTAssertEqual(BreathGauge.phase(2.999).1, 1, accuracy: 0.01)
    }
}
