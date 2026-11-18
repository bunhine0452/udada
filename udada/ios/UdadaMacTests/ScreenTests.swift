import XCTest

// 화면 그대로: 글자 조각의 자리로 받은 말을 가르고 가장 최근 제안을 찾는다.
// 기준: 2026-11-18 (수) 14:20 Asia/Seoul.

final class ScreenTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    private var today: DayKey { DayKey(y: 2026, m: 11, d: 18) }
    private var now: Date { today.date(minute: 14 * 60 + 20, calendar: cal) }

    private func theirs(_ t: String, _ top: Double) -> ScreenPiece { ScreenPiece(text: t, minX: 0.16, maxX: 0.16 + min(0.6, Double(t.count) * 0.035), top: top) }
    private func mine(_ t: String, _ top: Double) -> ScreenPiece { ScreenPiece(text: t, minX: 0.95 - min(0.5, Double(t.count) * 0.035), maxX: 0.95, top: top) }

    func testFindsTheOfferAmongBubbles() {
        let pieces = [
            ScreenPiece(text: "민지", minX: 0.4, maxX: 0.6, top: 0.06),          // 방 이름
            ScreenPiece(text: "2026년 11월 18일 수요일", minX: 0.3, maxX: 0.7, top: 0.14),
            theirs("요즘 어떻게 지내", 0.2), ScreenPiece(text: "오후 2:10", minX: 0.5, maxX: 0.6, top: 0.22),
            mine("그냥 그래 ㅋㅋ", 0.3),
            theirs("금요일 7시에 강남역에서 저녁 어때?", 0.4), ScreenPiece(text: "오후 2:12", minX: 0.75, maxX: 0.85, top: 0.42),
            ScreenPiece(text: "메시지 입력", minX: 0.15, maxX: 0.4, top: 0.95),
        ]
        guard case .offer(let m) = ScreenRules.read(pieces, now: now, calendar: cal) else { return XCTFail("제안을 못 찾음") }
        let o = ReplyRules.offer(from: m, now: now, calendar: cal)
        XCTAssertEqual(o?.day, DayKey(y: 2026, m: 11, d: 20))
        XCTAssertEqual(o?.time, 19 * 60, "보낸 시각 도장(오후 2:12)을 약속 시각으로 읽지 않는다")
    }

    func testMyOwnQuestionIsNotAnOffer() {
        let pieces = [theirs("주말에 뭐 해", 0.3), mine("토요일 3시에 영화 어때?", 0.4)]
        if case .offer = ScreenRules.read(pieces, now: now, calendar: cal) { XCTFail("내가 보낸 제안에 답장을 쓰지 않는다") }
    }

    /// 사용자가 보낸 실제 화면(나와의 채팅): 파일 카드와 날짜 가름줄은 일정이 아니고, 내가 적어 둔 세 줄만 일정이다.
    func testSelfChatWithFileCards() {
        func p(_ t: String, _ top: Double, _ a: Double, _ b: Double) -> ScreenPiece { ScreenPiece(text: t, minX: a, maxX: b, top: top) }
        let pieces = [
            p("22:58 A", 0.03, 0.11, 0.29), p("01 5G", 0.03, 0.68, 0.81),
            p("사업자등록 신청서.pdf", 0.31, 0.29, 0.64), p("유효기간 2026. 11. 27.", 0.34, 0.30, 0.64), p("용량 7.7 MB", 0.36, 0.30, 0.47),
            p("이오름 통신판매업 신고증.pdf", 0.41, 0.29, 0.74), p("유효기간 ~2026. 11. 27.", 0.44, 0.30, 0.64), p("용량 344 KB", 0.47, 0.30, 0.49),
            p("사업자등록증.pdf", 0.52, 0.29, 0.56), p("유효기간 ~2026. 11. 27.", 0.54, 0.30, 0.64), p("용량 124 KB", 0.57, 0.30, 0.48),
            p("10:16", 0.70, 0.20, 0.27), p("2026년 11월 18일 수요일>", 0.74, 0.33, 0.68),
            p("내일 밥먹기", 0.79, 0.77, 0.95), p("11월 20일 계획1", 0.83, 0.70, 0.95), p("22:44", 0.85, 0.59, 0.67),
            p("11월21일 오후3시에 강남역에서 만나", 0.88, 0.40, 0.95), p("22:45", 0.90, 0.30, 0.38),
            p("메시지 입력", 0.93, 0.16, 0.34), p("새익 추가해요", 0.98, 0.32, 0.52),
        ]
        guard case .lines(let l) = ScreenRules.read(pieces, now: now, calendar: cal) else { return XCTFail("줄을 못 뽑음") }
        XCTAssertEqual(l, ["내일 밥먹기", "11월 20일 계획1", "11월21일 오후3시에 강남역에서 만나"])
        let items = ScreenRules.items(from: l, data: AppData(), now: now, calendar: cal)
        XCTAssertEqual(items.map(\.day), [DayKey(y: 2026, m: 11, d: 19), DayKey(y: 2026, m: 11, d: 20), DayKey(y: 2026, m: 11, d: 21)])
        XCTAssertEqual(items.map(\.time), [nil, nil, 15 * 60])
        XCTAssertEqual(items[2].title, "강남역에서 만나")
        // 두 번 공유해도 겹쳐 넣지 않는다
        var d = AppData(); d.items = items
        XCTAssertTrue(ScreenRules.items(from: l, data: d, now: now, calendar: cal).isEmpty)
    }

    func testKeepDropsPastAndNameless() {
        let l = ScreenRules.keep(["2026.06.17 신규가입", "11월 25일", "11월 25일 건강검진", "용량 7.7 MB"], now: now, calendar: cal)
        XCTAssertEqual(l, ["11월 25일 건강검진"])
    }

    func testLatestOfferWins() {
        let pieces = [theirs("목요일 6시에 저녁 어때?", 0.2), mine("목요일은 안 돼", 0.3), theirs("그럼 토요일 1시에 점심 어때?", 0.4)]
        guard case .offer(let m) = ScreenRules.read(pieces, now: now, calendar: cal) else { return XCTFail() }
        XCTAssertEqual(ReplyRules.offer(from: m, now: now, calendar: cal)?.day, DayKey(y: 2026, m: 11, d: 21))
    }

    func testDayAndTimeInTwoBubbles() {
        let pieces = [theirs("이번 주 금요일에 시간 돼?", 0.3), theirs("7시에 홍대 어때", 0.36)]
        guard case .offer(let m) = ScreenRules.read(pieces, now: now, calendar: cal) else { return XCTFail() }
        let o = ReplyRules.offer(from: m, now: now, calendar: cal)
        XCTAssertEqual(o?.day, DayKey(y: 2026, m: 11, d: 20))
        XCTAssertEqual(o?.time, 19 * 60)
    }

    /// 대화가 아닌 화면(예약 안내)은 챙길 줄로
    func testNoticeBecomesLines() {
        let pieces = [
            ScreenPiece(text: "[서울밝은치과] 예약 안내", minX: 0.1, maxX: 0.7, top: 0.2),
            ScreenPiece(text: "11월 20일(금) 오후 2시 스케일링 예약입니다.", minX: 0.1, maxX: 0.85, top: 0.26),
            ScreenPiece(text: "변경은 02-123-4567", minX: 0.1, maxX: 0.6, top: 0.32),
        ]
        guard case .lines(let l) = ScreenRules.read(pieces, now: now, calendar: cal) else { return XCTFail("줄을 못 뽑음") }
        let p = Parser.parse(l[0], now: now, calendar: cal)
        XCTAssertEqual(p.day, DayKey(y: 2026, m: 11, d: 20))
        XCTAssertEqual(p.time, 14 * 60)
    }

    func testNoticeSaysWhenItClashes() {
        var d = AppData()
        d.items = [Item(title: "팀 회의", day: DayKey(y: 2026, m: 11, d: 20), time: 14 * 60, duration: 60)]
        let lines = CaptureRules.lines("[서울밝은치과] 11월 20일(금) 오후 2시 스케일링 예약입니다.", now: now, calendar: cal)
        let n = ScreenRules.notice(lines, data: d, now: now, calendar: cal)
        XCTAssertTrue(n.contains("‘팀 회의’와 겹쳐"), n)
        XCTAssertFalse(ScreenRules.notice(lines, data: AppData(), now: now, calendar: cal).contains("겹쳐"))
    }

    func testTextGoesTheSameWay() {
        if case .offer = ScreenRules.read(text: "내일 3시에 커피 어때?", now: now, calendar: cal) {} else { XCTFail() }
        XCTAssertEqual(ScreenRules.read(text: "ㅋㅋㅋㅋ 진짜?", now: now, calendar: cal), .nothing)
    }

    func testJunkIsNotReceived() {
        XCTAssertTrue(ScreenRules.isJunk("[Web발신] 인증번호 482913 을 입력해 주세요"))
        XCTAssertTrue(ScreenRules.isJunk("(광고) 11월 20일까지 전 품목 할인 무료수신거부 080"))
        XCTAssertTrue(ScreenRules.isJunk("[OO카드] 승인 12,000원 일시불 11/18 14:20"))
        XCTAssertFalse(ScreenRules.isJunk("[서울밝은치과] 11월 20일(금) 오후 2시 스케일링 예약입니다."))
    }
}
