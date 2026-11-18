import XCTest

/// 실제로 탭해서 끝까지 돈다. 스크린샷은 SHOT_DIR(=TEST_RUNNER_SHOT_DIR) 에 기기 이름을 붙여 저장.
final class FlowUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(speed: Int = 1) -> XCUIApplication {
        addUIInterruptionMonitor(withDescription: "권한") { alert in
            for label in ["허용", "Allow", "확인", "OK"] where alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            return false
        }
        let app = XCUIApplication()
        app.launchArguments = ["-udReset", "-udSpeed", "\(speed)"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = app.screenshot().pngRepresentation
        let att = XCTAttachment(data: png, uniformTypeIdentifier: "public.png"); att.name = name; att.lifetime = .keepAlways; add(att)
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device"
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(device)-\(name).png"))
        }
    }

    private func wait(_ e: XCUIElement, _ t: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(e.waitForExistence(timeout: t), "안 보임: \(e)", file: file, line: line)
    }

    /// 핵심 흐름: 소개 → 홈 → 쏟아내기(키보드) → 한 장씩 정리(날짜·파쇄) → 끝 → 숨 → 홈 소식·오늘 할 것 → 정리함
    func testDumpSortFinish() {
        let app = launch(speed: 40)
        wait(app.buttons["intro.go"]); shot(app, "0-intro")
        app.buttons["intro.go"].tap()
        wait(app.buttons["dump.start"]); shot(app, "1-home")
        app.buttons["dump.start"].tap()

        // 쏟아내기: 키보드가 떠도 [정리하기]가 키보드 위에서 눌려야 한다
        let editor = app.textViews["dump.text"]
        wait(editor)
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) { editor.tap() }
        editor.typeText("엄마한테 전화\n주말에 대청소\n월세 오르면 어떡하지\n헬스 할까 말까\n레포트 3장 쓰기")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "키보드가 안 떴다")
        let sort = app.buttons["dump.sort"]
        XCTAssertTrue(sort.isHittable, "키보드에 정리하기 키가 가렸다")
        XCTAssertLessThanOrEqual(sort.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        shot(app, "2-dump-keyboard")
        sort.tap()

        // 한 장씩: 제안대로 / 날짜 직접 / 파쇄
        wait(app.buttons["sort.suggest"]); shot(app, "3-sort")
        XCTAssertEqual(app.staticTexts["sort.card"].label, "엄마한테 전화")
        app.buttons["sort.suggest"].tap()                       // 지금
        wait(app.buttons["bin.date"]); app.buttons["bin.date"].tap()
        shot(app, "4-sort-date")
        app.buttons["when.weekend"].tap()                        // 주말에 대청소 → 이번 주말
        app.buttons["sort.suggest"].tap()                        // 월세 → 걱정 시간
        app.buttons["bin.drop"].tap()                            // 헬스 → 파쇄
        sleep(1)
        app.buttons["sort.suggest"].tap()                        // 레포트 → 날짜(내일 아침)

        // 끝
        wait(app.buttons["finish.done"], 6)
        app.tap() // 알림 권한 창이 떴으면 모니터가 처리
        sleep(1)
        XCTAssertEqual(app.staticTexts["finish.one"].label, "엄마한테 전화")
        shot(app, "5-finish")
        app.buttons["breath.go"].tap()
        wait(app.otherElements["breath"]); sleep(1); shot(app, "6-breath")
        wait(app.buttons["finish.done"], 15)                     // 배속이라 금방 끝나고 돌아온다
        app.buttons["finish.done"].tap()

        // 홈: 방금 소식 + 오늘 할 것 + 정리함
        wait(app.staticTexts["banner"])
        XCTAssertTrue(app.staticTexts["banner"].label.contains("5개"), app.staticTexts["banner"].label)
        XCTAssertTrue(app.staticTexts["엄마한테 전화"].exists, "지금 칸은 오늘 할 것에 보여야 한다")
        shot(app, "7-home-after")
        XCTAssertGreaterThanOrEqual(app.buttons["dump.start"].frame.minY, 60, "홈이 화면 안에 들어와야 한다")
        app.buttons["drawer"].tap()
        wait(app.staticTexts["걱정 시간 · 매일 21:30"])
        XCTAssertTrue(app.staticTexts["이번 주말"].exists)
        XCTAssertFalse(app.staticTexts["헬스 할까 말까"].exists, "버린 건 남지 않는다")
        shot(app, "8-drawer")
    }
}
