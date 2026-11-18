import XCTest

/// 기록 · 설정 · 소개. 시계는 2026-11-15(일) 14:20 으로 고정한다.
/// SHOT_DIR 환경 변수(TEST_RUNNER_SHOT_DIR)가 있으면 단계별 스크린샷을 그 폴더에 남긴다.
/// 화면 훑기(testSweep)는 SWEEP_TAG 까지 있을 때만 — 저장된 데이터를 그대로 두고 기록 · 설정을 끝까지 민다.
/// QA: SWEEP_ARGS(실행 인자 더하기, 예: 큰 글자) · SWEEP_DARK=1(어두운 화면).
final class RecordsUITests: XCTestCase {
    private var app: XCUIApplication!
    private let clock = ["-udNow", "2026-11-15T14:20"]
    /// QA 용: SWEEP_ARGS="-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL" 처럼 실행 인자를 더한다
    private let envArgs = (ProcessInfo.processInfo.environment["SWEEP_ARGS"] ?? "").split(separator: " ").map(String.init)

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // QA 용: SWEEP_DARK=1 이면 어두운 화면으로
        if ProcessInfo.processInfo.environment["SWEEP_DARK"] == "1" { XCUIDevice.shared.appearance = .dark }
    }

    override func tearDown() {
        if ProcessInfo.processInfo.environment["SWEEP_DARK"] == "1" { XCUIDevice.shared.appearance = .light }
        super.tearDown()
    }

    /// 깨끗하게 시작 (-udReset)
    private func launch(_ extra: [String] = [], seed: Bool = true, intro: Bool = false) {
        var args = ["-udReset"] + clock + ["-udSpeed", "60"]
        if seed { args.append("-udSeed") }
        args.append(intro ? "-udIntro" : "-udSkipIntro")
        app.launchArguments = args + envArgs + extra + ["-udNoSync"]
        app.launch()
    }

    /// 저장된 데이터를 그대로 두고 다시 연다
    private func relaunch(_ extra: [String] = []) {
        app.terminate()
        app.launchArguments = clock + ["-udSpeed", "60", "-udSkipIntro", "-udNoSync"] + envArgs + extra
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

    /// 아래로 밀어 가며 찾는다 (Form · ScrollView 는 화면 밖 줄을 늦게 만든다)
    /// 글이 들어 있는 아무 요소 (합쳐진 접근성 요소도)
    private func any(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// 화면에 실제로 보일 때까지 (쪽 넘김 TabView 는 옆 쪽도 트리에 있다)
    @discardableResult
    private func waitHittable(_ id: String, _ t: TimeInterval = 5) -> XCUIElement {
        let e = el(id)
        let end = Date().addingTimeInterval(t)
        while Date() < end && !(e.exists && e.isHittable) { usleep(150_000) }
        XCTAssertTrue(e.exists && e.isHittable, "안 보임: \(id)")
        return e
    }

    /// 관성 없이 화면의 40%만큼 올린다 (빠르게 밀면 찾는 줄을 지나친다)
    private func scrollStep() {
        let w = app.windows.firstMatch
        let from = w.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let to = w.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .default, thenHoldForDuration: 0.1)
    }

    @discardableResult
    private func scrollTo(_ id: String, max: Int = 30) -> XCUIElement {
        let e = el(id)
        var i = 0
        while !(e.exists && e.isHittable) && i < max {
            scrollStep()
            i += 1
        }
        XCTAssertTrue(e.exists && e.isHittable, "밀어도 안 보임: \(id)")
        return e
    }

    private func toggle(_ id: String) {
        let t = scrollTo(id)
        let knob = t.switches.firstMatch.exists ? t.switches.firstMatch : t
        knob.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    // MARK: 기록

    func testRecordsEmpty() {
        launch(["-udOpen", "udada://records"], seed: false)
        wait("records.empty")
        XCTAssertTrue(el("records.grid").exists, "빈 12주 칸도 보인다")
        XCTAssertFalse(el("records.reflection").exists, "빈 기록엔 한 줄이 없다")
        XCTAssertFalse(el("records.done").exists)
        shot("records-empty")
    }

    /// 끝내고 · 하루 닫으면 기록에 사실로 쌓인다 (둘 다 고정 시계로 적힌다)
    func testRecordsFillFromFlows() {
        launch()
        wait("check.보고서 초안").tap()
        wait("check.택배 보내기").tap()

        relaunch(["-udOpen", "udada://close"])
        wait("close.card")
        var i = 0
        while el("close.card").exists && i < 8 {
            el("close.tomorrow").tap()
            i += 1
            _ = el("close.end").waitForExistence(timeout: 0.6)
        }
        wait("close.end")
        el("close.finish").tap()

        relaunch(["-udOpen", "udada://records"])
        let done = wait("records.done")
        XCTAssertTrue(done.label.contains("2개"), "끝낸 일: \(done.label)")
        let closed = wait("records.fact.closed")
        XCTAssertTrue(closed.label.contains("1일"), "닫은 날: \(closed.label)")
        let line = wait("records.reflection")
        XCTAssertTrue(line.label.contains("끝냈어"), "이번 주 한 줄: \(line.label)")
        XCTAssertTrue(el("records.rate").exists, "끝낸 비율")
        shot("records-week")

        scrollTo("records.grid")
        shot("records-grid")
        scrollTo("records.history")
        XCTAssertTrue(any("보고서 초안").waitForExistence(timeout: 3), "끝낸 일 목록")
    }

    /// 집중 한 번 → 예상 대 실제 칸이 안내와 최근 기록을 보여 준다
    func testRecordsFocusInsight() {
        launch()
        wait("now.start").tap()
        wait("focus.clock")
        sleep(1)
        el("focus.done").tap()
        wait("toast")
        app.tabBars.buttons["기록"].tap()
        scrollTo("records.focus")
        XCTAssertTrue(any("1번 쟀어").exists, "집중 1번 안내")
        XCTAssertTrue(any("메일 답장").exists, "최근 집중")
        shot("records-focus")
    }

    // MARK: 설정

    func testSettingsDeepLinkSections() {
        launch(["-udOpen", "udada://settings"])
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5), "udada://settings 로 설정이 열린다")
        shot("settings-top")

        // 기기 안 AI: 상태 한 줄이 있고, 끄면 '꺼져 있어'
        let status = scrollTo("settings.ai.status")
        XCTAssertFalse(status.label.isEmpty, "AI 상태")
        shot("settings-ai")
        toggle("settings.ai.toggle")
        XCTAssertTrue(el("settings.ai.status").label.contains("꺼져"), "끈 뒤 상태: \(el("settings.ai.status").label)")
        toggle("settings.ai.toggle")

        // Siri: 팁 카드와 단축어 바로가기
        scrollTo("siri.tip")
        XCTAssertTrue(app.staticTexts["말로 넣기"].exists)
        shot("settings-siri")

        // 맨 아래까지 (데이터 · 정보 · 힘들 때)
        scrollTo("settings.intro")
        shot("settings-bottom")

        el("settings.close").tap()
        wait("records.screen")
        XCTAssertFalse(app.navigationBars["설정"].exists, "닫으면 기록으로")
    }

    /// 톱니로 연 설정에서 '예시로 채워 보기' → 되돌리기 토스트가 설정 위에 보인다 (오늘 탭이 아니라)
    func testSettingsFromGearSeedToast() {
        launch(["-udOpen", "udada://records"], seed: false)
        wait("records.settings").tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 3))
        scrollTo("settings.seed").tap()
        // 토스트는 5초만 머문다 — 한 번만 묻는다
        XCTAssertTrue(el("toast.undo").waitForExistence(timeout: 3), "설정 안에서 되돌리기 토스트가 보인다")
        shot("settings-toast")
        el("settings.close").tap()
        app.tabBars.buttons["오늘"].tap()
        XCTAssertTrue(el("row.메일 답장").waitForExistence(timeout: 3), "예시가 들어갔다")
    }

    func testReplayIntroFromSettings() {
        launch(["-udOpen", "udada://settings"])
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        scrollTo("settings.intro").tap()
        wait("tour.next", 6)
        XCTAssertFalse(app.navigationBars["설정"].exists, "설정은 내려가 있다")
        shot("intro-replay")
        wait("intro.skip").tap()
        wait("intro.start")
        XCTAssertFalse(el("intro.seed").exists, "내 할 일이 있으면 예시로 채우기를 숨긴다")
        el("intro.start").tap()
        wait("add.field")
        XCTAssertTrue(el("row.보고서 초안").waitForExistence(timeout: 3), "내 할 일은 그대로")
    }

    /// 설정이 열린 채 위젯 · 제어 센터 · Siri 링크가 오면 그 화면이 보여야 한다
    func testDeepLinkWhileSettingsOpen() {
        launch(["-udOpen", "udada://settings"])
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        app.open(URL(string: "udada://rest")!)
        wait("rest.breath", 8)
        XCTAssertFalse(app.navigationBars["설정"].exists, "설정은 내려가 있다")
        shot("deeplink-rest-over-settings")
    }

    // MARK: 테마

    /// 테마를 고르면 화면이 그 색으로 다시 그려지고, 설정은 열린 채로 남는다
    func testThemeSwitchKeepsSettingsOpen() {
        launch(["-udOpen", "udada://settings"])
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        let sand = scrollTo("settings.theme.sand")
        XCTAssertFalse(sand.isSelected)
        sand.tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5), "다시 그린 뒤에도 설정이 열려 있다")
        XCTAssertTrue(scrollTo("settings.theme.sand").isSelected, "모래 테마가 골라졌다")
        shot("theme-sand-settings")
    }

    // MARK: 말로 찾기

    /// 물음을 넘겨 열면 내 기록에서 찾아 답 한 줄과 항목을 보여 준다 (규칙 경로 — 모델 없이도 같은 화면)
    func testFindAnswersFromRecords() {
        launch(["-udOpen", "udada://find?q=오늘 치과 몇 시야"])
        let answer = wait("find.answer", 6)
        XCTAssertTrue(answer.label.hasPrefix("오늘 · ‘치과’ · 약속") && answer.label.contains("15:00"), "답: \(answer.label)")
        XCTAssertTrue(el("find.hit.치과").exists, "찾은 항목이 보인다")
        shot("find-answer")
        el("find.hit.치과").tap()
        wait("add.field")
    }

    /// 시키는 말: 미리 보여 주고, 눌러야 바뀐다 (규칙 경로 — 모델 없이도 같은 화면)
    func testCommandPreviewThenApply() {
        launch(["-udOpen", "udada://find?q=치과 내일로 미루고 보고서 초안은 끝냈어"])
        wait("cmd.title", 6)
        XCTAssertTrue(app.staticTexts["‘치과’ → 내일"].exists, "옮길 것을 미리 보여 준다")
        XCTAssertTrue(app.staticTexts["‘보고서 초안’ 끝냄"].exists)
        shot("command-plan")
        el("cmd.apply").tap()
        wait("add.field")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '2가지를 바꿨어'")).firstMatch.waitForExistence(timeout: 3), "되돌릴 수 있는 토스트")
        XCTAssertFalse(el("row.치과").exists, "치과는 오늘에서 빠졌다")
    }

    // MARK: 소개

    /// 처음 실행: 움직이는 사용법 아홉 장면 → 필요한 것만 켜기 → 예시로 시작
    func testIntroGuideFirstRun() {
        launch(seed: false, intro: true)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        wait("tour.next", 6)
        XCTAssertTrue(app.staticTexts["아래 한 줄에 적으면 자리를 찾아가"].exists, "첫 장면은 적기")
        shot("guide-1")
        for i in 0..<8 {
            el("tour.next").tap()
            if i == 2 { XCTAssertTrue(app.staticTexts["쏟아내면 한 줄씩 나눠 줘"].waitForExistence(timeout: 3), "넷째 장면은 쏟아내기") }
            if i == 5 { XCTAssertTrue(app.staticTexts["앱을 열지 않고 Siri에게"].waitForExistence(timeout: 3), "일곱째 장면은 Siri"); shot("guide-siri") }
        }
        XCTAssertTrue(app.staticTexts["전부 이 기기 안에서"].waitForExistence(timeout: 3))
        el("tour.next").tap()
        wait("intro.start")
        XCTAssertTrue(el("intro.notify").exists && el("intro.calendar").exists, "허락은 누를 때만")
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "소개가 먼저 허락을 묻지 않는다")
        shot("intro-setup")
        wait("intro.seed").tap()
        wait("add.field")
        XCTAssertTrue(el("row.메일 답장").waitForExistence(timeout: 3), "예시로 채워서 시작")
    }

    func testIntroSkip() {
        launch(seed: false, intro: true)
        wait("intro.skip").tap()
        wait("intro.start").tap()
        wait("add.field")
    }

    /// 넣기 줄의 Apple Intelligence 버튼: 판이 열리고 '물어보거나 시키기'가 말로 하기를 연다
    func testAIPanelOpensAsk() {
        launch()
        wait("ai.open").tap()
        wait("ai.ask", 4).tap()
        wait("find.field", 5)
    }

    /// 한 줄에 여러 일을 적으면 나눠서 넣는다 (규칙 경로)
    func testOneLineSplitsIntoSeveral() {
        launch()
        let field = wait("add.field")
        field.tap()
        field.typeText("엄마한테 전화하고 내일 은행 가야 되고 월세 오르면 어떡하지")
        wait("add.split", 4)
        el("add.go").tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '나눠 넣었어'")).firstMatch.waitForExistence(timeout: 3), "나눠 넣었다는 토스트")
    }

    // MARK: 화면 훑기 (SHOT_DIR 이 있을 때만) — 저장된 데이터를 그대로 쓴다

    func testSweep() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SHOT_DIR"] != nil, let tag = env["SWEEP_TAG"] else {
            throw XCTSkip("스크린샷 훑기는 SHOT_DIR 과 SWEEP_TAG 가 있을 때만")
        }

        relaunch(["-udOpen", "udada://records"])
        wait("records.screen")
        sleep(1)
        for i in 0..<7 {
            shot("\(tag)-records-\(i)")
            scrollStep()
        }
        relaunch(["-udOpen", "udada://settings"])
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        for i in 0..<10 {
            shot("\(tag)-settings-\(i)")
            scrollStep()
        }
    }
}
