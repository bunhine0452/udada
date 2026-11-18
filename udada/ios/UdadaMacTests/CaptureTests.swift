import XCTest

/// 밖에서 받기의 규칙 쪽(모델 없이) + 여러 번 넘어온 일 고르기.
final class CaptureTests: XCTestCase {
    private var now: Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: "2026-11-16T10:00")! // 월요일
    }
    private var today: DayKey { DayKey(now) }

    func testKeepsSentencesWithDatesOrRequests() {
        let lines = CaptureRules.lines("안녕하세요 김대리님, 견적서 내일까지 보내주시면 감사하겠습니다. 좋은 하루 되세요.", now: now)
        XCTAssertEqual(lines, ["견적서 내일까지 보내주시면 감사하겠습니다"])
        XCTAssertEqual(Parser.parse(lines[0], now: now).day, today.adding(days: 1))
    }

    func testDropsChatterAndReceipts() {
        XCTAssertEqual(CaptureRules.lines("ㅋㅋㅋ 어제 진짜 웃겼다 다음에 또 보자", now: now), [])
        XCTAssertEqual(CaptureRules.lines("주문하신 상품이 발송되었습니다. 운송장번호 1234-5678-9012", now: now), [])
        XCTAssertEqual(CaptureRules.lines("오늘 점심 뭐 먹었어?", now: now), [])
        XCTAssertEqual(CaptureRules.lines("오늘 날씨 정말 좋네요.", now: now), [])
    }

    func testJoinsDayThenTime() {
        let lines = CaptureRules.lines("수요일 저녁에 시간 돼? 6시 반 홍대 어때", now: now)
        XCTAssertEqual(lines.count, 1)
        let p = Parser.parse(lines[0], now: now)
        XCTAssertEqual(p.day, today.adding(days: 2)); XCTAssertEqual(p.time, 18 * 60 + 30)
    }

    func testReadsBracketWeekdayAndCopula() {
        var p = Parser.parse(CaptureRules.lines("예약 확인: 서울치과 11월 20일(금) 오전 10시 30분. 변경은 02-123-4567", now: now)[0], now: now)
        XCTAssertEqual(p.day, DayKey(y: 2026, m: 11, d: 20)); XCTAssertEqual(p.time, 630)
        p = Parser.parse(CaptureRules.lines("대여하신 책 반납일이 내일입니다.", now: now)[0], now: now)
        XCTAssertEqual(p.day, today.adding(days: 1))
    }

    func testModelLinesMustComeFromTheText() {
        let src = "팀장: 내일 오전 9시 반까지 발표 자료 최종본 올려주세요"
        let found = [CaptureRules.Found(title: "발표 자료 최종본 올리기", when: "내일 오전 9시 반"),
                     CaptureRules.Found(title: "회식 장소 예약", when: "금요일"),       // 글에 없는 일
                     CaptureRules.Found(title: "발표 자료 최종본", when: "다음 주 월요일")] // 글에 없는 때
        let lines = CaptureRules.lines(from: found, source: src, now: now)
        XCTAssertEqual(lines.first, "내일 오전 9시 반 발표 자료 최종본 올리기")
        XCTAssertFalse(lines.contains { $0.contains("회식") })
        XCTAssertTrue(lines.contains("발표 자료 최종본"), "때 낱말이 글에 없으면 때만 뗀다")
    }

    func testBlendKeepsRuleSkeletonAndAddsOnlyDatedNewOnes() {
        let rule = ["다음 주 화요일 오후 2시 주간회의"]
        let model = ["다음 주 화요일 오후 2시 회의 내용 정리", "금요일 3시 워크숍", "간식 준비"]
        let out = CaptureRules.blend(rule: rule, model: model, now: now)
        XCTAssertEqual(out, ["다음 주 화요일 오후 2시 주간회의", "금요일 3시 워크숍"])
    }

    // MARK: 여러 번 넘어온 일

    func testSettleCountsCarryOversAndAsksAfterThree() {
        var d = AppData()
        d.items = [Item(title: "보고서 초안", day: today.adding(days: -3)), Item(title: "장보기", day: today)]
        XCTAssertNil(d.stuck(today: today))
        for i in stride(from: -2, through: 0, by: 1) { d.settle(now: now.addingTimeInterval(Double(i) * 86400)) }
        XCTAssertEqual(d.items[0].moves, 3)
        XCTAssertEqual(d.stuck(today: today)?.title, "보고서 초안")
        // 그냥 둘게 → 한 주 동안 안 묻는다
        d.keepStuck(d.items[0].id, today: today)
        XCTAssertNil(d.stuck(today: today))
        XCTAssertNil(d.stuck(today: today.adding(days: 6)))
    }

    func testLaterOrDoneClearsStuck() {
        var d = AppData()
        var it = Item(title: "보고서 초안", day: today); it.moves = 5
        d.items = [it]
        XCTAssertNotNil(d.stuck(today: today))
        d.move(.item(it.id), to: nil)
        XCTAssertEqual(d.items[0].moves, 0)
        XCTAssertNil(d.stuck(today: today))
    }

    func testOldFilesDecodeWithoutMoves() throws {
        let raw = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"옛 일"}"#
        let it = try JSONDecoder().decode(Item.self, from: Data(raw.utf8))
        XCTAssertEqual(it.moves, 0); XCTAssertNil(it.stuckAsked)
    }
}
