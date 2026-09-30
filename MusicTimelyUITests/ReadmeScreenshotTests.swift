import XCTest

/// README 스크린샷. `TEST_RUNNER_CAPTURE_SCREENS=1`일 때만 실행한다.
final class ReadmeScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURE_SCREENS"] == "1", "화면 캡처 전용")
        continueAfterFailure = false
    }

    @MainActor
    private func launch(seed: String? = nil, theme: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        if let seed { app.launchArguments += ["-uiSeed", seed] }
        if let theme { app.launchArguments += ["-uiTheme", theme] }
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testReadmeScreens() {
        var app = launch()
        let title = app.textFields["assign.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("기획안 첫 문단 쓰기\n")
        capture(app, "assign")

        app = launch(seed: "running")
        XCTAssertTrue(app.otherElements["session.panel"].waitForExistence(timeout: 10))
        sleep(2)
        capture(app, "running")
        app.buttons["session.pause"].tap()
        XCTAssertTrue(app.staticTexts["session.pausedLabel"].waitForExistence(timeout: 3))
        sleep(1)
        capture(app, "paused")

        app = launch(seed: "lastUnit")
        XCTAssertTrue(app.otherElements["session.panel"].waitForExistence(timeout: 10))
        sleep(1)
        capture(app, "last-unit")
        app.buttons["session.memo"].tap()
        let memo = app.textFields["memo.text"]
        XCTAssertTrue(memo.waitForExistence(timeout: 3))
        memo.typeText("참고 자료 링크 다시 찾기")
        capture(app, "memo")

        app = launch(seed: "result")
        XCTAssertTrue(app.staticTexts["result.headline"].waitForExistence(timeout: 10))
        capture(app, "result")

        app = launch()
        XCTAssertTrue(app.buttons["assign.music"].waitForExistence(timeout: 10))
        app.buttons["assign.music"].tap()
        XCTAssertTrue(app.buttons["music.none"].waitForExistence(timeout: 3))
        capture(app, "music")

        app = launch(seed: "running", theme: "dark")
        XCTAssertTrue(app.otherElements["session.panel"].waitForExistence(timeout: 10))
        sleep(2)
        capture(app, "dark-running")

        app = launch(theme: "navy")
        XCTAssertTrue(app.buttons["assign.start"].waitForExistence(timeout: 10))
        capture(app, "navy-assign")
    }
}
