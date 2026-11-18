import XCTest

/// 실제 Mac 모델(macOS 27.2)에서 본 두 결함을 고정한다: 칸 이름이 글에 새는 것, 쏟아낸 줄이 빠지는 것.
final class BrainFinishTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_794_700_000)
    private var today: DayKey { DayKey(now) }

    func testBinTagIsStripped() {
        XCTAssertEqual(BrainRules.stripBinTag("엄마한테 전화해야 돼 (now"), "엄마한테 전화해야 돼")
        XCTAssertEqual(BrainRules.stripBinTag("기획서 금요일까지 내야 돼 (date)"), "기획서 금요일까지 내야 돼")
        XCTAssertEqual(BrainRules.stripBinTag("헬스장 등록할까 말까 고민 중이야 [drop]"), "헬스장 등록할까 말까 고민 중이야")
        XCTAssertEqual(BrainRules.stripBinTag("화분 분갈이 ("), "화분 분갈이")
        XCTAssertEqual(BrainRules.stripBinTag("update 문서 보내기"), "update 문서 보내기")
    }

    func testLeakedTagDoesNotReachCard() throws {
        let raw = "엄마한테 전화해야 되고 화분 분갈이도 해야 돼"
        let drafts = [BrainRules.Draft(text: "엄마한테 전화해야 돼 (now", bin: .now), BrainRules.Draft(text: "화분 분갈이도 해야 돼 (date", bin: .date)]
        let out = try XCTUnwrap(BrainRules.finish(drafts, raw: raw, today: today, now: now))
        XCTAssertFalse(out.contains { $0.text.contains("(") || $0.text.contains("now") || $0.text.contains("date") }, "\(out.map(\.text))")
    }

    /// 다섯 줄 중 모델이 한 줄(걱정)을 빠뜨려도 카드는 다섯 장이어야 한다
    func testMissedLineIsKept() throws {
        let raw = "엄마한테 전화해야 되고 금요일까지 기획서 내야 되는데 아직 시작도 못 했어 그리고 월세 오르면 어떡하지 헬스장 등록할까 말까 고민 중이고 화분 분갈이도 해야 돼"
        let drafts = [
            BrainRules.Draft(text: "엄마한테 전화해야 돼", bin: .now),
            BrainRules.Draft(text: "기획서 금요일까지 내야 돼", bin: .date),
            BrainRules.Draft(text: "헬스장 등록할까 말까 고민 중이야", bin: .drop),
            BrainRules.Draft(text: "화분 분갈이도 해야 돼", bin: .date),
        ]
        let out = try XCTUnwrap(BrainRules.finish(drafts, raw: raw, today: today, now: now))
        let worry = out.first { $0.text.contains("월세") }
        XCTAssertNotNil(worry, "빠진 줄이 없어야 한다: \(out.map(\.text))")
        XCTAssertEqual(worry?.bin, .worry)
        XCTAssertEqual(worry?.fromAI, false)
    }
}

extension BrainFinishTests {
    /// "… 어떡하지" 뒤에 다른 일이 이어져도 걱정은 따로 한 줄
    func testWorryEndingSplits() {
        let got = BrainRules.split("월세 오르면 어떡하지 헬스장 등록할까 말까 고민 중이고 화분 분갈이도 해야 돼")
        XCTAssertEqual(got.first, "월세 오르면 어떡하지")
        XCTAssertEqual(got.count, 3, "\(got)")
    }
}

/// 사진에서 본 일정의 검사 (BrainRules.lines) — 모델이 낸 것을 글자 인식 결과와 맞춰 본다.
final class SeenEventTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_794_700_000) // 2026-11-15 무렵
    private typealias E = BrainRules.SeenEvent

    func testPairsDateWithTitleAndDropsInvented() {
        let ocr = ["제12회", "가을 정기 연주회", "시민 오케스트라", "2026. 11. 20 (금) 오후 7시 30분", "구민회관 대강당", "전석 10,000원 · 문의 02-123-4567"]
        let got = BrainRules.lines(from: [E(title: "가을 정기 연주회", month: 11, day: 20, hour: 19, minute: 30),
                                          E(title: "피아노 독주회", month: 11, day: 21, hour: 18, minute: 0)], ocr: ocr, now: now)
        XCTAssertEqual(got, ["11월 20일 오후 7시 30분 가을 정기 연주회"], "사진에 없는 '피아노 독주회'는 버린다")
    }

    func testDateNotInPhotoIsNotUsed() {
        let got = BrainRules.lines(from: [E(title: "세탁소 코트 찾기", month: 12, day: 25, hour: -1, minute: 0)], ocr: ["- 세탁소 코트 찾기", "- 관리비 이체"], now: now)
        XCTAssertEqual(got, ["세탁소 코트 찾기"], "사진에 없는 날짜는 붙이지 않는다")
    }

    /// 모델이 시간표를 한 덩어리로 봤으면 글자 인식의 '날짜가 읽히는 줄'로 채운다
    func testTableRowsAreRecoveredFromOCR() {
        let ocr = ["기말고사 시간표", "12월 7일 (월) 국어", "12월 8일 (화) 수학", "12월 9일 (수) 영어", "시험 범위는 학급 게시판 참고"]
        let got = BrainRules.lines(from: [E(title: "기말고사 시간표", month: 12, day: 7, hour: 0, minute: 0)], ocr: ocr, now: now)
        XCTAssertEqual(got, ["12월 7일 (월) 국어", "12월 8일 (화) 수학", "12월 9일 (수) 영어"])
    }

    func testPosterDateLineIsNotDuplicated() {
        let ocr = ["김민준 · 이서연", "결혼합니다", "2026년 11월 28일 토요일 낮 12시 30분", "더컨벤션 3층 그랜드홀"]
        let got = BrainRules.lines(from: [E(title: "결혼합니다", month: 11, day: 28, hour: 12, minute: 30)], ocr: ocr, now: now)
        XCTAssertEqual(got, ["11월 28일 오후 12시 30분 결혼합니다"])
    }
}

/// 표의 칸에서 일정 줄 만들기 (BrainRules.tableLines)
final class TableLinesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_794_700_000)

    func testDatesAcrossHeaderRow() {
        let grid = [["11월 셋째 주 일정"], ["11월 17일 (화)", "11월 18일 (수)", "11월 19일 (목)"], ["기획 회의", "고객 발표", "팀 워크숍"], ["보고서 마감", "저녁 회식", ""]]
        XCTAssertEqual(BrainRules.tableLines(grid, now: now),
                       ["11월 17일 (화) 기획 회의", "11월 17일 (화) 보고서 마감", "11월 18일 (수) 고객 발표", "11월 18일 (수) 저녁 회식", "11월 19일 (목) 팀 워크숍"])
    }

    func testEmptyDateCellCarriesDown() {
        let grid = [["날짜", "행사", "시간"], ["12월 2일", "학부모 총회", "14:00"], ["", "급식 모니터링", "11:30"], ["12월 9일", "독서 발표회", "10:00"]]
        XCTAssertEqual(BrainRules.tableLines(grid, now: now), ["12월 2일 학부모 총회 14:00", "12월 2일 급식 모니터링 11:30", "12월 9일 독서 발표회 10:00"])
    }

    func testTableWithoutDatesIsLeftAlone() {
        XCTAssertEqual(BrainRules.tableLines([["품목", "수량"], ["두부", "2"], ["대파", "1"]], now: now), [])
    }
}
