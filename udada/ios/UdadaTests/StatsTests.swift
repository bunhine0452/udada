import XCTest
@testable import Udada

// 기록 탭 숫자 (Udada/Records/Stats.swift). 기준 날은 2026-11-15 (일) Asia/Seoul.
// 아래 '공통 사례'는 macOS 하네스가 그대로 잘라 써서 같은 목록을 돌린다.

final class StatsTests: XCTestCase {
    func testCases() {
        statsCases { ok, message, line in XCTAssertTrue(ok, message, line: line) }
    }
}

// MARK: - 공통 사례 (하네스와 XCTest 가 같은 목록을 쓴다)

fileprivate let seoul: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Seoul")!
    c.locale = Locale(identifier: "ko_KR")
    return c
}()

fileprivate func k(_ s: String) -> DayKey { DayKey(string: s)! }

/// "2026-11-10 09:30" → 서울 시각
fileprivate func at(_ s: String) -> Date {
    let f = DateFormatter()
    f.calendar = seoul
    f.timeZone = seoul.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}

fileprivate func doneItem(_ title: String, _ when: String, part: Part = .afternoon, time: Int? = nil) -> Item {
    var it = Item(title: title, day: k(String(when.prefix(10))), part: part, time: time)
    it.done = true
    it.doneAt = at(when)
    return it
}

fileprivate func statsCases(_ report: (Bool, String, UInt) -> Void) {
    func eq<T: Equatable>(_ got: T, _ want: T, _ what: String, line: UInt = #line) {
        report(got == want, "\(what): got \(got), want \(want)", line)
    }
    func near(_ got: Double?, _ want: Double, _ what: String, line: UInt = #line) {
        report(got.map { abs($0 - want) < 1e-9 } ?? false, "\(what): got \(String(describing: got)), want \(want)", line)
    }
    let today = k("2026-11-15") // 일요일

    // 1. 새 사용자: 빈 상태
    do {
        let s = RecordStats.compute(AppData(), today: today, calendar: seoul)
        eq(s.isEmpty, true, "empty.isEmpty")
        eq(s.week.done, 0, "empty.done")
        eq(s.week.rate == nil, true, "empty.rate nil")
        eq(s.grid.count, 84, "empty.grid count")
        eq(s.history.isEmpty, true, "empty.history")
        eq(s.reflection, RecordStats.emptyText, "empty.reflection")
        eq(s.focusAdvice == nil, true, "empty.focusAdvice")
    }

    // 2. 주 경계: 월요일 시작 / 일요일 시작
    do {
        var d = AppData()
        let s = RecordStats.compute(d, today: today, calendar: seoul)
        eq(s.week.start, k("2026-11-09"), "mon.start")
        eq(s.week.end, k("2026-11-15"), "mon.end")
        eq(s.prev.start, k("2026-11-02"), "mon.prev.start")
        eq(s.weekRange, "11월 9일–15일", "mon.range")
        d.settings.mondayFirst = false
        let t = RecordStats.compute(d, today: today, calendar: seoul)
        eq(t.week.start, k("2026-11-15"), "sun.start")
        eq(t.week.end, k("2026-11-21"), "sun.end")
        eq(RecordStats.range(k("2026-10-27"), k("2026-11-02")), "10월 27일–11월 2일", "range across months")
    }

    // 3. 끝낸 일: doneAt 기준, 지난주와 따로
    do {
        var d = AppData()
        d.items = [
            doneItem("a", "2026-11-10 09:00", part: .morning),
            doneItem("b", "2026-11-15 23:59", part: .evening),
            doneItem("c", "2026-11-08 20:00"),         // 지난주 일요일
            doneItem("d", "2026-10-01 10:00"),         // 오래전
        ]
        var noDate = Item(title: "doneAt 없음", day: k("2026-11-12")); noDate.done = true
        d.items.append(noDate)
        let s = RecordStats.compute(d, today: today, calendar: seoul)
        eq(s.week.done, 2, "done.week")
        eq(s.prev.done, 1, "done.prev")
        eq(s.isEmpty, false, "done.notEmpty")
        eq(s.week.byPart[.morning] ?? 0, 1, "done.byPart morning")
        eq(s.week.byPart[.evening] ?? 0, 1, "done.byPart evening")
        eq(s.week.byPart[.afternoon] ?? 0, 0, "done.byPart afternoon")
    }

    // 4. 끝낸 비율: 반복·약속·걱정·떼어 낸 반복 하루치는 '안 끝냄'에서 뺀다. 떼어 낸 하루치를 끝내면 셈.
    do {
        var d = AppData()
        d.items = [
            doneItem("a", "2026-11-11 10:00"),
            Item(title: "열린 할 일", day: k("2026-11-12")),
            Item(title: "열린 할 일 2", day: k("2026-11-15"), part: .evening),
            Item(title: "지난 약속", day: k("2026-11-12"), time: 900),
            Item(title: "반복 원본", day: k("2026-11-01"), repeatRule: .daily),
            Item(title: "걱정", day: k("2026-11-12"), worry: true),
            Item(title: "나중에"),
            Item(title: "다음 주", day: k("2026-11-16")),
        ]
        var occOpen = Item(title: "물", day: k("2026-11-13")); occOpen.seriesID = UUID(); occOpen.occurrence = k("2026-11-13")
        var occDone = doneItem("물", "2026-11-14 08:00", part: .morning); occDone.seriesID = occOpen.seriesID
        d.items += [occOpen, occDone]
        let s = RecordStats.compute(d, today: today, calendar: seoul)
        eq(s.week.done, 2, "rate.done incl. repeat")
        eq(s.week.open, 2, "rate.open")
        near(s.week.rate, 0.5, "rate")
        eq(RecordStats.percent(s.week.rate!), "50%", "rate.percent")
    }

    // 5. 일요일 시작 주에서는 아직 안 온 날의 열린 일을 세지 않는다
    do {
        var d = AppData()
        d.settings.mondayFirst = false
        d.items = [Item(title: "오늘", day: k("2026-11-15")), Item(title: "수요일", day: k("2026-11-18"))]
        let s = RecordStats.compute(d, today: today, calendar: seoul)
        eq(s.week.open, 1, "future open excluded")
    }

    // 6. 닫기 · 식히기 · 비우기
    do {
        var d = AppData()
        d.closes = [
            CloseLog(day: k("2026-11-10"), at: at("2026-11-10 21:00"), done: 3, tomorrow: 1, later: 0, dropped: 0),
            CloseLog(day: k("2026-11-14"), at: at("2026-11-14 21:00"), done: 2, tomorrow: 0, later: 1, dropped: 1),
            CloseLog(day: k("2026-11-07"), at: at("2026-11-07 21:00"), done: 1, tomorrow: 0, later: 0, dropped: 0),
        ]
        d.rests = [
            RestLog(at: at("2026-11-11 15:00"), kind: .breath, seconds: 60, before: 3, after: 6),
            RestLog(at: at("2026-11-12 15:00"), kind: .far, seconds: 180, before: 4, after: 5),
            RestLog(at: at("2026-11-13 15:00"), kind: .walk, seconds: 600, before: nil, after: 7),
        ]
        d.dumps = [
            DumpLog(at: at("2026-11-09 08:00"), before: 8, after: 4, now: 2, dated: 5, worry: 1, dropped: 2),
            DumpLog(at: at("2026-11-12 08:00"), before: 6, after: 4, now: 1, dated: 2, worry: 0, dropped: 1),
        ]
        let s = RecordStats.compute(d, today: today, calendar: seoul)
        eq(s.week.closed, 2, "closed.week")
        eq(s.prev.closed, 1, "closed.prev")
        eq(s.week.rests, 3, "rests")
        near(s.week.clarity, 2.0, "clarity mean (both only)")
        eq(s.week.dumps, 2, "dumps")
        eq(s.week.dumped, 14, "dumped total")
        near(s.week.noise, -3.0, "noise mean")
        eq(s.reflection, "이번 주엔 아직 끝낸 일이 없어, 하루를 2번 닫았어. 식히고 나면 맑기가 평균 +2 올랐어.", "reflection logs")
    }

    // 7. 예상 대 실제: 3번 이상일 때만, 중앙값
    do {
        var d = AppData()
        d.focus = [
            FocusLog(at: at("2026-11-10 10:00"), title: "a", planned: 30, spent: 30, finished: true),
            FocusLog(at: at("2026-11-11 10:00"), title: "b", planned: 30, spent: 60, finished: true),
        ]
        eq(RecordStats.compute(d, today: today, calendar: seoul).focusRatio == nil, true, "focus <3 nil")
        d.focus.append(FocusLog(at: at("2026-11-12 10:00"), title: "c", planned: 50, spent: 70, finished: false))
        d.focus.append(FocusLog(at: at("2026-11-12 11:00"), title: "예상 0은 뺀다", planned: 0, spent: 10, finished: false))
        let s = RecordStats.compute(d, today: today, calendar: seoul)
        eq(s.focusCount, 3, "focus count")
        near(s.focusRatio, 1.4, "focus median")
        eq(s.focusAdvice, "대체로 예상의 1.4배 걸려. 길이를 넉넉히 잡아 봐.", "focus advice")
        near(RecordStats.median([1, 2, 3, 4]), 2.5, "median even")
    }

    // 8. 12주 칸: 84칸, 주 단위, 미래 표시
    do {
        var d = AppData()
        d.items = [doneItem("a", "2026-11-12 10:00"), doneItem("b", "2026-11-12 18:00"), doneItem("c", "2026-08-24 09:00")]
        let s = RecordStats.compute(d, today: today, calendar: seoul)
        eq(s.grid.first?.day, k("2026-08-24"), "grid.first")
        eq(s.grid.last?.day, k("2026-11-15"), "grid.last")
        eq(s.grid.first?.count, 1, "grid.first count")
        eq(s.grid.first { $0.day == k("2026-11-12") }?.count, 2, "grid.11-12 count")
        eq(s.grid.filter { $0.future }.count, 0, "grid.no future (mon)")
        d.settings.mondayFirst = false
        let t = RecordStats.compute(d, today: today, calendar: seoul)
        eq(t.grid.filter { $0.future }.count, 6, "grid.future (sun)")
        eq(t.grid[t.grid.count - 7].day, k("2026-11-15"), "grid.last column starts today (sun)")
    }

    // 9. 최근 14일 끝낸 일: 날로 묶고 최근 날부터
    do {
        var d = AppData()
        d.items = [
            doneItem("오래됨", "2026-11-01 10:00"),
            doneItem("경계", "2026-11-02 10:00"),
            doneItem("치과", "2026-11-14 15:30", time: 900),
            doneItem("메일", "2026-11-14 09:00", part: .morning),
            doneItem("빨래", "2026-11-15 20:00", part: .evening),
        ]
        let s = RecordStats.compute(d, today: today, calendar: seoul)
        eq(s.history.map { $0.day }, [k("2026-11-15"), k("2026-11-14"), k("2026-11-02")], "history days")
        eq(s.history[1].items.map { $0.title }, ["치과", "메일"], "history order in day")
        eq(s.history[1].items.map { $0.slot }, ["15:00", "아침"], "history slot")
    }

    // 10. 띠별 · 가장 많이 끝낸 띠 · 한 줄
    do {
        var d = AppData()
        d.items = [
            doneItem("a", "2026-11-10 09:00", part: .morning),
            doneItem("b", "2026-11-11 14:00"),
            doneItem("c", "2026-11-12 14:00"),
        ]
        d.closes = [CloseLog(day: k("2026-11-12"), at: at("2026-11-12 21:00"), done: 2, tomorrow: 0, later: 0, dropped: 0)]
        let s = RecordStats.compute(d, today: today, calendar: seoul)
        eq(s.topPart, Part?.some(.afternoon), "topPart")
        eq(s.reflection, "이번 주엔 3개를 끝냈어, 하루를 1번 닫았어. 낮에 가장 많이 끝냈어.", "reflection")
        var tie = AppData()
        tie.items = [doneItem("a", "2026-11-10 09:00", part: .evening), doneItem("b", "2026-11-10 10:00", part: .morning)]
        eq(RecordStats.compute(tie, today: today, calendar: seoul).topPart, Part?.some(.morning), "topPart tie → earlier band")
    }

    // 11. 진하기 단계 · 부호 숫자
    do {
        eq([0, 1, 2, 3, 4, 5, 6, 20].map(RecordStats.level), [0, 1, 2, 2, 3, 3, 4, 4], "level")
        eq(RecordStats.signed(2.04), "+2", "signed int")
        eq(RecordStats.signed(-3.25), "−3.3", "signed neg") // 반올림: -32.5 → -33 (멀어지는 쪽)
        eq(RecordStats.signed(0.04), "0", "signed zero")
        eq(RecordStats.signed(1.5), "+1.5", "signed frac")
    }

    // 12. 예상보다 빨리 · 예상만큼
    do {
        var d = AppData()
        d.focus = (0..<3).map { FocusLog(at: at("2026-11-1\($0) 10:00"), title: "f", planned: 40, spent: 30, finished: true) }
        eq(RecordStats.compute(d, today: today, calendar: seoul).focusAdvice, "대체로 예상의 0.8배면 끝나. 길이를 줄여도 돼.", "focus faster")
        d.focus = (0..<3).map { FocusLog(at: at("2026-11-1\($0) 10:00"), title: "f", planned: 30, spent: 31, finished: true) }
        eq(RecordStats.compute(d, today: today, calendar: seoul).focusAdvice, "대체로 예상한 만큼 걸려.", "focus same")
        d.focus = (0..<3).map { FocusLog(at: at("2026-07-0\($0 + 1) 10:00"), title: "f", planned: 30, spent: 60, finished: true) }
        eq(RecordStats.compute(d, today: today, calendar: seoul).focusRatio == nil, true, "focus older than 12 weeks ignored")
    }
}
