import XCTest

final class MusicTimelyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    @MainActor
    func testAssignShowsSongTranslation() {
        let app = launch()
        XCTAssertTrue(app.buttons["assign.start"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["assign.start"].label, "약 7곡 분량으로 시작")
        app.buttons["assign.chip.10"].tap()
        XCTAssertEqual(app.buttons["assign.start"].label, "약 3곡 분량으로 시작")
    }

    @MainActor
    func testSessionFlowFromStartToNewSession() {
        let app = launch()
        let title = app.textFields["assign.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("기획안 첫 문단 쓰기")
        app.buttons["assign.start"].tap()

        let panel = app.otherElements["session.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(panel.label.contains("분량 남음"), panel.label)

        app.buttons["session.pause"].tap()
        XCTAssertTrue(app.staticTexts["session.pausedLabel"].waitForExistence(timeout: 3))
        app.buttons["session.resume"].tap()
        XCTAssertTrue(app.buttons["session.pause"].waitForExistence(timeout: 3))

        app.buttons["session.finish"].tap()
        let headline = app.staticTexts["result.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        XCTAssertFalse(headline.label.contains("들었"), headline.label)

        app.buttons["result.again"].tap()
        XCTAssertTrue(app.buttons["assign.start"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["assign.title"].value as? String, "기획안 첫 문단 쓰기")
    }

    @MainActor
    func testMemoDuringSessionKeepsTimerRunning() {
        let app = launch()
        XCTAssertTrue(app.buttons["assign.start"].waitForExistence(timeout: 10))
        app.buttons["assign.start"].tap()
        XCTAssertTrue(app.buttons["session.memo"].waitForExistence(timeout: 5))
        app.buttons["session.memo"].tap()
        let field = app.textFields["memo.text"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("참고 자료 링크 다시 찾기")
        app.buttons["editor.primary"].tap()
        XCTAssertTrue(app.buttons["session.pause"].waitForExistence(timeout: 3))
        app.buttons["session.finish"].tap()
        XCTAssertTrue(app.staticTexts["참고 자료 링크 다시 찾기"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCustomMinutesRejectsOutOfRange() {
        let app = launch()
        XCTAssertTrue(app.buttons["assign.chip.custom"].waitForExistence(timeout: 10))
        app.buttons["assign.chip.custom"].tap()
        let field = app.textFields["custom.minutes"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("241")
        XCTAssertTrue(app.staticTexts["custom.error"].exists)
        XCTAssertFalse(app.buttons["editor.primary"].isEnabled)
    }

    /// H1 회귀: 노이즈 렌더 블록이 오디오 스레드에서 돌아도 앱이 살아 있어야 한다.
    @MainActor
    func testNoisePlaybackKeepsAppAlive() {
        let app = launch()
        XCTAssertTrue(app.buttons["assign.music"].waitForExistence(timeout: 10))
        app.buttons["assign.music"].tap()
        XCTAssertTrue(app.buttons["music.noise.pink"].waitForExistence(timeout: 3))
        app.buttons["music.noise.pink"].tap()
        app.buttons["music.noiseToggle"].tap()
        sleep(3)
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertEqual(app.buttons["music.noiseToggle"].label, "소리 멈추기")
        app.buttons["music.noiseToggle"].tap()
        app.buttons["완료"].tap()
        app.buttons["assign.start"].tap()
        XCTAssertTrue(app.otherElements["session.panel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["session.panel"].label.contains("남음"))
        XCTAssertFalse(app.otherElements["session.panel"].label.contains("곡"))
    }
}
