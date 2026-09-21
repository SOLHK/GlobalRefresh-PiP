import XCTest

final class SimulatorUITests: XCTestCase {
    func testLaunchNavigateAndBackgroundForeground() {
        let app = XCUIApplication()
        app.launchArguments = ["-globalRefresh.launchCelebration.seen.1.1.0.tutorial-v7", "YES",
                               "-globalRefresh.latestChangelog.seen.1.1.1-beta4", "YES"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))
        if app.alerts.firstMatch.waitForExistence(timeout: 3) {
            app.alerts.firstMatch.buttons.firstMatch.tap()
        }
        XCTAssertEqual(tabs.buttons.count, 3)
        for index in [2, 1, 0] {
            let tab = tabs.buttons.element(boundBy: index)
            XCTAssertTrue(tab.isHittable)
            tab.tap()
            XCTAssertTrue(tab.isSelected)
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "tab-\(index)"
            capture.lifetime = .keepAlways
            add(capture)
        }
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(tabs.exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "foreground-restored"
        capture.lifetime = .keepAlways
        add(capture)
    }
}
