import XCTest

/// 전체 화면 흐름: 비우기 · 걱정 시간 · 식히기 · 집중 · 하루 닫기 · 숏폼 앞.
/// 시계는 2026-11-15(일) 14:20 (지금 띠 = 낮), 예시 하루(-udSeed)로 시작한다. 식히기·집중 시계는 60배속.
/// 규칙으로 돈다(-udNoAI). 그래도 AI 가 켜진 기기에서도 돌도록 카드 글은 낱말(엄마·치과·관리비·헬스)로만 알아본다.
/// SHOT_DIR 환경 변수(TEST_RUNNER_SHOT_DIR)가 있으면 단계별 스크린샷을 남긴다.
final class FlowsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: 도우미

    private func launch(_ extra: [String] = [], seed: Bool = true, speed: Int = 60) {
        // -udNoAI: 기기 모델 속도에 흔들리지 않게 규칙으로 (AI 가 켜진 기기에서도 돌도록 카드는 낱말로 알아본다)
        var args = ["-udReset", "-udNow", "2026-11-15T14:20", "-udSpeed", "\(speed)", "-udSkipIntro", "-udNoAI"]
        if seed { args.append("-udSeed") }
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
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("flows-\(w)-\(name).png"))
        }
    }

    private func el(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    @discardableResult
    private func wait(_ id: String, _ t: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: t), "안 보임: \(id)", file: file, line: line)
        return e
    }

    /// 접근성 id 가 prefix 로 시작하고 이름에 낱말이 든 것 (하루 한 장의 줄 · 약속)
    private func item(_ prefix: String, _ word: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", prefix, word)).firstMatch
    }

    private func text(containing s: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    /// 합쳐진 카드 이름의 첫 조각 = 카드 글
    private func cardText(_ id: String = "sort.card") -> String {
        el(id).label.components(separatedBy: ", ").first ?? ""
    }

    /// "7장 중 2번째" · "4개 중 2번째" 가 n번째가 될 때까지
    private func waitPosition(_ n: Int, _ id: String = "sort.count", _ t: TimeInterval = 5) -> Bool {
        let end = Date().addingTimeInterval(t)
        repeat {
            if el(id).label.hasSuffix("중 \(n)번째") { return true }
            usleep(200_000)
        } while Date() < end
        return false
    }

    /// 덮개가 다 올라온 뒤에 민다 (올라오는 동안의 손짓은 시스템이 받지 않는다)
    private func settle() { sleep(1) }

    /// 내일(16일 월요일)로: 주 띠는 월요일부터라 다음 주로 한 번 민다
    private func showTomorrow() {
        if !el("week.16").waitForExistence(timeout: 1) { wait("week.strip").swipeLeft() }
        wait("week.16").tap()
    }

    private func total(_ id: String) -> Int {
        Int(el(id).label.prefix { $0.isNumber }) ?? -1
    }

    // MARK: 비우기

    /// 지금 → 오늘 지금 띠(첫 장은 오늘의 하나) · 날짜 → 고른 날(시각이 있으면 약속) · 걱정 → 걱정 상자 · 버리기 → 어디에도 없음.
    /// 끝에서 '숨 1분'은 고르기 없이 바로 숨으로 이어지고, 비우기 기록은 한 번만 남는다.
    func testDumpPlacesEachCard() {
        launch(["-udOpen", "udada://dump"])
        let field = wait("dump.text")
        field.tap()
        field.typeText("엄마한테 전화\n내일 3시 치과 예약\n다음 달 관리비 오르면 어떡하지\n헬스 등록할까 말까")
        shot("dump-write")
        wait("dump.sort").tap()
        if el("ai.thinking").waitForExistence(timeout: 1) { shot("dump-thinking") }
        wait("sort.card", 20)
        shot("dump-card")
        var placed = 0
        for _ in 0..<10 {
            guard el("sort.card").waitForExistence(timeout: 3) else { break }
            let t = cardText()
            if t.contains("엄마") {
                el("bin.now").tap()
            } else if t.contains("치과") {
                el("bin.date").tap()
                wait("when.back")
                shot("dump-when")
                app.buttons["내일 아침"].firstMatch.tap()
            } else if t.contains("관리비") {
                el("bin.worry").tap()
            } else if t.contains("헬스") {
                el("bin.drop").tap()
            } else {
                el("sort.suggest").tap()
            }
            placed += 1
            if el("finish.one").waitForExistence(timeout: 1.5) { break }
        }
        wait("finish.one")
        XCTAssertTrue(el("finish.one").label.contains("엄마"), "지금 할 단 하나 = 지금 칸의 첫 장: \(el("finish.one").label)")
        shot("dump-finish")

        el("finish.breath").tap()
        // 60배속이면 숨 1분이 1초라 끝 화면으로 본다 (고르기 화면 없이 바로 숨으로 갔다는 뜻)
        wait("rest.done", 12)
        XCTAssertFalse(el("rest.far").exists, "고르기 화면을 거치지 않음")
        el("rest.back").tap()

        wait("dump.start")
        XCTAssertEqual(el("worry.count").label, "2개", "걱정 칸 → 걱정 상자 (예시 1 + 새로 1)")
        XCTAssertTrue(el("dump.last").label.contains("\(placed)개 내려놓음"), "비우기 기록: \(el("dump.last").label)")
        XCTAssertTrue(el("mind.total").label.contains("\(placed)"), "기록은 한 번만: \(el("mind.total").label)")
        XCTAssertFalse(el("dump.draft").exists, "다 정했으면 쓰던 글이 안 남음")

        app.tabBars.buttons["오늘"].tap()
        let mom = item("row.", "엄마")
        XCTAssertTrue(mom.waitForExistence(timeout: 4), "지금 칸 → 오늘")
        XCTAssertTrue(mom.label.contains("오늘의 하나"), "첫 장은 오늘의 하나로 꽂힘: \(mom.label)")
        let afternoon = el("band.afternoon"), evening = el("band.evening")
        if afternoon.exists && evening.exists {
            XCTAssertTrue(mom.frame.minY > afternoon.frame.minY && mom.frame.minY < evening.frame.minY, "지금 띠(낮)에 들어감")
        }
        XCTAssertFalse(item("row.", "헬스").exists, "버린 건 어디에도 없음")
        XCTAssertFalse(item("row.", "관리비").exists, "걱정은 하루 한 장에 안 보임")

        showTomorrow()
        let dentist = item("event.", "치과")
        XCTAssertTrue(dentist.waitForExistence(timeout: 4), "날짜 칸 → 내일, 시각이 있으면 약속")
        XCTAssertTrue(dentist.label.contains("오후 3시"), "글의 시각을 그대로: \(dentist.label)")
        XCTAssertFalse(dentist.label.contains("내일 3시"), "날짜 낱말은 제목에서 빠짐: \(dentist.label)")
    }

    /// 밀어서 정하기(→ 제안대로 · ← 버리기) · 앞 장으로 · 파쇄 중 두 번 눌러도 한 장만 ·
    /// 중간에 닫으면 정한 것만 넣고 기록은 한 번, 남은 줄은 쓰던 글로 남아 다음에 이어 쓴다.
    func testDumpSwipeBackAndDraft() {
        launch(["-udOpen", "udada://dump"])
        wait("dump.example").tap()
        wait("dump.sort").tap()
        let card = wait("sort.card", 20)
        settle()
        let first = cardText()
        card.swipeRight()
        XCTAssertTrue(waitPosition(2), "오른쪽으로 밀면 제안대로, 다음 장: \(el("sort.count").label)")
        let second = cardText()
        XCTAssertNotEqual(first, second)
        el("sort.card").swipeLeft()
        XCTAssertTrue(waitPosition(3), "왼쪽으로 밀면 버리기")
        el("sort.back").tap()
        XCTAssertTrue(waitPosition(2), "앞 장으로")
        XCTAssertEqual(cardText(), second, "되돌린 장이 다시 나옴")

        el("bin.drop").doubleTap()
        XCTAssertTrue(waitPosition(3), "버리기")
        sleep(1)
        XCTAssertTrue(el("sort.count").label.hasSuffix("중 3번째"), "파쇄 중 두 번 눌러도 한 장만: \(el("sort.count").label)")
        shot("dump-sorting")

        el("dump.close").tap()
        wait("dump.start")
        XCTAssertTrue(el("dump.draft").waitForExistence(timeout: 3), "남은 줄은 쓰던 글로")
        XCTAssertTrue(el("dump.last").label.contains("2개 내려놓음"), "정한 2장만 기록: \(el("dump.last").label)")

        el("dump.start").tap()
        wait("dump.clear")
        let restored = (el("dump.text").value as? String) ?? ""
        XCTAssertFalse(restored.isEmpty, "쓰던 글로 이어서")
        XCTAssertFalse(restored.contains(first), "정한 줄은 빠짐")
        shot("dump-draft")
        el("dump.close").tap()
        wait("dump.start")
        XCTAssertTrue(el("dump.last").label.contains("2개 내려놓음"), "다시 닫아도 기록은 그대로: \(el("dump.last").label)")
        XCTAssertTrue(el("mind.total").label.contains("2"), "내려놓은 수: \(el("mind.total").label)")
    }

    // MARK: 걱정 시간

    /// 위기 낱말이면 상담 전화 카드가 바로 뜨고 할 일로 만들 수 없다. 내 손 안의 걱정은 작은 걸음이 오늘 할 일이 된다.
    func testWorryCrisisAndSmallStep() {
        launch(["-udOpen", "udada://dump"])
        let field = wait("dump.text")
        field.tap()
        field.typeText("요즘 다 사라지고 싶어\n발표 망치면 어떡하지")
        wait("dump.sort").tap()
        wait("sort.card", 20)
        for _ in 0..<4 {
            guard el("sort.card").waitForExistence(timeout: 2) else { break }
            if cardText().contains("사라지고") {
                XCTAssertTrue(el("sort.call.109").exists, "위기 줄이면 비우기에서도 바로 상담 전화")
                shot("dump-crisis")
            }
            el("bin.worry").tap()
            if el("finish.done").waitForExistence(timeout: 1.5) { break }
        }
        wait("finish.done").tap()
        XCTAssertEqual(wait("worry.count").label, "3개")
        el("worry.open").tap()
        var sawCrisis = false, madeTask = false
        for _ in 0..<5 {
            guard el("worry.card").waitForExistence(timeout: 4) else { break }
            let t = el("worry.card").label
            if t.contains("사라지고") {
                wait("worry.crisis")
                XCTAssertTrue(el("worry.call.109").exists, "상담 전화")
                XCTAssertFalse(el("worry.task").exists, "위기 글은 할 일로 만들지 않는다")
                shot("worry-crisis")
                sawCrisis = true
                el("worry.keep").tap()
            } else if t.contains("발표") {
                wait("worry.advice", 10)
                shot("worry-step")
                el("worry.task").tap()
                madeTask = true
            } else {
                wait("worry.advice", 10)
                el("worry.keep").tap()
            }
            if el("worry.end").waitForExistence(timeout: 1.2) { break }
        }
        XCTAssertTrue(sawCrisis && madeTask)
        wait("worry.end")
        el("worry.close").tap()
        XCTAssertEqual(wait("worry.count").label, "2개", "할 일로 옮긴 건 상자에서 빠짐")
    }

    // MARK: 하루 닫기

    /// → 내일 · ← 안 해 · 앞 장으로 되돌리기(지운 것도 살아남) · 끝은 도장과 한 줄.
    func testCloseDaySwipeUndoStamp() {
        launch(["-udOpen", "udada://close"])
        let card = wait("close.card")
        settle()
        let firstTitle = cardText("close.card")
        card.swipeRight()
        XCTAssertTrue(waitPosition(2, "close.count"), "오른쪽으로 밀면 내일: \(el("close.count").label)")
        let dropped = cardText("close.card")
        el("close.card").swipeLeft()
        XCTAssertTrue(waitPosition(3, "close.count"), "왼쪽으로 밀면 안 해")
        el("close.back").tap()
        XCTAssertTrue(waitPosition(2, "close.count"), "앞 장으로")
        XCTAssertEqual(cardText("close.card"), dropped, "지운 장이 되살아남")
        var i = 0
        while el("close.card").exists && i < 10 {
            el("close.later").tap()
            i += 1
            _ = el("close.end").waitForExistence(timeout: 0.8)
        }
        wait("close.end")
        wait("close.stamp")
        wait("close.line")
        sleep(1)
        shot("close-stamp")
        el("close.finish").tap()
        wait("now")
        XCTAssertFalse(item("row.", dropped).exists, "나중에로 보낸 건 오늘에서 빠짐")
        wait("later.open").tap()
        XCTAssertTrue(text(containing: dropped).waitForExistence(timeout: 3), "되살린 장은 나중에 함으로: \(dropped)")
        app.buttons["닫기"].firstMatch.tap()
        showTomorrow()
        XCTAssertTrue(item("row.", firstTitle).waitForExistence(timeout: 4), "내일로 보낸 장: \(firstTitle)")
    }

    // MARK: 식히기 · 집중 · 숏폼 앞

    /// 맑기 전후 · 3분 멀리 보기 · 한 번 더
    func testRestClarityAndAgain() {
        launch(["-udOpen", "udada://rest"])
        let before = wait("rest.before")
        before.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        shot("rest-pick")
        el("rest.far").tap()
        wait("rest.clock")
        shot("rest-far")
        wait("rest.done", 12)
        el("rest.after").coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        XCTAssertTrue(text(containing: "→").waitForExistence(timeout: 2), "맑기 전 → 후")
        shot("rest-end")
        el("rest.again").tap()
        wait("rest.clock")
        wait("rest.done", 12)
        el("rest.back").tap()
        wait("now")
    }

    /// 지금 줄의 일로 집중: 예상 · 첫 동작. 그만이면 할 일은 그대로, 끝냈어면 예상과 실제를 견줘 보이고 토스트.
    func testFocusStopThenFinish() {
        launch(["-udOpen", "udada://focus"])
        wait("focus.clock")
        XCTAssertTrue(el("focus.plan").label.contains("예상 15분"), el("focus.plan").label)
        XCTAssertTrue(el("focus.step").waitForExistence(timeout: 8), "첫 동작 한 줄")
        sleep(2)
        shot("focus")
        el("focus.stop").tap()
        wait("toast")
        XCTAssertTrue(text(containing: "집중했어").exists, "그만: 한 만큼 알려 줌")
        XCTAssertTrue(el("row.메일 답장").exists, "그만이면 할 일은 그대로")
        wait("now.start").tap()
        wait("focus.done").tap()
        wait("focus.summary")
        shot("focus-summary")
        wait("toast", 8)
        XCTAssertTrue(text(containing: "예상 15분").exists, "예상 대 실제 토스트")
    }

    /// 남은 할 일이 없으면 고르기 화면 → 이름 없이 시작(예상 25분) → 끝냈어
    func testFocusChooserFree() {
        launch(["-udOpen", "udada://focus"], seed: false)
        wait("focus.free")
        shot("focus-chooser")
        el("focus.free").tap()
        wait("focus.clock")
        XCTAssertTrue(el("focus.plan").label.contains("예상 25분"), el("focus.plan").label)
        el("focus.done").tap()
        wait("focus.summary")
        wait("toast", 8)
    }

    /// 숏폼 앞: 지금 줄 한 장 · 1분 숨은 고르기 없이 바로 (제 속도로 숨 원을 보고, 그만으로 일찍 끝내기)
    func testGateToBreath() {
        launch(["-udOpen", "udada://gate"], speed: 1)
        wait("gate.now")
        shot("gate")
        el("gate.breath").tap()
        wait("rest.breath.word", 8)
        sleep(3)
        shot("rest-breath")
        el("rest.stop").tap()
        wait("rest.done", 6)
        el("rest.back").tap()
        wait("now")
    }
}
