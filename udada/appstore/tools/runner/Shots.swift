import XCTest

/// App Store 스크린샷용 — 설치된 우다다를 번들 ID로 띄워, 손으로 눌러야 하는 화면을 만든 뒤 SHOT_DIR 에 PNG 로 남긴다.
/// 환경 변수(xcodebuild 에는 TEST_RUNNER_ 를 붙여 넘긴다): SHOT_DIR · NOW(yyyy-MM-ddTHH:mm) · ADD_TEXT
final class Shots: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "io.github.bunhine0452.udada")
    var env: [String: String] { ProcessInfo.processInfo.environment }
    var dir: String { env["SHOT_DIR"] ?? NSTemporaryDirectory() }

    override func setUp() { continueAfterFailure = true }

    func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
    }
    func el(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    @discardableResult func wait(_ id: String, _ t: TimeInterval = 15) -> XCUIElement {
        let e = el(id); _ = e.waitForExistence(timeout: t); return e
    }
    func launch(_ args: [String]) {
        app.terminate()
        app.launchArguments = args
        app.launch()
    }
    /// 앱 그룹에 미리 넣어 둔 '써 본 사람' 데이터를 그대로 쓴다
    func lived(_ fallback: String) -> [String] {
        ["-udSkipIntro", "-udNow", env["NOW"].flatMap { $0.isEmpty ? nil : $0 } ?? fallback]
    }
    /// 앱이 가진 예시 하루로 새로 시작
    var seeded: [String] { ["-udReset", "-udSeed", "-udSkipIntro", "-udNow", "2026-11-12T14:20"] }

    /// 2번: 한 줄 넣기 미리보기
    func testA_Add() {
        launch(lived("2026-11-12T14:20"))
        let field = wait("add.field")
        field.tap()
        sleep(1)
        field.typeText(env["ADD_TEXT"].flatMap { $0.isEmpty ? nil : $0 } ?? "내일 3시 치과")
        wait("add.preview")
        sleep(1)
        shot("add")
    }

    /// 한 줄에 여러 일: 나눠 넣기 미리보기
    func testJ_Split() {
        launch(lived("2026-11-12T14:20"))
        let field = wait("add.field")
        field.tap()
        sleep(1)
        field.typeText("엄마한테 전화하고 내일 은행 가야 되고 월세 오르면 어떡하지")
        wait("add.split")
        sleep(5) // 모델이 다듬은 카드가 올 때까지
        shot("split")
    }

    /// 넣기 줄의 Apple Intelligence 판
    func testK_AIPanel() {
        launch(lived("2026-11-12T14:20"))
        wait("ai.open").tap()
        wait("ai.ask")
        sleep(2)
        shot("aipanel")
    }

    /// 5번: 하루 닫기 — 내일 · 나중에 · 안 해를 차례로 골라 도장까지
    func testC_Close() {
        launch(lived("2026-11-12T21:40") + ["-udOpen", "udada://close"])
        wait("close.card")
        sleep(1)
        shot("close-card")
        let order = ["close.tomorrow", "close.later", "close.drop"]
        var i = 0
        while el("close.card").exists && i < 12 {
            el(order[i % 3]).tap()
            i += 1
            _ = el("close.end").waitForExistence(timeout: 0.8)
        }
        wait("close.end")
        sleep(3)
        shot("close-stamp")
    }

    /// 3번: 비우기 — 예시 글을 넣고 카드마다 제안을 남긴다
    func testH_DumpAll() {
        launch(seeded + ["-udOpen", "udada://dump"])
        wait("dump.example").tap()
        sleep(1)
        shot("dumpall-write")
        el("dump.sort").tap()
        wait("sort.card", 20)
        sleep(2)
        var i = 1
        while el("sort.card").exists && i <= 9 {
            shot("dumpall-card-\(i)")
            el("sort.suggest").tap()
            sleep(1)
            i += 1
        }
        wait("finish.one", 10)
        sleep(3)
        shot("dumpall-finish")
    }

    /// 8번: 설정 → 근거 보기
    func testI_Evidence() {
        launch(lived("2026-11-12T14:20") + ["-udOpen", "udada://settings"])
        let e = el("settings.evidence")
        var n = 0
        while !(e.exists && e.isHittable) && n < 12 { app.swipeUp(velocity: .slow); n += 1 }
        e.tap()
        sleep(2)
        shot("evidence")
    }
}
