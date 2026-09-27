import XCTest
import CoreGraphics
@testable import ControllerKeys

/// Exercise the actual event pipeline with a mock output sink, never global
/// keyboard/mouse events. Contact loss must cancel queued cursor and scroll work.
@MainActor
final class SteamTouchpadContactTests: XCTestCase {
    func testAlreadyFilteredSteamMotionHasNoSecondThresholdOrPendingFrame() {
        let controller = ControllerService(enableHardwareMonitoring: false)
        let simulator = MockInputSimulator()
        controller.storage.isSteamController = true
        controller.onInputEvent = { event in
            if case .touchpadMoved(let delta) = event {
                simulator.moveMouse(dx: delta.x, dy: delta.y)
            }
        }
        defer {
            controller.onInputEvent = nil
            controller.cleanup()
        }
        controller.updateSteamTouchpad(side: .right, x: 0.2, y: 0, isTouching: true)
        for frame in 1...100 {
            controller.updateSteamTouchpad(side: .right, x: 0.2 + Float(frame) * 0.00025, y: 0, isTouching: true)
        }
        let moves = simulator.events.compactMap { event -> CGFloat? in
            if case .moveMouse(let x, _) = event { return x }
            return nil
        }
        XCTAssertEqual(moves.count, 100)
        XCTAssertEqual(moves.reduce(0, +), 0.025, accuracy: 0.000001)
        controller.updateSteamTouchpad(side: .right, x: 0, y: 0, isTouching: false)
        XCTAssertEqual(simulator.events.count, 100, "Lifting must not replay motion")
    }

    func testPointerAndScrollStopWhenContactEnds() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("steam-contact-test-\(UUID().uuidString)", isDirectory: true)
        let controller = ControllerService(enableHardwareMonitoring: false)
        let profiles = ProfileManager(configDirectoryOverride: directory)
        let simulator = MockInputSimulator()
        let engine = MappingEngine(
            controllerService: controller,
            profileManager: profiles,
            appMonitor: AppMonitor(),
            inputSimulator: simulator
        )
        defer {
            engine.disable()
            controller.onInputEvent = nil
            controller.cleanup()
            try? FileManager.default.removeItem(at: directory)
        }

        var profile = Profile(name: "Contact guard", buttonMappings: [:])
        profile.joystickSettings.touchpadSmoothing = 0
        profile.joystickSettings.touchpadAcceleration = 0
        profile.joystickSettings.touchpadPanSensitivity = 0.25
        profiles.setActiveProfile(profile)
        controller.storage.isSteamController = true
        controller.storage.isTouchpadTouching = true
        controller.storage.isSteamLeftTouchpadTouching = true
        controller.isConnected = true
        engine.enable()
        try await Task.sleep(nanoseconds: 100_000_000)

        controller.emitInputEvent(.touchpadMoved(CGPoint(x: 0.1, y: 0.1)))
        controller.emitInputEvent(.steamLeftTouchpadMoved(CGPoint(x: 0.1, y: 0.1)))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(simulator.events.contains { if case .moveMouse = $0 { return true }; return false })
        XCTAssertTrue(simulator.events.contains { if case .scroll = $0 { return true }; return false })

        simulator.clearEvents()
        controller.storage.isTouchpadTouching = false
        controller.storage.isSteamLeftTouchpadTouching = false
        controller.emitInputEvent(.touchpadMoved(CGPoint(x: 0.1, y: 0.1)))
        controller.emitInputEvent(.steamLeftTouchpadMoved(CGPoint(x: 0.1, y: 0.1)))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(simulator.events.contains { if case .moveMouse = $0 { return true }; return false })
        XCTAssertFalse(simulator.events.contains { if case .scroll(let x, let y) = $0 { return x != 0 || y != 0 }; return false })
    }
}
