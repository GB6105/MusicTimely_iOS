import XCTest

/// 잠금화면 Live Activity·Dynamic Island 캡처. `TEST_RUNNER_CAPTURE_SCREENS=1`일 때만 실행한다.
final class LockScreenCaptureTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURE_SCREENS"] == "1", "화면 캡처 전용")
        continueAfterFailure = false
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func run(seed: String, prefix: String, pause: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiLiveActivity", "-uiSeed", seed]
        app.launch()
        XCTAssertTrue(app.otherElements["session.panel"].waitForExistence(timeout: 10))
        if pause {
            app.buttons["session.pause"].tap()
            XCTAssertTrue(app.buttons["session.resume"].waitForExistence(timeout: 3))
        }
        sleep(2)
        XCUIDevice.shared.press(.home)
        sleep(3)
        capture("\(prefix)-island")
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(3)
        capture("\(prefix)-lock")
        app.terminate()
    }

    @MainActor
    func testCaptureRunning() { run(seed: "running", prefix: "la-running") }

    @MainActor
    func testCaptureLastUnit() { run(seed: "lastUnit", prefix: "la-last") }

    @MainActor
    func testCapturePaused() { run(seed: "running", prefix: "la-paused", pause: true) }
}
