import XCTest

/// 피그마 비교용 화면 캡처. `TEST_RUNNER_CAPTURE_SCREENS=1`일 때만 실행한다.
final class ScreenCaptureTests: XCTestCase {
    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCaptureScreens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURE_SCREENS"] == "1", "화면 캡처 전용")
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let title = app.textFields["assign.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("기획안 첫 문단 쓰기\n")
        capture(app, "01-assign")

        app.buttons["assign.start"].tap()
        XCTAssertTrue(app.otherElements["session.panel"].waitForExistence(timeout: 5))
        sleep(2)
        capture(app, "02-running")

        app.buttons["session.pause"].tap()
        XCTAssertTrue(app.staticTexts["session.pausedLabel"].waitForExistence(timeout: 3))
        sleep(1)
        capture(app, "03-paused")
        app.buttons["session.resume"].tap()

        app.buttons["session.memo"].tap()
        let memo = app.textFields["memo.text"]
        XCTAssertTrue(memo.waitForExistence(timeout: 3))
        memo.typeText("참고 자료 링크 다시 찾기")
        capture(app, "04-memo")
        app.buttons["editor.primary"].tap()

        app.buttons["session.more"].tap()
        app.buttons["곡 표시 맞추기"].tap()
        XCTAssertTrue(app.textFields["correction.value"].waitForExistence(timeout: 3))
        capture(app, "05-correction")
        app.buttons["editor.cancel"].tap()

        app.buttons["session.more"].tap()
        app.buttons["음악 바꾸기"].tap()
        XCTAssertTrue(app.buttons["music.none"].waitForExistence(timeout: 3))
        capture(app, "06-music")
        app.buttons["완료"].tap()

        app.buttons["session.finish"].tap()
        XCTAssertTrue(app.staticTexts["result.headline"].waitForExistence(timeout: 5))
        capture(app, "07-result")

        app.buttons["result.next"].tap()
        XCTAssertTrue(app.buttons["assign.settings"].waitForExistence(timeout: 5))
        app.buttons["assign.settings"].tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 3))
        capture(app, "08-settings")
    }

    @MainActor
    func testCaptureDarkAndLimit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURE_SCREENS"] == "1", "화면 캡처 전용")
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTheme", "dark"]
        app.launch()
        XCTAssertTrue(app.buttons["assign.start"].waitForExistence(timeout: 10))
        capture(app, "09-dark-assign")

        app.buttons["assign.chip.custom"].tap()
        let field = app.textFields["custom.minutes"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("1")
        app.buttons["editor.primary"].tap()
        app.buttons["assign.start"].tap()
        XCTAssertTrue(app.otherElements["session.panel"].waitForExistence(timeout: 5))
        capture(app, "10-dark-running")
        XCTAssertTrue(app.buttons["session.extend.5"].waitForExistence(timeout: 75))
        sleep(1)
        capture(app, "11-dark-limit")
    }
}
