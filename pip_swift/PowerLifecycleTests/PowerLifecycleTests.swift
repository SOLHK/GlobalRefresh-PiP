import XCTest
import AVKit
@testable import pip_swift

@MainActor
final class PowerLifecycleTests: XCTestCase {
    private var controller: ViewController!

    override func setUp() async throws {
        controller = ViewController()
        controller.loadViewIfNeeded()
    }

    override func tearDown() async throws {
        controller.viewWillDisappear(false)
        controller.stopForFullDataReset()
        NotificationCenter.default.removeObserver(controller!)
        controller = nil
    }

    private func lock() {
        NotificationCenter.default.post(name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
    }
    private func unlock() {
        NotificationCenter.default.post(name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
    }

    func testIdleLockUnlockDoesNotStartUnrequestedPiP() {
        lock()
        XCTAssertTrue(controller.shouldPauseForPower)
        XCTAssertFalse(controller.simulatorSnapshot.resumePending)
        unlock()
        XCTAssertFalse(controller.shouldPauseForPower)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 0)
        XCTAssertFalse(controller.simulatorSnapshot.wantsPiP)
    }

    func testLockDuringStartupCancelsWorkAndRetainsRecoveryIntent() {
        controller.simulatorSeedStartingSession(height: 0.1)
        lock()
        let state = controller.simulatorSnapshot
        XCTAssertTrue(state.resumePending)
        XCTAssertFalse(state.wantsPiP)
        XCTAssertFalse(state.hasPendingStart)
        XCTAssertFalse(state.hasContentTimers)
        XCTAssertFalse(state.audioPlaying)
        XCTAssertFalse(controller.needsBackgroundRefreshDriver)
        XCTAssertEqual(state.savedHeight, 0.1)
    }

    func testUnlockInvokesAutomaticRecoveryWithoutButtonPress() {
        controller.simulatorSeedStartingSession(height: 0.1)
        lock()
        unlock()
        XCTAssertFalse(controller.shouldPauseForPower)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 1)
    }

    func testRepeatedUnlockDoesNotCreateRestartLoop() {
        controller.simulatorSeedStartingSession(height: 0.1)
        lock()
        unlock()
        unlock()
        unlock()
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 1)
    }

    func testExplicitStopCancelsUnlockRecovery() {
        controller.simulatorSeedStartingSession(height: 0.1)
        lock()
        controller.simulatorUserStop()
        unlock()
        XCTAssertFalse(controller.simulatorSnapshot.resumePending)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 0)
        XCTAssertFalse(controller.simulatorSnapshot.wantsPiP)
    }

    func testHeatRecoveryWaitsForCooldown() {
        controller.simulatorSeedStartingSession(height: 44)
        controller.applyThermalState(.serious)
        XCTAssertTrue(controller.simulatorThermalRecoveryPending)
        XCTAssertFalse(controller.simulatorSnapshot.hasContentTimers)
        controller.applyThermalState(.nominal)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 0)
        controller.simulatorFinishCooling()
        XCTAssertFalse(controller.simulatorThermalRecoveryPending)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 1)
    }

    func testIdleHeatDoesNotStartAnUnrequestedSession() {
        controller.applyThermalState(.critical)
        controller.applyThermalState(.nominal)
        controller.simulatorFinishCooling()
        XCTAssertFalse(controller.simulatorThermalRecoveryPending)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 0)
    }

    func testManualStopCancelsThermalRecovery() {
        controller.simulatorSeedStartingSession(height: 44)
        controller.applyThermalState(.serious)
        controller.applyThermalState(.nominal)
        controller.simulatorUserStop()
        controller.simulatorFinishCooling()
        XCTAssertFalse(controller.simulatorThermalRecoveryPending)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 0)
    }

    func testCoolingWhileLockedWaitsForUnlock() {
        controller.simulatorSeedStartingSession(height: 0.1)
        lock()
        controller.applyThermalState(.serious)
        controller.applyThermalState(.nominal)
        controller.simulatorFinishCooling()
        XCTAssertTrue(controller.simulatorSnapshot.resumePending)
        XCTAssertEqual(controller.simulatorSnapshot.savedHeight, 0.1)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 0)
        unlock()
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 1)
    }

    func testWarmingAgainCancelsCooldownDeadline() {
        controller.simulatorSeedStartingSession(height: 44)
        controller.applyThermalState(.serious)
        controller.applyThermalState(.nominal)
        controller.applyThermalState(.fair)
        controller.simulatorFinishCooling()
        XCTAssertTrue(controller.simulatorThermalRecoveryPending)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 0)
        controller.applyThermalState(.nominal)
        controller.simulatorFinishCooling()
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 1)
    }

    func testMainRefreshDriverIsRemovedOnLockNotification() {
        let tabs = MainTabBarController()
        tabs.loadViewIfNeeded()
        let home = tabs.viewControllers!.first as! ViewController
        home.loadViewIfNeeded()
        lock()
        XCTAssertFalse(tabs.simulatorHasRefreshDriver)
        home.stopForFullDataReset()
        NotificationCenter.default.removeObserver(home)
        NotificationCenter.default.removeObserver(tabs)
    }

    func testMainRefreshDriverRestartsOnUnlockWithoutForegroundActivation() {
        let tabs = MainTabBarController()
        tabs.loadViewIfNeeded()
        let home = tabs.viewControllers!.first as! ViewController
        home.loadViewIfNeeded()
        XCTAssertTrue(tabs.simulatorHasRefreshDriver)
        lock()
        XCTAssertFalse(tabs.simulatorHasRefreshDriver)
        // Do not send UIApplication.didBecomeActiveNotification or visit the app.
        unlock()
        XCTAssertTrue(tabs.simulatorHasRefreshDriver)
        home.stopForFullDataReset()
        NotificationCenter.default.removeObserver(home)
        NotificationCenter.default.removeObserver(tabs)
    }

    func testBackgroundHomeUpdatesCannotRestartRuntimeUITimer() {
        controller.viewDidAppear(false)
        controller.simulatorSeedRuntime(startedAt: Date().addingTimeInterval(-90))
        XCTAssertTrue(controller.simulatorRuntimeUIState.hasTimer)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        controller.simulatorRefreshHome()
        XCTAssertFalse(controller.simulatorRuntimeUIState.hasTimer)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(controller.simulatorRuntimeUIState.hasTimer)
        XCTAssertGreaterThanOrEqual(controller.simulatorRuntimeUIState.duration, 90)
    }

    func testHiddenHomeStopsRuntimeTimerAndRestoresElapsedTime() {
        controller.viewDidAppear(false)
        controller.simulatorSeedRuntime(startedAt: Date().addingTimeInterval(-90))
        XCTAssertTrue(controller.simulatorRuntimeUIState.hasTimer)
        controller.viewWillDisappear(false)
        controller.simulatorRefreshHome()
        XCTAssertFalse(controller.simulatorRuntimeUIState.hasTimer)
        controller.viewDidAppear(false)
        XCTAssertTrue(controller.simulatorRuntimeUIState.hasTimer)
        XCTAssertGreaterThanOrEqual(controller.simulatorRuntimeUIState.duration, 90)
    }

    func testRetainedRuntimeDoesNotRestartTimerWhileLocked() {
        controller.viewDidAppear(false)
        lock()
        // Model the retained session timestamp of a paused, established PiP.
        controller.simulatorSeedRuntime(startedAt: Date().addingTimeInterval(-90))
        controller.simulatorRefreshHome()
        XCTAssertFalse(controller.simulatorRuntimeUIState.hasTimer)
        unlock()
        XCTAssertTrue(controller.simulatorRuntimeUIState.hasTimer)
    }

    func testWatchdogDetectingLockPreservesAutomaticRecovery() {
        controller.simulatorSeedStartingSession(height: 0.1)
        controller.simulatorWatchdogDetectsLock()
        XCTAssertTrue(controller.simulatorSnapshot.resumePending)
        XCTAssertFalse(controller.simulatorSnapshot.hasPendingStart)
        XCTAssertFalse(controller.simulatorSnapshot.hasContentTimers)
        XCTAssertEqual(controller.simulatorSnapshot.savedHeight, 0.1)
        unlock()
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 1)
    }

    func testUserStopAfterWatchdogLockPreventsAutomaticRecovery() {
        controller.simulatorSeedStartingSession(height: 0.1)
        controller.simulatorWatchdogDetectsLock()
        controller.simulatorUserStop()
        unlock()
        XCTAssertFalse(controller.simulatorSnapshot.resumePending)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 0)
    }

    func testActualPiPStartWhenSimulatorSupportsIt() async throws {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            throw XCTSkip("This simulator does not support actual PiP. Lock lifecycle tests inject public notifications; they do not verify physical screen locking.")
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { controller.stopForFullDataReset(); window.isHidden = true }
        controller.simulatorUserStart()
        for _ in 0..<100 {
            if controller.simulatorSnapshot.actualPiPActive { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(controller.simulatorSnapshot.actualPiPActive, "PiP claims support but did not start in the simulator; inspect runtime logs.")
    }
}

