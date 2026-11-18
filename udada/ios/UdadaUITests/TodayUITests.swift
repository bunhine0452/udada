import XCTest
import UIKit

/// 오늘 · 달력 탭의 손동작. 시계는 2026-11-15(일) 14:20 — 아침 띠는 지났고 지금은 낮 띠.
/// 예시 하루: 아침 「메일 답장」 「물 한 잔(매일)」 · 10:00 팀 회의 / 낮 「보고서 초안」 「택배 보내기」 · 15:00 치과 / 저녁 「빨래 개기」 · 19:30 저녁 약속.
/// TEST_RUNNER_TODAY_SHOTS=1 + TEST_RUNNER_SHOT_DIR=<폴더> 이면 화면 둘러보기(testShotsWalkthrough)가 상태별 스크린샷을 남긴다.
/// TEST_RUNNER_TODAY_SIZE=UICTContentSizeCategoryAccessibilityL 처럼 주면 그 글자 크기로 띄운다.
final class TodayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = [], seed: Bool = true, reset: Bool = true) {
        // -udNoAI: 기기 안 모델 속도에 흔들리지 않게 규칙만 쓴다
        var args = ["-udNow", "2026-11-15T14:20", "-udSkipIntro", "-udNoAI"]
        if reset { args.insert("-udReset", at: 0) }
        if seed { args.append("-udSeed") }
        if let size = ProcessInfo.processInfo.environment["TODAY_SIZE"] {
            args += ["-UIPreferredContentSizeCategoryName", size]
        }
        app.launchArguments = args + extra + ["-udNoSync"]
        app.launch()
    }

    private func el(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    @discardableResult
    private func wait(_ id: String, _ t: TimeInterval = 5, _ why: String? = nil) -> XCUIElement {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: t), why ?? "안 보임: \(id)")
        return e
    }

    private func text(containing s: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    /// 그 띠 안에 그 줄이 있나
    private func bandRow(_ title: String, in part: String) -> XCUIElement {
        el("band.\(part)").descendants(matching: .any)["row.\(title)"].firstMatch
    }

    private func gone(_ e: XCUIElement, _ t: TimeInterval = 3) -> Bool { e.waitForNonExistence(timeout: t) }

    /// 라벨이 그 글을 품을 때까지 기다린다 (타자가 앱에 다 닿기 전에 읽지 않게)
    @discardableResult
    private func label(of e: XCUIElement, contains s: String, _ t: TimeInterval = 6) -> Bool {
        let p = NSPredicate(format: "label CONTAINS %@", s)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: p, object: e)], timeout: t) == .completed
    }

    /// 주 띠를 밀어 다음 주(16–22일)로. 오늘(15일, 일)은 월요일에 시작하는 주의 끝이라 16일은 다음 주에 있다.
    private func nextWeek() {
        XCTAssertTrue(el("week.22").exists || drag(wait("week.strip"), left: true, until: el("week.22")), "다음 주로 넘어감")
    }

    /// 주 띠를 손가락처럼 끈다 (빠른 swipeLeft 보다 흔들림이 적다)
    private func swipeStrip(left: Bool) { drag(wait("week.strip"), from: left ? 0.85 : 0.15, to: left ? 0.15 : 0.85) }

    /// 요소 안에서 가로로 정해진 만큼 끈다 (가로 비율 from → to). XCUITest 의 빠른 swipe 는 거리·속도가 들쭉날쭉하다.
    private func drag(_ e: XCUIElement, from: CGFloat, to: CGFloat, velocity: CGFloat = 700) {
        let a = e.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5))
        let b = e.coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.5))
        a.press(forDuration: 0.05, thenDragTo: b, withVelocity: XCUIGestureVelocity(velocity), thenHoldForDuration: 0.05)
    }

    /// 넘어갈 때까지 (최대 두 번) 끈다
    @discardableResult
    private func drag(_ e: XCUIElement, left: Bool, until done: XCUIElement) -> Bool {
        for _ in 0..<2 {
            drag(e, from: left ? 0.85 : 0.15, to: left ? 0.15 : 0.85)
            if done.waitForExistence(timeout: 6) { return true }
        }
        return false
    }

    // MARK: 밀기

    func testSwipeRightCompletes() {
        launch()
        let row = wait("row.택배 보내기")
        drag(row, from: 0.1, to: 0.9)
        let check = wait("check.택배 보내기")
        XCTAssertTrue(label(of: check, contains: "끝냄"), "오른쪽으로 밀면 끝: \(check.label)")
        // 한 번 더 밀면 되살린다
        drag(row, from: 0.1, to: 0.9)
        XCTAssertTrue(label(of: wait("check.택배 보내기"), contains: "끝내기"), "되살리기")
    }

    func testSwipeLeftMovesToTomorrow() {
        launch()
        let row = wait("row.택배 보내기")
        // 조금만 밀면 [내일] [나중에] 버튼이 열린다
        drag(row, from: 0.9, to: 0.55, velocity: 300)
        let tomorrow = app.buttons["내일"].firstMatch
        XCTAssertTrue(tomorrow.waitForExistence(timeout: 3), "밀어서 연 버튼")
        tomorrow.tap()
        XCTAssertTrue(text(containing: "내일 아침으로 옮겼어").waitForExistence(timeout: 3), "옮김 토스트")
        XCTAssertTrue(gone(el("row.택배 보내기")), "오늘에서 빠짐")
        nextWeek()
        wait("week.16").tap()
        XCTAssertTrue(bandRow("택배 보내기", in: "morning").waitForExistence(timeout: 3), "내일 아침 띠에 있음")
    }

    func testFullSwipeLeftAndUndo() {
        launch()
        let row = wait("row.보고서 초안")
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let end = row.coordinate(withNormalizedOffset: CGVector(dx: -0.35, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: XCUIGestureVelocity(900), thenHoldForDuration: 0.05)
        XCTAssertTrue(text(containing: "내일 아침으로 옮겼어").waitForExistence(timeout: 3), "끝까지 밀면 바로 내일로")
        wait("toast.undo").tap()
        XCTAssertTrue(wait("row.보고서 초안").exists, "되돌리기")
        XCTAssertTrue(bandRow("보고서 초안", in: "afternoon").exists, "제자리(낮)로 돌아옴")
    }

    // MARK: 띠 옮기기
    // 끌어 옮기기(.draggable → 띠의 .dropDestination)도 있지만, XCUITest 의 합성 '길게 누르고 끌기'는
    // 들림 → 메뉴로 넘어가는 시점을 못 맞춰 메뉴가 뜬다. 그래서 같은 일을 하는 메뉴의 「다른 띠로」를 검증한다.

    func testMoveBandFromMenu() {
        launch()
        wait("row.택배 보내기").press(forDuration: 1.2)
        let sub = app.buttons["다른 띠로"]
        XCTAssertTrue(sub.waitForExistence(timeout: 3), "길게 누르면 메뉴")
        sub.tap()
        let evening = app.buttons["저녁으로"]
        XCTAssertTrue(evening.waitForExistence(timeout: 3), "띠 고르기")
        evening.tap()
        XCTAssertTrue(text(containing: "오늘 저녁으로 옮겼어").waitForExistence(timeout: 3), "옮김 토스트")
        XCTAssertTrue(bandRow("택배 보내기", in: "evening").waitForExistence(timeout: 3), "저녁 띠로 감")
    }

    /// 맨 위로 (오늘은 열릴 때 지금 띠로 스크롤되어 지난 아침 띠가 머리 위로 올라가 있다)
    private func toTop() {
        for _ in 0..<2 {
            let a = app.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.4))
            let b = app.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.85))
            a.press(forDuration: 0.05, thenDragTo: b, withVelocity: XCUIGestureVelocity(1500), thenHoldForDuration: 0.3)
        }
    }

    /// 띠의 윗부분이 넣기 줄 위로 보이도록 왼쪽 띠 이름 줄을 잡고 조금씩 올린다
    private func reveal(_ e: XCUIElement) {
        let limit = app.frame.height - 230
        var n = 0
        while e.frame.minY + 60 > limit && n < 4 {
            let a = app.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.62))
            let b = app.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.42))
            a.press(forDuration: 0.05, thenDragTo: b, withVelocity: XCUIGestureVelocity(300), thenHoldForDuration: 0.4)
            n += 1
        }
    }

    // MARK: 스크롤

    /// 줄 · 달 칸 위에서 시작한 세로 끌기도 화면을 스크롤한다 (가로 밀기 제스처가 스크롤을 막지 않는다)
    func testVerticalDragOnRowsScrolls() {
        launch()
        let row = wait("row.보고서 초안")
        let now = wait("now")
        let before = now.frame.minY
        let a = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        a.press(forDuration: 0.05, thenDragTo: a.withOffset(CGVector(dx: 0, dy: 160)), withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.3)
        XCTAssertGreaterThan(now.frame.minY, before + 60, "줄 위에서 아래로 끌면 위가 보인다")

        app.tabBars.buttons["달력"].tap()
        let grid = wait("cal.grid")
        let title = wait("cal.title")
        let top = title.frame.minY
        let g = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        g.press(forDuration: 0.05, thenDragTo: g.withOffset(CGVector(dx: 0, dy: -180)), withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.3)
        XCTAssertLessThan(title.frame.minY, top - 60, "달 칸 위에서 위로 끌면 아래(그날 띠)가 보인다")
    }

    // MARK: 쪼개기

    /// 고치기 → 작게 쪼개기 → 걸음이 날에 놓인 채 미리 보이고, 눌러야 들어간다 (큰일은 그대로). 되돌리기 한 번.
    /// 모델 없는 길(-udNoAI): 「보고서 초안」은 다듬어 둔 네 걸음. TEST_RUNNER_SHOT_DIR 이 있으면 미리보기 화면을 남긴다.
    func testSplitBigTaskIntoSteps() {
        launch()
        wait("row.보고서 초안").tap()
        let split = wait("edit.split")
        if !split.isHittable { app.swipeUp() }
        split.tap()
        wait("split.apply")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "split.step").count, 4, "걸음 넷")
        XCTAssertTrue(text(containing: "오늘 · 낮").exists, "오늘 마감인 큰일은 오늘 지금 띠에")
        // 하루에 하나로 바꾸면 내일·모레로 이어진다
        el("split.pace.daily").tap()
        XCTAssertTrue(text(containing: "내일").waitForExistence(timeout: 2), "하루에 하나")
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("split-preview.png"))
        }
        el("split.pace.today").tap()
        XCTAssertTrue(label(of: el("split.apply"), contains: "걸음 4개 넣기"))
        el("split.apply").tap()
        // 되돌리기 토스트는 5초만 떠 있다 — 뜬 것을 먼저 잡고, 그 사이에 줄을 본다
        let undo = wait("toast.undo", 6, "넣으면 시트가 닫히고 되돌리기가 뜬다")
        XCTAssertTrue(bandRow("자료 모아 한곳에 두기", in: "afternoon").exists, "걸음이 오늘 낮에")
        XCTAssertTrue(el("row.다시 읽고 고치기").exists)
        XCTAssertTrue(el("row.보고서 초안").exists, "큰일은 그대로")
        undo.tap()
        XCTAssertTrue(gone(el("row.자료 모아 한곳에 두기")), "되돌리기 한 번에 다 빠진다")
    }

    // MARK: 고치기

    func testEditMakesWeeklyRepeat() {
        launch()
        wait("row.보고서 초안").tap()
        wait("edit.done")
        app.buttons["chip.매주"].firstMatch.tap()
        let mon = wait("edit.wd.2"), wed = wait("edit.wd.4")
        XCTAssertTrue(el("edit.wd.1").isSelected, "오늘(일)이 먼저 켜짐")
        mon.tap(); wed.tap()
        XCTAssertTrue(mon.isSelected && wed.isSelected, "월 · 수 켜짐")
        el("edit.done").tap()
        XCTAssertTrue(label(of: wait("row.보고서 초안"), contains: "반복"), "반복 표시")
        nextWeek()
        wait("week.16").tap() // 월
        XCTAssertTrue(wait("row.보고서 초안").exists, "월요일에 있음")
        wait("week.17").tap() // 화
        XCTAssertTrue(gone(el("row.보고서 초안")), "화요일엔 없음")
        wait("week.18").tap() // 수
        XCTAssertTrue(wait("row.보고서 초안").exists, "수요일에 있음")
    }

    func testEditRepeatScope() {
        launch()
        // 반복 전체: 길이를 바꾸면 내일 것도 바뀐다
        wait("row.물 한 잔")
        toTop()
        el("row.물 한 잔").tap()
        wait("edit.done")
        let all = app.buttons["반복 전체"].firstMatch
        XCTAssertTrue(all.waitForExistence(timeout: 3), "이날만 · 반복 전체")
        all.tap()
        app.buttons["chip.15분"].firstMatch.tap()
        el("edit.done").tap()
        XCTAssertTrue(label(of: wait("row.물 한 잔"), contains: "15분"), "오늘 것 15분")
        // 이날만: 오늘 것만 30분
        toTop()
        el("row.물 한 잔").tap()
        wait("edit.done")
        XCTAssertTrue(app.buttons["이날만"].firstMatch.isSelected, "기본은 이날만")
        app.buttons["chip.30분"].firstMatch.tap()
        el("edit.done").tap()
        XCTAssertTrue(label(of: wait("row.물 한 잔"), contains: "30분"), "오늘 것만 30분")
        nextWeek()
        wait("week.16").tap()
        XCTAssertTrue(label(of: wait("row.물 한 잔"), contains: "15분"), "내일 것은 그대로 15분")
    }

    // MARK: 나중에 · 날짜

    func testLaterPullAndRelease() {
        launch()
        wait("later.open").tap()
        wait("later.pull.책장 정리").tap()
        XCTAssertTrue(text(containing: "오늘 낮에 넣었어").waitForExistence(timeout: 3), "꺼냄 토스트")
        // 오래된 것은 놓아주고, 되돌린다
        wait("later.drop.여권 갱신").tap()
        XCTAssertTrue(gone(el("later.pull.여권 갱신")), "놓아줌")
        wait("toast.undo").tap()
        XCTAssertTrue(wait("later.pull.여권 갱신").exists, "되돌리기")
        app.buttons["닫기"].firstMatch.tap()
        XCTAssertTrue(bandRow("책장 정리", in: "afternoon").waitForExistence(timeout: 3), "지금 띠(낮)로")
    }

    func testDayPickerAndWeekSwipe() {
        launch()
        wait("header.date").tap()
        let close = app.buttons["daypicker.close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 3), "날짜 고르기가 열림")
        sleep(1)
        XCTAssertTrue(close.exists, "열리자마자 닫히지 않음")
        close.tap()
        XCTAssertTrue(gone(close), "닫힘")
        // 주 띠를 옆으로 밀면 다음 주 같은 요일
        XCTAssertTrue(drag(wait("week.strip"), left: true, until: el("week.22")), "다음 주로")
        XCTAssertTrue(el("week.22").isSelected, "다음 주 같은 요일")
        XCTAssertTrue(drag(el("week.strip"), left: false, until: el("week.9")), "다시 이번 주로")
        XCTAssertTrue(wait("week.15").isSelected, "오늘")
        wait("now")
    }

    // MARK: 한 줄 넣기

    func testQuickAddReadsKorean() {
        launch()
        let field = wait("add.field")
        field.tap()
        let preview = wait("add.preview")
        func check(_ input: String, _ expect: [String]) {
            if el("add.clear").exists { el("add.clear").tap() }
            field.typeText(input)
            for s in expect { XCTAssertTrue(label(of: preview, contains: s), "\(input) → \(preview.label) (\(s) 없음)") }
        }
        check("내일 3시 치과", ["치과", "내일 15:00 약속 · 1시간"])
        check("보고서 30분", ["보고서", "오늘 낮 · 30분"])
        check("매주 월수금 아침 운동", ["운동", "매주 월·수·금 아침 · 30분", "11월 16일부터"])
        check("나중에 여권", ["여권", "나중에"])
        // 칩으로 고치기
        check("보고서 30분", ["오늘 낮"])
        app.buttons["chip.내일"].firstMatch.tap()
        app.buttons["chip.part.evening"].firstMatch.tap()
        app.buttons["chip.1시간"].firstMatch.tap()
        XCTAssertTrue(label(of: preview, contains: "내일 저녁 · 1시간"), "칩: \(preview.label)")
        // 엔터로 넣고 이어서 적는다
        field.typeText("\n")
        XCTAssertTrue(text(containing: "넣었어").waitForExistence(timeout: 3), "넣음 토스트")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "키보드 남음")
        XCTAssertFalse(el("add.clear").exists, "줄이 비워짐")
        field.typeText("빨래 걷기\n")
        XCTAssertTrue(el("row.빨래 걷기").waitForExistence(timeout: 3), "연속 넣기")
        wait("add.dismiss").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "키보드 내리기")
        XCTAssertTrue(wait("row.빨래 걷기").exists)
    }

    func testQuickAddMultiLinePaste() {
        launch()
        UIPasteboard.general.string = "- 우유 사기\n- 세탁소 들르기\n- 엄마한테 전화"
        let field = wait("add.field")
        field.tap()
        field.press(forDuration: 1.2)
        let paste = [app.menuItems["붙여넣기"], app.menuItems["Paste"], app.buttons["붙여넣기"], app.buttons["Paste"]]
        var tapped = false
        for p in paste where p.waitForExistence(timeout: tapped ? 0 : 1.5) { p.tap(); tapped = true; break }
        XCTAssertTrue(tapped, "붙여넣기 메뉴")
        XCTAssertTrue(label(of: wait("add.preview"), contains: "3개를"), "여러 줄: \(el("add.preview").label)")
        wait("add.go").tap()
        XCTAssertTrue(text(containing: "3개 넣었어").waitForExistence(timeout: 3))
        wait("add.dismiss").tap()
        for t in ["우유 사기", "세탁소 들르기", "엄마한테 전화"] { XCTAssertTrue(wait("row.\(t)").exists, t) }
    }

    // MARK: 달력

    func testCalendarMonthSwipeAndSelect() {
        launch()
        app.tabBars.buttons["달력"].tap()
        XCTAssertTrue(app.staticTexts["2026년 11월"].waitForExistence(timeout: 3))
        XCTAssertTrue(drag(wait("cal.grid"), left: true, until: app.staticTexts["2026년 12월"]), "다음 달")
        wait("cal.2026-12-03").tap()
        XCTAssertTrue(wait("cal.2026-12-03").isSelected, "고른 날")
        XCTAssertTrue(text(containing: "12월 3일").waitForExistence(timeout: 3), "그날 띠")
        XCTAssertTrue(drag(el("cal.grid"), left: false, until: app.staticTexts["2026년 11월"]), "이전 달")
        XCTAssertTrue(drag(el("cal.grid"), left: false, until: app.staticTexts["2026년 10월"]), "한 번 더 이전 달")
        wait("cal.today").tap()
        XCTAssertTrue(app.staticTexts["2026년 11월"].waitForExistence(timeout: 3), "오늘로")
        wait("cal.2026-11-16").tap()
        wait("calendar.open.day").tap()
        XCTAssertTrue(wait("header.date").label.contains("11월 16일"), "하루 한 장으로: \(el("header.date").label)")
        XCTAssertTrue(wait("row.장보기").exists, "그날의 할 일")
    }

    // MARK: 화면 둘러보기 (스크린샷)

    func testShotsWalkthrough() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["TODAY_SHOTS"] != nil, let dir = env["SHOT_DIR"] else { throw XCTSkip("TEST_RUNNER_TODAY_SHOTS 없음") }
        let tag = env["TODAY_TAG"] ?? "x"
        func shot(_ name: String) {
            let s = XCUIScreen.main.screenshot()
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(tag)-\(name).png"))
        }
        func tapIf(_ id: String, _ t: TimeInterval = 2) { if el(id).waitForExistence(timeout: t) { el(id).tap() } }
        func top() { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04)).tap() }

        launch()
        wait("add.field")
        sleep(1)
        shot("01-today")
        // 열리면 지금 띠가 맨 위라 「택배 보내기」가 보인다 (큰 글자에서는 아래에 있을 수 있어 보일 때만)
        if el("row.택배 보내기").waitForExistence(timeout: 2) && el("row.택배 보내기").isHittable {
            el("row.택배 보내기").swipeLeft(); sleep(1)
            shot("03-swipe-open")
            el("row.택배 보내기").tap(); sleep(1)
            if el("edit.done").exists { el("edit.done").tap(); sleep(1) }
            el("row.택배 보내기").press(forDuration: 1.2); sleep(1)
            shot("04-menu")
            top(); sleep(1)
        }
        reveal(el("close.open")); sleep(1)
        shot("02-today-bottom")
        toTop(); sleep(1)
        tapIf("header.date"); sleep(1)
        shot("05-daypicker")
        tapIf("daypicker.close"); sleep(1)
        tapIf("later.open"); sleep(1)
        shot("06-later")
        if app.buttons["닫기"].exists { app.buttons["닫기"].firstMatch.tap() }; sleep(1)
        tapIf("row.보고서 초안"); sleep(1)
        shot("07-edit-todo")
        tapIf("chip.매주"); sleep(1)
        shot("08-edit-weekly")
        app.swipeUp(); sleep(1)
        shot("09-edit-bottom")
        tapIf("chip.안 함"); tapIf("edit.done"); sleep(1)
        tapIf("event.치과"); sleep(1)
        shot("10-edit-event")
        tapIf("edit.done"); sleep(1)
        tapIf("row.물 한 잔"); sleep(1)
        shot("11-edit-repeat")
        tapIf("edit.done"); sleep(1)
        tapIf("add.field"); sleep(1)
        el("add.field").typeText("매주 월수금 아침 운동"); sleep(1)
        shot("12-add")
        tapIf("add.clear"); tapIf("add.dismiss"); sleep(1)
        el("week.strip").swipeLeft(); sleep(1)
        tapIf("week.16"); sleep(1)
        shot("13-tomorrow")
        tapIf("header.today"); sleep(1)
        app.tabBars.buttons["달력"].tap(); sleep(1)
        shot("14-calendar")
        app.swipeUp(); sleep(1)
        shot("15-calendar-agenda")
        app.terminate()

        launch(seed: false)
        wait("add.field"); sleep(1)
        shot("16-empty")
    }

    // MARK: 밖에서 받기 · 여러 번 넘어온 일

    /// 공유로 받아 둔 글 → '정리하기' → 비우기 적는 칸에 챙길 줄만 올라온다 (인사말은 빠진다). 보관함은 비워진다.
    func testInboxSharedTextBecomesDumpLines() {
        launch(["-udInbox", "팀장: 내일 오전 9시 반까지 발표 자료 최종본 올려주세요. 좋은 하루 되세요."])
        wait("inbox.card")
        el("inbox.sort").tap()
        let editor = wait("dump.text", 8)
        let has = NSPredicate(format: "value CONTAINS %@", "발표 자료 최종본")
        expectation(for: has, evaluatedWith: editor)
        waitForExpectations(timeout: 8)
        XCTAssertFalse((editor.value as? String ?? "").contains("좋은 하루"))
    }

    /// 네 번 넘어온 일은 한 줄로 묻는다. '나중에 함'을 누르면 카드가 사라진다.
    func testStuckCardAsksOnceAndClears() {
        launch(["-udStuck", "보고서 초안"])
        wait("stuck.card")
        XCTAssertTrue(text(containing: "4번 넘어왔어").exists)
        el("stuck.later").tap()
        XCTAssertTrue(el("stuck.card").waitForNonExistence(timeout: 4))
    }

    /// 움직임 확인용 (TEST_RUNNER_MOTION=1 일 때만): 줄을 끝내고, 하루 띠로 칸을 오가고, 마지막 줄까지 끝낸다. 화면은 밖에서 녹화한다.
    func testMotionWalk() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MOTION"] == "1")
        launch()
        usleep(1_200_000)
        el("check.메일 답장").tap(); usleep(1_100_000)
        el("check.보고서 초안").tap(); usleep(1_100_000)
        el("ruler.evening").tap(); usleep(1_100_000)
        el("ruler.morning").tap(); usleep(1_100_000)
        el("ruler.afternoon").tap(); usleep(1_100_000)
        el("check.택배 보내기").tap(); usleep(1_400_000)
    }
}
