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

    func testSevereHeatCancelsRecoveryAndCoolingDoesNotRestart() {
        controller.simulatorSeedStartingSession(height: 44)
        lock()
        controller.applyThermalState(.serious)
        unlock()
        controller.applyThermalState(.nominal)
        XCTAssertFalse(controller.simulatorSnapshot.resumePending)
        XCTAssertEqual(controller.simulatorSnapshot.restartAttempts, 0)
        XCTAssertFalse(controller.simulatorSnapshot.wantsPiP)
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
