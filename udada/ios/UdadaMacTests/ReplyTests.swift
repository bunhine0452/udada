import XCTest

// 받은 약속에 답장의 규칙: 제안 읽기 · 내 일정에 대기 · 대신 되는 때 · 규칙 문장 · 모델 문장 검사.
// 기준: 2026-11-18 (수) 14:20 Asia/Seoul.

final class ReplyTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    private var today: DayKey { DayKey(y: 2026, m: 11, d: 18) }
    private var now: Date { today.date(minute: 14 * 60 + 20, calendar: cal) }
    private var fri: DayKey { today.adding(days: 2, calendar: cal) }

    private func offer(_ s: String) -> ReplyOffer? { ReplyRules.offer(from: s, now: now, calendar: cal) }

    func testReadsSocialTimeAsEvening() throws {
        let o = try XCTUnwrap(offer("금요일 7시에 강남역에서 저녁 어때?"))
        XCTAssertEqual(o.day, fri); XCTAssertEqual(o.time, 19 * 60, "만나는 약속의 7시는 저녁 7시")
        XCTAssertEqual(o.title, "강남역에서 저녁"); XCTAssertFalse(o.polite); XCTAssertEqual(o.duration, 90)
        XCTAssertEqual(try XCTUnwrap(offer("내일 3시에 회의 가능하세요?")).time, 15 * 60)
        XCTAssertTrue(try XCTUnwrap(offer("내일 3시에 회의 가능하세요?")).polite)
        XCTAssertEqual(try XCTUnwrap(offer("토요일 아침 9시에 등산 갈래?")).time, 9 * 60, "아침이라고 했으면 그대로")
        XCTAssertEqual(try XCTUnwrap(offer("토요일 저녁에 볼래?")).time, 19 * 60, "시각 없이 저녁이면 19시")
    }

    func testNotAnOffer() {
        XCTAssertNil(offer("ㅋㅋㅋ 어제 진짜 웃겼어"))
        XCTAssertNil(offer("내일 3시 치과"), "묻는 말이 없으면 답장할 것이 아니다")
        XCTAssertNil(offer("월세 오르면 어떡하지"))
        XCTAssertNil(offer("요즘 어때?"), "때가 없다")
    }

    func testFreeSlotGetsAcceptAndDecline() throws {
        let c = ReplyRules.check(try XCTUnwrap(offer("금요일 7시에 강남역에서 저녁 어때?")), data: AppData(), now: now, calendar: cal)
        XCTAssertTrue(c.free); XCTAssertNil(c.alt)
        XCTAssertEqual(ReplyRules.verdict(c), "금요일 19:00 — 비어 있어.")
        let d = ReplyRules.drafts(c)
        XCTAssertEqual(d.map(\.kind), [.accept, .decline])
        XCTAssertEqual(d[0].text, "좋아! 금요일 7시에 봐.")
        let it = try XCTUnwrap(ReplyRules.item(for: .accept, check: c, parts: DayParts(), created: now))
        XCTAssertEqual(it.day, fri); XCTAssertEqual(it.time, 19 * 60); XCTAssertEqual(it.part, .evening); XCTAssertEqual(it.title, "강남역에서 저녁")
        XCTAssertNil(ReplyRules.item(for: .decline, check: c, parts: DayParts(), created: now))
    }

    func testClashOffersNearestFreeTime() throws {
        var data = AppData()
        data.items = [Item(title: "치과", day: fri, part: .evening, time: 18 * 60 + 30, duration: 60), Item(title: "장보기", day: fri, part: .evening, duration: 40)]
        let c = ReplyRules.check(try XCTUnwrap(offer("금요일 7시에 저녁 어떠세요?")), data: data, now: now, calendar: cal)
        XCTAssertEqual(c.clashes.map(\.title), ["치과"], "할 일(장보기)은 겹침이 아니다")
        XCTAssertEqual(c.alt, .init(day: fri, time: 19 * 60 + 30), "치과가 끝나는 7시 반부터 된다")
        XCTAssertEqual(ReplyRules.verdict(c), "금요일 19:00엔 ‘치과’(18:30–19:30) 일정이 있어.")
        let d = ReplyRules.drafts(c)
        XCTAssertEqual(d.map(\.kind), [.alternative, .decline])
        XCTAssertEqual(d[0].text, "금요일 7시에는 일정이 있어서요, 7시 반은 어떠세요?")
        XCTAssertEqual(ReplyRules.item(for: .alternative, check: c, parts: DayParts(), created: now)?.time, 19 * 60 + 30)
    }

    func testClockAndDayWords() {
        XCTAssertEqual(ReplyRules.clockWord(19 * 60), "7시"); XCTAssertEqual(ReplyRules.clockWord(19 * 60 + 30), "7시 반")
        XCTAssertEqual(ReplyRules.clockWord(10 * 60), "오전 10시"); XCTAssertEqual(ReplyRules.clockWord(12 * 60), "12시")
        XCTAssertEqual(ReplyRules.dayWord(today, today: today), "오늘"); XCTAssertEqual(ReplyRules.dayWord(fri, today: today), "금요일")
    }

    /// 모델이 쓴 문장: 다른 시각을 말하거나 · 수락인데 거절 말이 섞이거나 · 말투가 어긋나면 안 받는다
    func testVetRejectsWrongFacts() throws {
        let free = ReplyRules.check(try XCTUnwrap(offer("금요일 7시에 강남역에서 저녁 어때?")), data: AppData(), now: now, calendar: cal)
        XCTAssertEqual(ReplyRules.vet("좋아, 금요일 7시에 강남역에서 보자!", kind: .accept, check: free), "좋아, 금요일 7시에 강남역에서 보자!")
        XCTAssertNil(ReplyRules.vet("좋아, 금요일 8시에 보자!", kind: .accept, check: free), "정해 준 시각이 아니다")
        XCTAssertNil(ReplyRules.vet("좋아요, 금요일 7시에 봬요.", kind: .accept, check: free), "반말로 온 글에 존댓말")
        XCTAssertNil(ReplyRules.vet("미안, 7시는 어려울 것 같아.", kind: .accept, check: free), "수락이 아니다")
        XCTAssertNotNil(ReplyRules.vet("미안, 금요일은 어려울 것 같아. 다음에 보자!", kind: .decline, check: free))
        XCTAssertNil(ReplyRules.vet("Sure! see you", kind: .accept, check: free))
        XCTAssertNil(ReplyRules.vet("이번에는 어렵다.", kind: .decline, check: free), "딱 자르는 거절은 안 받는다")
        var data = AppData()
        data.items = [Item(title: "치과", day: fri, part: .evening, time: 18 * 60 + 30, duration: 60)]
        let busy = ReplyRules.check(try XCTUnwrap(offer("금요일 7시에 강남역에서 저녁 어때?")), data: data, now: now, calendar: cal)
        XCTAssertNil(ReplyRules.vet("좋아, 금요일 7시에 보자!", kind: .accept, check: busy), "겹치는데 수락은 없다")
        XCTAssertNotNil(ReplyRules.vet("7시엔 일정이 있어서, 7시 반은 어때?", kind: .alternative, check: busy))
        XCTAssertNil(ReplyRules.vet("7시엔 일정이 있어서, 9시는 어때?", kind: .alternative, check: busy), "대신 되는 때가 아니다")
    }
}
