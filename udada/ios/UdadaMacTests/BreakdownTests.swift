import XCTest

/// 쪼개기의 규칙 쪽: 이름 떼기 · 모델이 쓴 걸음 검사 · 날에 놓기.
final class BreakdownTests: XCTestCase {
    private let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Seoul")!; return c }()
    private var now: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10))! } // 월요일 10시
    private var today: DayKey { DayKey(now, calendar: cal) }

    private func offsets(_ n: Int, _ pace: BreakPace, due: Int?) -> [Int] {
        let steps = (0..<n).map { "걸음 \($0)" }
        return BreakRules.place(steps, pace: pace, today: today, due: due.map { today.adding(days: $0, calendar: cal) },
                                nowPart: .morning, part: .evening, calendar: cal).map { today.days(to: $0.day, calendar: cal) }
    }

    func testSubjectDropsWhenWords() {
        XCTAssertEqual(BreakRules.subject("금요일까지 발표 준비", now: now, calendar: cal), "발표 준비")
        XCTAssertEqual(BreakRules.subject("이사 준비", now: now, calendar: cal), "이사 준비")
    }

    func testCleanKeepsGoodStepsInOrder() {
        let got = BreakRules.clean(["1. 노트북 종류 조사하기", "예산 범위 정하기", "모델 두 가지 비교하기", "구매하기"], subject: "노트북 새로 사기")
        XCTAssertEqual(got, ["노트북 종류 조사하기", "예산 범위 정하기", "모델 두 가지 비교하기", "구매하기"])
    }

    func testCleanDropsHollowDuplicateAndDatedSteps() {
        let got = BreakRules.clean(["서류 준비하기", "기관 방문하기", "내일 신청서 내기", "서류 준비하기", "갱신 완료하기", "준비하기", "수수료 내기"], subject: "운전면허 갱신")
        XCTAssertEqual(got, ["서류 준비하기", "기관 방문하기", "수수료 내기"])
    }

    func testCleanFixesDoubleEndingAndRejectsAdvice() {
        let got = BreakRules.clean(["새 집 찾기하기", "주식 투자 방법 조사하기", "짐 싸기 시작", "주소 옮기기"], subject: "이사")
        XCTAssertEqual(got, ["새 집 찾기", "짐 싸기 시작", "주소 옮기기"])
    }

    func testWhenWordInTheNameIsNotADate() {
        let got = BreakRules.clean(["주말농장 정보 찾아 두기", "신청 양식 작성하기", "조건 확인하기", "신청하기"], subject: "주말농장 신청")
        XCTAssertEqual(got, ["주말농장 정보 찾아 두기", "신청 양식 작성하기", "조건 확인하기"])
    }

    func testCleanNeedsThreeSteps() {
        XCTAssertNil(BreakRules.clean(["자료 모으기", "완료하기", "발표 준비"], subject: "발표 준비"))
        XCTAssertNil(BreakRules.clean(["하나 적기", "둘 적기", "셋 적기"], subject: "그냥 사라지고 싶다"))
    }

    func testFallbackUsesKnownStepsOrGeneric() {
        XCTAssertEqual(BreakRules.fallback(for: "분기 보고서 쓰기").first, "자료 모아 한곳에 두기")
        XCTAssertNil(BreakRules.knownSteps(for: "강아지 예방접종"))
        XCTAssertEqual(BreakRules.fallback(for: "강아지 예방접종").count, 4)
    }

    func testSpreadEndsTheDayBeforeDue() {
        XCTAssertEqual(offsets(4, .spread, due: 4), [0, 1, 2, 3])   // 월 → 금 마감: 월·화·수·목
        XCTAssertEqual(offsets(3, .spread, due: 10), [0, 5, 9])
        XCTAssertEqual(offsets(4, .spread, due: 2), [0, 0, 1, 1])  // 날이 모자라면 하루에 둘
        XCTAssertEqual(offsets(1, .spread, due: 7), [0])
    }

    func testNoStepPassesAFutureDeadline() {
        for due in 2...15 { for n in 1...5 { for pace in BreakPace.allCases {
            XCTAssertLessThanOrEqual(offsets(n, pace, due: due).max()!, due - 1, "\(pace) n=\(n) due=\(due)")
        } } }
    }

    func testDailyAndTodayPaces() {
        XCTAssertEqual(offsets(4, .daily, due: nil), [0, 1, 2, 3])
        XCTAssertEqual(offsets(4, .daily, due: 3), [0, 1, 2, 2])
        XCTAssertEqual(offsets(3, .daily, due: 0), [0, 1, 2])      // 오늘에 들어가 있던 큰일: 고르면 날을 넘겨 이어진다
        XCTAssertEqual(offsets(3, .today, due: 9), [0, 0, 0])
    }

    func testPacesByDeadline() {
        XCTAssertEqual(BreakRules.paces(today: today, due: nil, calendar: cal), [.daily, .today])
        XCTAssertEqual(BreakRules.paces(today: today, due: today, calendar: cal), [.today, .daily])
        XCTAssertEqual(BreakRules.paces(today: today, due: today.adding(days: 4, calendar: cal), calendar: cal), [.spread, .daily, .today])
    }

    func testPartsAndItems() {
        let placed = BreakRules.place(["가", "나"], pace: .daily, today: today, due: nil, nowPart: .morning, part: .evening, calendar: cal)
        XCTAssertEqual(placed.map(\.part), [.morning, .evening])   // 오늘은 지금 띠, 다른 날은 큰일의 띠
        let items = BreakRules.items(placed, subject: "발표 준비", duration: 30, now: now)
        XCTAssertEqual(items.map(\.title), ["가", "나"])
        XCTAssertEqual(items[1].day, today.adding(days: 1, calendar: cal))
        XCTAssertEqual(items[0].note, "‘발표 준비’에서 나눈 걸음")
        XCTAssertLessThan(items[0].created, items[1].created)
    }
}
