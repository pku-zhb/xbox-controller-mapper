import XCTest
import CoreGraphics
@testable import ControllerKeys

final class DesktopTouchpadTuningTests: XCTestCase {
    func testSettingsMigrateClampAndRoundTrip() throws {
        let defaults = try JSONDecoder().decode(TouchpadTuning.self, from: Data("{}".utf8))
        XCTAssertEqual(defaults.fastGain, 3)
        XCTAssertEqual(defaults.zoomSteps, 1)
        let invalid = try JSONDecoder().decode(TouchpadTuning.self, from: Data("{\"liftGuard\":9,\"leftJitter\":-1,\"zoomSteps\":999}".utf8))
        XCTAssertEqual(invalid.liftGuard, 0.06)
        XCTAssertEqual(invalid.leftJitter, 0)
        XCTAssertEqual(invalid.zoomSteps, 3)
        XCTAssertEqual(try JSONDecoder().decode(TouchpadTuning.self, from: JSONEncoder().encode(invalid)), invalid)
        let legacy = try JSONDecoder().decode(RepeatMapping.self, from: Data("{\"enabled\":true,\"interval\":0.083333}".utf8))
        XCTAssertEqual(legacy.initialDelay, 0.35)
    }

    func testWideAccelerationHasIndependentSlowAndFastGain() {
        let slow = JoystickMath.touchpadAccelerationGain(distance: 0.001, elapsed: 0.01, amount: 1, slowGain: 0.15, fastGain: 3)
        let fast = JoystickMath.touchpadAccelerationGain(distance: 0.1, elapsed: 0.01, amount: 1, slowGain: 0.15, fastGain: 3)
        XCTAssertEqual(slow, 0.15, accuracy: 0.0001)
        XCTAssertEqual(fast, 3, accuracy: 0.0001)
        XCTAssertEqual(JoystickMath.touchpadAccelerationGain(distance: 0.1, elapsed: 0.01, amount: 0, slowGain: 0.15, fastGain: 3), 1)
    }

    func testTapIsCancelledBySlidingEvenAfterReturningToStart() {
        var tracker = SteamControllerTouchpadTapTracker()
        var count = 0
        let touch: (Float, Bool) -> SteamControllerTouchpadState = { .init(x: $0, y: 0, isTouching: $1, isPressed: false) }
        tracker.update(state: touch(0, true), now: 0, maxDuration: 0.25, maxTravel: 0.05) { _ in count += 1 }
        tracker.update(state: touch(0.1, true), now: 0.05, maxDuration: 0.25, maxTravel: 0.05) { _ in count += 1 }
        tracker.update(state: touch(0, true), now: 0.1, maxDuration: 0.25, maxTravel: 0.05) { _ in count += 1 }
        tracker.update(state: touch(0, false), now: 0.15, maxDuration: 0.25, maxTravel: 0.05) { _ in count += 1 }
        XCTAssertEqual(count, 0)
        tracker.update(state: touch(0, true), now: 1, maxDuration: 0.25, maxTravel: 0.05) { _ in count += 1 }
        tracker.update(state: touch(0, false), now: 1.1, maxDuration: 0.25, maxTravel: 0.05) { _ in count += 1 }
        XCTAssertEqual(count, 1)
    }

    func testPressStaysPutUntilDragAndReleaseDoesNotJump() {
        var filter = SteamTouchpadMotionFilter()
        func sample(_ x: Float, _ pressed: Bool) -> SteamControllerTouchpadState {
            .init(x: x, y: 0, isTouching: true, isPressed: pressed)
        }
        _ = filter.update(sample(0.3, false), now: 0)
        let click = filter.update(sample(0.34, true), now: 0.05, clickSettle: 0.035, dragTravel: 0.06)
        XCTAssertTrue(click.isPressed)
        XCTAssertEqual(click.x, 0.3, accuracy: 0.0001)
        let wobble = filter.update(sample(0.36, true), now: 0.06, clickSettle: 0.035, dragTravel: 0.06)
        XCTAssertEqual(wobble.x, 0.3, accuracy: 0.0001)
        let startDrag = filter.update(sample(0.55, true), now: 0.09, clickSettle: 0.035, dragTravel: 0.06)
        XCTAssertEqual(startDrag.x, 0.3, accuracy: 0.0001)
        let drag = filter.update(sample(0.6, true), now: 0.11, clickSettle: 0.035, dragTravel: 0.06)
        XCTAssertGreaterThan(drag.x, 0.3)
        let up = filter.update(sample(0.61, false), now: 0.12, clickSettle: 0.035, dragTravel: 0.06)
        XCTAssertFalse(up.isPressed)
        XCTAssertEqual(up.x, drag.x, accuracy: 0.0001)
    }

    func testTapWobbleNeverMovesAndSlideDoesNotReplaySuppressedMotion() {
        var filter = SteamTouchpadMotionFilter()
        func update(_ x: Float, _ time: Double, pressed: Bool = false, touching: Bool = true) -> SteamControllerTouchpadState {
            filter.update(.init(x: x, y: 0, isTouching: touching, isPressed: pressed), now: time,
                          radius: 0.012, guardTime: 0, clickSettle: 0.035, dragTravel: 0.06,
                          tapDuration: 0.25, tapTravel: 0.05)
        }
        XCTAssertEqual(update(0.3, 0).x, 0.3, accuracy: 0.0001)
        XCTAssertEqual(update(0.34, 0.1).x, 0.3, accuracy: 0.0001)
        _ = update(0, 0.15, touching: false)
        XCTAssertEqual(update(0.3, 1).x, 0.3, accuracy: 0.0001)
        XCTAssertEqual(update(0.4, 1.1).x, 0.3, accuracy: 0.0001)
        XCTAssertGreaterThan(update(0.45, 1.12).x, 0.3)
        _ = update(0, 1.2, touching: false)
        // A finger landing already pressed must retain its real baseline.
        XCTAssertEqual(update(0.7, 2, pressed: true).x, 0.7, accuracy: 0.0001)
        XCTAssertEqual(update(0.72, 2.01, pressed: true).x, 0.7, accuracy: 0.0001)
    }

    func testNativeZoomIsBoundedAndStepZoomHasNoBurstOrReleaseBacklog() {
        var tuning = TouchpadTuning()
        tuning.zoomStepTravel = 0.1
        var zoom = DesktopZoomDynamics()
        let native = zoom.update(distance: 10, pan: 0, touching: true, native: true, ratio: 1.95, now: 0, tuning: tuning)
        XCTAssertTrue(native.begin)
        XCTAssertLessThanOrEqual(abs(native.magnification), 0.06)
        XCTAssertTrue(zoom.update(distance: 0, pan: 0, touching: false, native: true, ratio: 1.95, now: 0.1, tuning: tuning).end)
        XCTAssertEqual(zoom.update(distance: 1, pan: 0, touching: true, native: false, ratio: 1.95, now: 1, tuning: tuning).steps, 1)
        XCTAssertEqual(zoom.update(distance: 1, pan: 0, touching: true, native: false, ratio: 1.95, now: 1.05, tuning: tuning).steps, 0)
        XCTAssertEqual(zoom.update(distance: 0, pan: 0, touching: true, native: false, ratio: 1.95, now: 1.3, tuning: tuning).steps, 0)
        _ = zoom.update(distance: 0, pan: 0, touching: false, native: false, ratio: 1.95, now: 1.31, tuning: tuning)
        XCTAssertEqual(zoom.update(distance: 0.01, pan: 0, touching: true, native: false, ratio: 1.95, now: 2, tuning: tuning).steps, 0)
    }

    func testMomentumStartsOnlyAfterFlickAndStopsOnRetouch() {
        let tuning = TouchpadTuning()
        var scroll = DesktopScrollDynamics()
        let initial = scroll.move(.init(x: 0, y: 10), now: 0.01)
        XCTAssertEqual(initial.last?.phase, .began)
        _ = scroll.move(.init(x: 0, y: 10), now: 0.03)
        let released = scroll.tick(touching: false, suppressed: false, now: 0.04, tuning: tuning)
        XCTAssertTrue(released.contains { $0.phase == .ended })
        XCTAssertTrue(released.contains { $0.momentumPhase == .begin })
        let motion = scroll.tick(touching: false, suppressed: false, now: 0.05, tuning: tuning)
        XCTAssertTrue(motion.contains { $0.dy > 0 })
        let stopped = scroll.tick(touching: true, suppressed: false, now: 0.06, tuning: tuning)
        XCTAssertTrue(stopped.contains { $0.momentumPhase == .end })
        XCTAssertFalse(stopped.contains { $0.dy != 0 })
        XCTAssertTrue(scroll.tick(touching: true, suppressed: false, now: 0.07, tuning: tuning).isEmpty)
    }

    func testRestBeforeLiftDoesNotStartInertiaAndComparisonKeepsSticks() throws {
        var scroll = DesktopScrollDynamics()
        _ = scroll.move(.init(x: 0, y: 10), now: 0)
        _ = scroll.move(.init(x: 0, y: 10), now: 0.02)
        let end = scroll.tick(touching: false, suppressed: false, now: 0.3, tuning: .default)
        XCTAssertFalse(end.contains { $0.momentumPhase == .begin })
        var settings = JoystickSettings()
        let saved = TouchpadFeelSnapshot(settings)
        settings.rightStick.scrollSensitivity = 0.88
        settings.touchpadTuning.fastGain = 5
        saved.apply(to: &settings)
        XCTAssertEqual(settings.rightStick.scrollSensitivity, 0.88)
        XCTAssertEqual(settings.touchpadTuning.fastGain, 3)
        settings.touchpadComparison = saved
        let copy = try JSONDecoder().decode(JoystickSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(copy.touchpadComparison, saved)
    }
}

/// Real repeat timers, with an isolated profile and mock output only.
@MainActor
final class DesktopRepeatDelayTests: XCTestCase {
    func testQuickTapFiresOnceAndHoldRepeatsOnlyAfterInitialDelay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("repeat-delay-\(UUID().uuidString)")
        let controller = ControllerService(enableHardwareMonitoring: false)
        let profiles = ProfileManager(configDirectoryOverride: directory)
        let simulator = MockInputSimulator()
        let engine = MappingEngine(controllerService: controller, profileManager: profiles,
                                   appMonitor: AppMonitor(), inputSimulator: simulator)
        defer {
            engine.disable()
            controller.onInputEvent = nil
            controller.cleanup()
            try? FileManager.default.removeItem(at: directory)
        }
        var mapping = KeyMapping.key(51)
        mapping.repeatMapping = RepeatMapping(enabled: true, interval: 0.04, initialDelay: 0.3)
        profiles.installTestProfile(Profile(name: "Repeat", buttonMappings: [.y: mapping]))
        engine.enable()
        try await Task.sleep(nanoseconds: 50_000_000)
        func count() -> Int {
            simulator.events.filter { if case .executeMapping = $0 { return true }; return false }.count
        }
        controller.emitInputEvent(.buttonPressed(.y))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(count(), 1)
        controller.emitInputEvent(.buttonReleased(.y, holdDuration: 0.1))
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(count(), 1)
        simulator.clearEvents()
        controller.emitInputEvent(.buttonPressed(.y))
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(count(), 1)
        try await Task.sleep(nanoseconds: 280_000_000)
        XCTAssertGreaterThanOrEqual(count(), 3)
        controller.emitInputEvent(.buttonReleased(.y, holdDuration: 0.43))
        try await Task.sleep(nanoseconds: 60_000_000)
        let stopped = count()
        try await Task.sleep(nanoseconds: 160_000_000)
        XCTAssertEqual(count(), stopped)
    }
}
