import XCTest

// 한 주 풀기의 규칙: 한 주의 짐을 펼치고 · 말을 읽고 · 모델이 고른 번호를 기록에 대어 놓고 · 모자란 만큼 채운다.
// 기준: 2026-11-16 (월) 10:00 Asia/Seoul — 오늘 아침 칸은 2시간 남았다.

final class ReplanTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    private var today: DayKey { DayKey(y: 2026, m: 11, d: 16) }
    private var now: Date { today.date(minute: 600, calendar: cal) }

    /// 오늘 낮: 약속 3시간 30분 → 빈 2시간 30분에 할 일 3시간 20분 (50분 넘침)
    private func busy() -> AppData {
        var d = AppData()
        d.items = [
            Item(title: "팀 회의", day: today, part: .afternoon, time: 840, duration: 120),
            Item(title: "고객 미팅", day: today, part: .afternoon, time: 960, duration: 90),
            Item(title: "보고서 초안", day: today, part: .afternoon, duration: 90),
            Item(title: "메일 답장", day: today, part: .afternoon, duration: 30),
            Item(title: "자료 조사", day: today, part: .afternoon, duration: 60),
            Item(title: "택배 보내기", day: today, part: .afternoon, duration: 20),
            Item(title: "장보기", day: today.adding(days: 1, calendar: cal), part: .evening, duration: 40),
        ]
        return d
    }
    private func snap(_ d: AppData) -> ReplanSnapshot { ReplanRules.snapshot(data: d, now: now, calendar: cal) }

    func testSnapshotCountsRealFreeTime() {
        let s = snap(busy())
        let noon = s.cell(today, .afternoon)!
        XCTAssertEqual(noon.free, 150); XCTAssertEqual(noon.planned, 200); XCTAssertEqual(noon.overflow, 50)
        XCTAssertEqual(s.cell(today, .morning)?.free, 120, "오늘 아침은 지금(10시)부터")
        XCTAssertEqual(s.todos.map(\.entry.title), ["보고서 초안", "메일 답장", "자료 조사", "택배 보내기", "장보기"], "약속은 옮길 일이 아니다")
        XCTAssertEqual(s.todos.map(\.n), [1, 2, 3, 4, 5])
    }

    func testReadsDayClearAndKeep() {
        let s = snap(busy())
        XCTAssertTrue(ReplanRules.looksLikeReplan("이번 주 너무 빡빡해"))
        XCTAssertFalse(ReplanRules.looksLikeReplan("월세 오르면 어떡하지"), "걱정은 풀기가 아니다")
        XCTAssertFalse(ReplanRules.looksLikeReplan("내일 3시 치과"))
        var a = ReplanRules.read("오늘 낮이 넘쳐. 보고서 초안은 오늘 꼭 해야 해", snapshot: s)
        XCTAssertEqual(a.focus, [today]); XCTAssertFalse(a.clear); XCTAssertEqual(a.keep, [1])
        a = ReplanRules.read("수요일은 비워 줘", snapshot: s)
        XCTAssertEqual(a.focus, [today.adding(days: 2, calendar: cal)]); XCTAssertTrue(a.clear)
        XCTAssertEqual(s.day(named: "내일"), today.adding(days: 1, calendar: cal))
        XCTAssertEqual(s.day(named: "목요일"), today.adding(days: 3, calendar: cal))
        XCTAssertNil(s.day(named: "언젠가"))
    }

    /// 규칙만으로: 넘침이 풀리고, 받는 칸은 넘치지 않고, 지키라는 일은 그대로
    func testFillRelievesWithoutOverflowingTarget() {
        let s = snap(busy())
        let ask = ReplanRules.read("오늘 너무 빡빡해. 보고서 초안은 꼭 해야 해", snapshot: s)
        let moves = ReplanRules.fill(snapshot: s, ask: ask)
        XCTAssertFalse(moves.isEmpty)
        XCTAssertFalse(moves.contains { $0.todo.entry.title == "보고서 초안" }, "지키라는 일은 안 옮긴다")
        let after = ReplanRules.apply(moves, to: s.cells)
        XCTAssertEqual(ReplanRules.overflow(after, ask: ask), 0)
        XCTAssertTrue(after.allSatisfy { $0.overflow == 0 }, "옮겨 받은 칸이 넘치면 안 된다")
        XCTAssertEqual(moves.first?.why, "오늘 낮이 50분 넘쳐서")
    }

    /// 모델이 고른 번호: 없는 번호 · 넘치지 않는 칸의 일 · 지키라는 일은 버리고, 넘침이 풀리면 더 안 옮긴다
    func testChooseChecksModelPicks() {
        let s = snap(busy())
        let ask = ReplanRules.read("오늘 낮이 넘쳐. 메일 답장은 그대로 둬", snapshot: s)
        let moves = ReplanRules.choose(later: [99, 5, 2, 3, 4], snapshot: s, ask: ask)
        XCTAssertEqual(moves.map(\.todo.entry.title), ["자료 조사"], "99번은 없고, 5번은 넘치지 않는 칸이고, 2번은 지키라고 했고, 3번으로 풀렸으니 4번은 안 옮긴다")
        XCTAssertTrue(moves.allSatisfy(\.fromAI))
        XCTAssertEqual(moves.first?.day, today); XCTAssertEqual(moves.first?.part, .evening, "가장 가까운 넉넉한 칸: 오늘 저녁")
    }

    func testClearMovesEverythingOutOfThatDay() {
        var d = AppData()
        let wed = today.adding(days: 2, calendar: cal)
        d.items = [Item(title: "발표 자료", day: wed, part: .morning, duration: 90), Item(title: "은행 가기", day: wed, part: .afternoon, duration: 40),
                   Item(title: "오늘의 하나", day: wed, part: .evening, duration: 30)]
        d.items[2].pinned = true
        let s = snap(d)
        let ask = ReplanRules.read("수요일은 비워 줘", snapshot: s)
        let moves = ReplanRules.fill(snapshot: s, ask: ask)
        XCTAssertEqual(Set(moves.map(\.todo.entry.title)), ["발표 자료", "은행 가기"], "오늘의 하나는 안 옮긴다")
        XCTAssertTrue(moves.allSatisfy { $0.day != wed }, "비우려는 날로는 안 옮긴다")
    }

    func testNothingToDoWhenNothingOverflows() {
        var d = AppData()
        d.items = [Item(title: "메일 답장", day: today, part: .afternoon, duration: 20)]
        let s = snap(d)
        let ask = ReplanRules.read("이번 주 빡빡한가?", snapshot: s)
        XCTAssertTrue(ReplanRules.fill(snapshot: s, ask: ask).isEmpty)
        let r = ReplanResult(snapshot: s, ask: ask, moves: [], fromAI: false)
        XCTAssertEqual(ReplanRules.headline(r), "넘치는 칸이 없어. 이대로 괜찮아.")
    }

    /// 이미 지난 칸에 남은 일은 넘침으로 세지 않는다
    func testGoneBandIsNotOverflow() {
        var d = AppData()
        d.items = [Item(title: "물 한 잔", day: today, part: .morning, duration: 30)]
        let late = today.date(minute: 17 * 60, calendar: cal)
        let s = ReplanRules.snapshot(data: d, now: late, calendar: cal)
        XCTAssertEqual(s.cell(today, .morning)?.gone, true)
        XCTAssertEqual(s.overflow, 0)
    }

    /// 꺼 둔 선택지는 처음에 고른 것에 들지 않고, 옮긴 뒤 셈에도 안 든다
    func testOptionalMovesAreOffByDefault() {
        let s = snap(busy())
        let ask = ReplanAsk()
        var moves = ReplanRules.fill(snapshot: s, ask: ask)
        XCTAssertGreaterThan(moves.count, 0)
        moves[0].optional = true
        let r = ReplanResult(snapshot: s, ask: ask, moves: moves, fromAI: false)
        XCTAssertFalse(r.defaults.contains(moves[0].id))
        XCTAssertEqual(r.after().first { $0.day == today && $0.part == .afternoon }?.planned, 200 - moves.dropFirst().filter { $0.todo.entry.day == today && $0.todo.entry.part == .afternoon }.reduce(0) { $0 + $1.todo.entry.duration })
    }
}
