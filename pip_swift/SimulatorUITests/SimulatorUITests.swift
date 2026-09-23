import XCTest

final class SimulatorUITests: XCTestCase {
    func testLaunchNavigateAndBackgroundForeground() {
        let app = XCUIApplication()
        app.launchArguments = ["-globalRefresh.launchCelebration.seen.1.1.0.tutorial-v7", "YES",
                               "-globalRefresh.latestChangelog.seen.2.0.4", "YES"]
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
            if index == 2 {
                XCTAssertTrue(app.staticTexts["2.0.4"].waitForExistence(timeout: 8), "About must show the STRA 2.0 release")
                let openSettings = app.buttons["stra.about.openSettings"]
                XCTAssertTrue(openSettings.waitForExistence(timeout: 8), "About preferences button must be visible")
                for _ in 0..<3 where !openSettings.isHittable { app.swipeUp() }
                XCTAssertTrue(openSettings.isHittable)
                openSettings.tap()
                let closeSettings = app.buttons["stra.about.closeSettings"]
                XCTAssertTrue(closeSettings.waitForExistence(timeout: 8), "Preferences needs a visible close button")
                closeSettings.tap()
                let disappeared = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == false"),
                    object: closeSettings
                )
                XCTAssertEqual(XCTWaiter.wait(for: [disappeared], timeout: 5), .completed,
                               "About preferences should close without trapping touches")
            }
            if index == 1 {
                XCTAssertTrue(app.staticTexts["stra.motion.fps"].waitForExistence(timeout: 8))
                let mode = app.segmentedControls["stra.motion.mode"]
                XCTAssertTrue(mode.exists)
                mode.buttons.element(boundBy: 0).tap()
                XCTAssertTrue(mode.buttons.element(boundBy: 0).isSelected)
                mode.buttons.element(boundBy: 1).tap()
                XCTAssertTrue(app.descendants(matching: .any)["stra.motion.playState"].exists)
                let play = app.buttons["stra.motion.play"]
                XCTAssertTrue(play.isHittable)
                let initialPlaybackLabel = play.label
                play.tap()
                XCTAssertNotEqual(play.label, initialPlaybackLabel, "Playback control must update its visible state")
                play.tap()
                XCTAssertEqual(play.label, initialPlaybackLabel, "Playback must resume after pausing")
                app.swipeUp()
                app.swipeDown()
            }
            if index == 0 {
                XCTAssertTrue(app.staticTexts["Refresh Console"].exists || app.staticTexts["刷新控制台"].exists,
                              "Home must show the redesigned control room")
                let primary = app.buttons["stra.primaryPiP"]
                XCTAssertTrue(primary.waitForExistence(timeout: 8))
                XCTAssertTrue(primary.label.contains("开启悬浮窗") || primary.label.contains("Start Floating Window"),
                              "The unified primary action starts PiP while idle")
                XCTAssertFalse(app.buttons["stra.minimizePiP"].exists, "Minimize is now the same primary button")
                XCTAssertFalse(app.buttons["悬浮窗高度"].exists, "Home height editor tile must be removed")
                XCTAssertFalse(app.buttons["Window Height"].exists)
                XCTAssertFalse(app.buttons["切换样式"].exists)
                XCTAssertFalse(app.buttons["使用指南"].exists)
                XCTAssertFalse(app.buttons["stra.stopPiP"].exists,
                               "Stop is shown in the status card only during an active PiP session")
                let homeSettings = app.buttons["stra.home.closeSettings"]
                let openHomeSettings = app.buttons["stra.home.openSettings"]
                XCTAssertTrue(openHomeSettings.waitForExistence(timeout: 8),
                              "Home settings gear must remain accessible after control consolidation")
                XCTAssertTrue(openHomeSettings.isHittable, "Home settings gear must be tappable")
                openHomeSettings.tap()
                XCTAssertTrue(homeSettings.waitForExistence(timeout: 8),
                              "The translucent home preferences overlay must expose its close button")
                XCTAssertTrue(homeSettings.isHittable, "Close must be visible, not a hidden overlay")
                XCTAssertTrue(app.staticTexts["悬浮窗引擎"].exists || app.staticTexts["Floating Window"].exists,
                              "STRA settings must show the grouped engine section")
                homeSettings.tap()
                let homeDismissed = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == false"), object: homeSettings
                )
                XCTAssertEqual(XCTWaiter.wait(for: [homeDismissed], timeout: 5), .completed,
                               "Home preferences must be removed from hierarchy after close")
                XCTAssertTrue(primary.isHittable, "Dismissing settings must restore the main button")
            }
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
