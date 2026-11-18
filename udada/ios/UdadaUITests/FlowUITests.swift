import XCTest

/// 우다다 v5 주요 흐름. 시계를 2026-11-15(일) 14:20 으로 고정하고 예시 하루로 시작한다.
/// SHOT_DIR 환경 변수(TEST_RUNNER_SHOT_DIR)가 있으면 단계별 스크린샷을 그 폴더에 남긴다.
final class FlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ extra: [String] = [], seed: Bool = true, intro: Bool = false) {
        var args = ["-udReset", "-udNow", "2026-11-15T14:20", "-udSpeed", "60", "-udNoAI"]
        if seed { args.append("-udSeed") }
        args.append(intro ? "-udIntro" : "-udSkipIntro")
        app.launchArguments = args + extra + ["-udNoSync"]
        app.launch()
    }

    private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            let w = Int(app.windows.firstMatch.frame.width)
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(w)-\(name).png"))
        }
    }

    private func el(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    @discardableResult
    private func wait(_ id: String, _ t: TimeInterval = 5) -> XCUIElement {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: t), "안 보임: \(id)")
        return e
    }

    // MARK: 오늘

    func testTodayAddCompleteSwipeEdit() {
        launch()
        wait("now")
        XCTAssertTrue(app.staticTexts["치과까지 40분"].exists, "지금 줄 머리말")
        shot("today")

        // 한 줄 넣기: 미리보기가 날·시각을 읽는다
        let field = wait("add.field")
        field.tap()
        field.typeText("내일 3시 치과 검진")
        let preview = wait("add.preview")
        let read = expectation(for: NSPredicate(format: "label CONTAINS '내일 15:00'"), evaluatedWith: preview)
        wait(for: [read], timeout: 5)
        shot("add-preview")
        wait("add.go").tap()
        wait("toast")
        XCTAssertTrue(el("toast").label.contains("넣었어") || app.staticTexts.containing(NSPredicate(format: "label CONTAINS '넣었어'")).count > 0)
        // 키보드는 남아 이어서 적을 수 있다
        XCTAssertTrue(app.keyboards.firstMatch.exists, "넣은 뒤에도 키보드 유지")
        field.typeText("보고서 마무리 1시간\n")
        wait("add.dismiss").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "키보드 내리기")

        // 네모를 눌러 끝내기
        let check = wait("check.보고서 초안")
        check.tap()
        XCTAssertTrue(check.label.contains("끝냄"), "끝낸 뒤 라벨: \(check.label)")

        // 왼쪽으로 밀어 '내일'
        let row = wait("row.택배 보내기")
        row.swipeLeft()
        let tomorrow = app.buttons["내일"].firstMatch
        if tomorrow.waitForExistence(timeout: 2) { tomorrow.tap() }
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '옮겼어'")).firstMatch.waitForExistence(timeout: 3), "옮김 토스트")
        XCTAssertFalse(el("row.택배 보내기").exists, "오늘에서 빠짐")
        wait("toast.undo").tap()
        XCTAssertTrue(wait("row.택배 보내기").exists, "되돌리기")

        // 눌러서 고치기: 길이 1시간
        el("row.메일 답장").tap()
        wait("edit.done")
        shot("edit")
        app.buttons["chip.1시간"].firstMatch.tap()
        el("edit.done").tap()
        XCTAssertTrue(app.staticTexts["1시간"].waitForExistence(timeout: 3), "길이가 바뀜")
    }

    func testLaterSheetAndWeek() {
        launch()
        wait("later.open").tap()
        wait("later.pull.여권 갱신")
        XCTAssertTrue(app.staticTexts["12일째. 아직 할 거야?"].exists, "10일 넘은 일은 묻는다")
        shot("later")
        el("later.pull.여권 갱신").tap()
        app.buttons["닫기"].firstMatch.tap()
        XCTAssertTrue(wait("row.여권 갱신").exists, "오늘로 꺼냄")
        // 주 띠로 어제, 다시 오늘로
        wait("week.14").tap()
        wait("header.today")
        shot("yesterday")
        el("header.today").tap()
        wait("now")
    }

    // MARK: 하루 닫기 · 식히기 · 집중

    func testCloseDayStamp() {
        launch(["-udOpen", "udada://close"])
        wait("close.card")
        shot("close-card")
        let order = ["close.tomorrow", "close.later", "close.drop"]
        var i = 0
        while el("close.card").exists && i < 12 {
            el(order[i % 3]).tap()
            i += 1
            _ = el("close.end").waitForExistence(timeout: 0.6)
        }
        wait("close.end")
        sleep(1)
        shot("close-stamp")
        el("close.finish").tap()
        wait("now")
    }

    func testRestBreathFinishes() {
        launch(["-udOpen", "udada://rest"])
        wait("rest.breath")
        shot("rest-pick")
        el("rest.breath").tap()
        wait("rest.done", 8)
        shot("rest-done")
        el("rest.back").tap()
        wait("now")
    }

    func testFocusFromNowLine() {
        launch()
        wait("now.start").tap()
        wait("focus.clock")
        XCTAssertTrue(el("focus.title").label.contains("메일 답장"))
        shot("focus")
        el("focus.done").tap()
        wait("toast")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '예상 15분'")).firstMatch.exists, "예상 대 실제 토스트")
    }

    // MARK: 비우기

    func testDumpSortFinish() {
        launch(["-udOpen", "udada://dump"])
        wait("dump.example").tap()
        shot("dump-write")
        el("dump.sort").tap()
        wait("sort.card", 10)
        shot("dump-card")
        el("sort.suggest").tap()
        if el("sort.all").waitForExistence(timeout: 2) { el("sort.all").tap() }
        wait("finish.one", 6)
        shot("dump-finish")
        el("finish.done").tap()
        wait("toast")
    }

    func testWorryTime() {
        launch(["-udOpen", "udada://worry"])
        wait("worry.keep", 8)
        shot("worry")
        el("worry.keep").tap()
        wait("worry.end")
        el("worry.close").tap()
    }

    func testGate() {
        launch(["-udOpen", "udada://gate"])
        wait("gate.title")
        shot("gate")
        el("gate.pass").tap()
        wait("now")
    }

    // MARK: 탭 · 설정 · 소개

    func testTabsAndSettings() {
        launch()
        app.tabBars.buttons["달력"].tap()
        wait("calendar.open.day")
        shot("calendar")
        app.tabBars.buttons["비우기"].tap()
        wait("dump.start")
        shot("mind")
        app.tabBars.buttons["기록"].tap()
        sleep(1)
        shot("records")
        app.buttons["설정"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 3) || app.staticTexts["설정"].exists)
        shot("settings")
    }

    func testIntroToToday() {
        launch(seed: false, intro: true)
        sleep(1)
        shot("intro-1")
        let skip = app.buttons["건너뛰기"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        skip.tap()
        // 사용법을 건너뛰어도 '필요한 것만 켜기'는 한 번 보여 준다
        wait("intro.start").tap()
        wait("add.field")
        shot("empty-today")
    }
}
