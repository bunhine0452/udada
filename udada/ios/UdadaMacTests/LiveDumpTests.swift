import XCTest

// 말하는 동안 카드가 떨어지는 쏟아내기의 규칙: 말이 끝난 조각만 카드로, 받아쓰기가 글을 고쳐도 같은 조각의 카드는 그대로.

final class LiveDumpTests: XCTestCase {
    private func make(_ s: String) -> DumpSuggestion { DumpSuggestion(text: s, bin: .date, reason: "", fromAI: false) }

    func testOnlyFinishedClausesBecomeCards() {
        var c = LiveDump.cut("엄마한테 전화해야 되고 보고서도", open: true)
        XCTAssertEqual(c.settled.count, 1, "말하는 중인 끝 조각은 아직 카드가 아니다")
        XCTAssertEqual(c.pending, "보고서도")
        c = LiveDump.cut("엄마한테 전화해야 되고 보고서도 써야 되는데 월세 오르면", open: true)
        XCTAssertEqual(c.settled.count, 2)
        XCTAssertEqual(c.pending, "월세 오르면")
    }

    func testEverythingSettlesWhenSpeechStops() {
        let c = LiveDump.cut("엄마한테 전화해야 되고 보고서도 써야 되는데 월세 오르면 어떡하지", open: false)
        XCTAssertEqual(c.settled.count, 3)
        XCTAssertEqual(c.pending, "")
        XCTAssertEqual(LiveDump.cut("", open: true).settled, [])
    }

    /// 멈췄다 다시 말하면 줄이 바뀐다 — 앞 줄은 끝난 말이다
    func testClosedLineIsSettled() {
        let c = LiveDump.cut("장보기\n택배", open: true)
        XCTAssertEqual(c.settled, ["장보기"])
        XCTAssertEqual(c.pending, "택배")
        XCTAssertEqual(LiveDump.cut("장보기\n", open: true).settled, ["장보기"])
    }

    func testReconcileKeepsCardsAndTheirRefinement() {
        var cards = LiveDump.reconcile([], settled: ["가", "나"], make: make)
        cards[0].refined = true
        cards[0].s.bin = .now
        let ids = cards.map(\.id)
        // 조각이 하나 더 끝났다: 앞의 둘은 그대로
        var next = LiveDump.reconcile(cards, settled: ["가", "나", "다"], make: make)
        XCTAssertEqual(next.prefix(2).map(\.id), ids)
        XCTAssertTrue(next[0].refined); XCTAssertEqual(next[0].s.bin, .now)
        XCTAssertEqual(next[2].s.piece, 2)
        // 받아쓰기가 둘째를 고쳐 썼다: 그 카드만 새로
        next = LiveDump.reconcile(next, settled: ["가", "나나", "다"], make: make)
        XCTAssertEqual(next[0].id, ids[0]); XCTAssertNotEqual(next[1].id, ids[1])
        XCTAssertEqual(next[1].source, "나나"); XCTAssertFalse(next[1].refined)
        // 앞에 조각이 끼어들어 자리가 밀려도 같은 조각의 카드는 따라온다
        next = LiveDump.reconcile(cards, settled: ["새", "가", "나"], make: make)
        XCTAssertEqual(next[1].id, ids[0]); XCTAssertEqual(next[2].id, ids[1])
        // 글이 줄면 카드도 준다
        XCTAssertEqual(LiveDump.reconcile(cards, settled: ["가"], make: make).count, 1)
    }
}
