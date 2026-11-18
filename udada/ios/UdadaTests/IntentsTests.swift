import XCTest
@testable import Udada

// Siri 동작의 순수한 부분: 한 줄 → 항목, 말로 읽을 문장, 찾을 수 있는 할 일, 잠깐 화면 문.
// 기준: 2026-11-15 (일) 14:20 Asia/Seoul.

final class IntentsTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    private var today: DayKey { DayKey(y: 2026, m: 11, d: 15) }
    private var now: Date { today.date(minute: 14 * 60 + 20, calendar: cal) }

    func testAddEventTomorrow() throws {
        let it = try XCTUnwrap(AddEntryIntent.item(from: "내일 3시 치과", now: now, settings: Settings(), calendar: cal))
        XCTAssertEqual(it.title, "치과")
        XCTAssertEqual(it.day, today.adding(days: 1, calendar: cal))
        XCTAssertEqual(it.time, 900)
        XCTAssertEqual(it.part, .afternoon)
        XCTAssertEqual(AddEntryIntent.placed(it, today: today), "내일 15:00에 넣었어 · 치과")
    }

    func testAddTodoTodayCurrentBand() throws {
        let it = try XCTUnwrap(AddEntryIntent.item(from: "보고서 초안", now: now, settings: Settings(), calendar: cal))
        XCTAssertEqual(it.day, today)
        XCTAssertEqual(it.part, .afternoon)
        XCTAssertNil(it.time)
        XCTAssertEqual(it.duration, Settings().defaultDuration)
        XCTAssertEqual(AddEntryIntent.placed(it, today: today), "오늘 낮에 넣었어 · 보고서 초안")
    }

    func testAddLater() throws {
        let it = try XCTUnwrap(AddEntryIntent.item(from: "나중에 여권 갱신", now: now, settings: Settings(), calendar: cal))
        XCTAssertTrue(it.isLater)
        XCTAssertEqual(AddEntryIntent.placed(it, today: today), "나중에 함에 넣었어 · 여권 갱신")
    }

    func testAddEmpty() {
        XCTAssertNil(AddEntryIntent.item(from: "   ", now: now, settings: Settings(), calendar: cal))
    }

    func testTodaySpoken() {
        var d = AppData()
        for (t, p) in [("메일 답장", Part.evening), ("보고서", .evening), ("택배", .evening), ("빨래", .evening), ("전화", .evening), ("장보기", .evening)] {
            d.add(Item(title: t, day: today, part: p))
        }
        let sheet = DayLogic.sheet(for: today, data: d, now: now, calendar: cal)
        XCTAssertEqual(TodayIntent.spoken(sheet), "오늘 할 일 6개야. 저녁 메일 답장, 보고서, 택배, 빨래, 전화. 외 1개.")
        XCTAssertEqual(TodayIntent.spoken(DayLogic.sheet(for: today, data: AppData(), now: now, calendar: cal)), "남은 할 일은 없어. 쉬어도 돼.")
    }

    func testTaskEntities() {
        var d = AppData()
        d.add(Item(title: "오늘 일", day: today, part: .evening))
        d.add(Item(title: "나중 일"))
        d.add(Item(title: "먼 일", day: today.adding(days: 15, calendar: cal)))
        d.add(Item(title: "지난 일", day: today.adding(days: -1, calendar: cal)))
        d.add(Item(title: "반복", day: today, repeatRule: .daily))
        d.add(Item(title: "걱정", worry: true))
        d.add(Item(title: "끝냄", day: today, done: true))
        d.add(Item(title: "내일 약속", day: today.adding(days: 1, calendar: cal), time: 600))
        let all = TaskEntity.all(in: d, now: now, calendar: cal)
        XCTAssertEqual(all.map(\.title), ["오늘 일", "내일 약속", "나중 일"])
        XCTAssertEqual(all[1].slot, "10:00")
        XCTAssertTrue(TaskEntity.matches(all[1], "내일약속"))
        XCTAssertFalse(TaskEntity.matches(all[1], "치과"))
    }

    func testGate() {
        XCTAssertTrue(GateIntent.shouldGate(gateOn: true, passOpen: false))
        XCTAssertFalse(GateIntent.shouldGate(gateOn: true, passOpen: true))
        XCTAssertFalse(GateIntent.shouldGate(gateOn: false, passOpen: false))
        // 앱 그룹 값을 건드리므로 끝나면 지운다 (UI 테스트의 잠깐 화면이 건너뛰어지지 않게)
        defer { UserDefaults(suiteName: DataFile.group)?.removeObject(forKey: GatePass.key) }
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        GatePass.grant(minutes: 15, now: t)
        XCTAssertTrue(GatePass.isOpen(now: t.addingTimeInterval(14 * 60)))
        XCTAssertFalse(GatePass.isOpen(now: t.addingTimeInterval(16 * 60)))
    }
}
