import Foundation

/// Live, per-profile desktop touchpad parameters. Missing keys migrate safely.
struct TouchpadTuning: Codable, Equatable, Sendable {
    var slowGain: Double = 0.15
    var fastGain: Double = 3
    var accelerationStart: Double = 0.25
    var accelerationEnd: Double = 3
    var leftJitter: Double = 0.012
    var rightJitter: Double = 0.012
    var liftGuard: Double = 0.016
    var tapDuration: Double = 0.25
    var tapTravel: Double = 0.05
    var clickSettle: Double = 0.035
    var dragTravel: Double = 0.06
    var leftClickStrength: Double = 0.6
    var rightClickStrength: Double = 0.6
    var leftTapStrength: Double = 0.25
    var rightTapStrength: Double = 0.25
    var clickFeedback: Bool = true
    var tapFeedback: Bool = true
    var zoomEnabled: Bool = true
    var zoomGain: Double = 0.6
    var zoomMaxDelta: Double = 0.06
    var zoomStartTravel: Double = 0.03
    var zoomStepTravel: Double = 0.12
    var zoomStepInterval: Double = 0.2
    var zoomSteps: Int = 1
    var inertiaEnabled: Bool = true
    var inertiaDecay: Double = 0.3
    var inertiaMinSpeed: Double = 120
    var inertiaMaxSpeed: Double = 3000
    static let `default` = TouchpadTuning()
    init() {}

    enum CodingKeys: String, CodingKey {
        case slowGain
        case fastGain
        case accelerationStart
        case accelerationEnd
        case leftJitter
        case rightJitter
        case liftGuard
        case tapDuration
        case tapTravel
        case clickSettle
        case dragTravel
        case leftClickStrength
        case rightClickStrength
        case leftTapStrength
        case rightTapStrength
        case clickFeedback
        case tapFeedback
        case zoomEnabled
        case zoomGain
        case zoomMaxDelta
        case zoomStartTravel
        case zoomStepTravel
        case zoomStepInterval
        case zoomSteps
        case inertiaEnabled
        case inertiaDecay
        case inertiaMinSpeed
        case inertiaMaxSpeed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slowGain = try c.decode(.slowGain, default: 0.15, clampedTo: 0.05...1)
        fastGain = try c.decode(.fastGain, default: 3, clampedTo: 1...6)
        accelerationStart = try c.decode(.accelerationStart, default: 0.25, clampedTo: 0.05...3)
        accelerationEnd = try c.decode(.accelerationEnd, default: 3, clampedTo: 0.2...10)
        leftJitter = try c.decode(.leftJitter, default: 0.012, clampedTo: 0...0.06)
        rightJitter = try c.decode(.rightJitter, default: 0.012, clampedTo: 0...0.06)
        liftGuard = try c.decode(.liftGuard, default: 0.016, clampedTo: 0...0.06)
        tapDuration = try c.decode(.tapDuration, default: 0.25, clampedTo: 0.08...0.6)
        tapTravel = try c.decode(.tapTravel, default: 0.05, clampedTo: 0.01...0.25)
        clickSettle = try c.decode(.clickSettle, default: 0.035, clampedTo: 0...0.1)
        dragTravel = try c.decode(.dragTravel, default: 0.06, clampedTo: 0.01...0.25)
        leftClickStrength = try c.decode(.leftClickStrength, default: 0.6, clampedTo: 0...1)
        rightClickStrength = try c.decode(.rightClickStrength, default: 0.6, clampedTo: 0...1)
        leftTapStrength = try c.decode(.leftTapStrength, default: 0.25, clampedTo: 0...1)
        rightTapStrength = try c.decode(.rightTapStrength, default: 0.25, clampedTo: 0...1)
        clickFeedback = try c.decode(.clickFeedback, default: true)
        tapFeedback = try c.decode(.tapFeedback, default: true)
        zoomEnabled = try c.decode(.zoomEnabled, default: true)
        zoomGain = try c.decode(.zoomGain, default: 0.6, clampedTo: 0.05...3)
        zoomMaxDelta = try c.decode(.zoomMaxDelta, default: 0.06, clampedTo: 0.005...0.2)
        zoomStartTravel = try c.decode(.zoomStartTravel, default: 0.03, clampedTo: 0.005...0.2)
        zoomStepTravel = try c.decode(.zoomStepTravel, default: 0.12, clampedTo: 0.02...0.5)
        zoomStepInterval = try c.decode(.zoomStepInterval, default: 0.2, clampedTo: 0.05...1)
        zoomSteps = min(3, max(1, try c.decodeIfPresent(Int.self, forKey: .zoomSteps) ?? 1))
        inertiaEnabled = try c.decode(.inertiaEnabled, default: true)
        inertiaDecay = try c.decode(.inertiaDecay, default: 0.3, clampedTo: 0.08...1.5)
        inertiaMinSpeed = try c.decode(.inertiaMinSpeed, default: 120, clampedTo: 20...1000)
        inertiaMaxSpeed = try c.decode(.inertiaMaxSpeed, default: 3000, clampedTo: 200...8000)
    }
}

/// Comparison slots contain touchpad settings only, never buttons or profiles.
struct TouchpadFeelSnapshot: Codable, Equatable {
    var tuning: TouchpadTuning
    var sensitivity: Double
    var acceleration: Double
    var panSensitivity: Double
    var smoothing: Double
    var deadzone: Double
    var nativeZoom: Bool
    var zoomRatio: Double

    init(_ settings: JoystickSettings) {
        tuning = settings.touchpadTuning
        sensitivity = settings.touchpadSensitivity
        acceleration = settings.touchpadAcceleration
        panSensitivity = settings.touchpadPanSensitivity
        smoothing = settings.touchpadSmoothing
        deadzone = settings.touchpadDeadzone
        nativeZoom = settings.touchpadUseNativeZoom
        zoomRatio = settings.touchpadZoomToPanRatio
    }

    func apply(to settings: inout JoystickSettings) {
        settings.touchpadTuning = tuning
        settings.touchpadSensitivity = sensitivity
        settings.touchpadAcceleration = acceleration
        settings.touchpadPanSensitivity = panSensitivity
        settings.touchpadSmoothing = smoothing
        settings.touchpadDeadzone = deadzone
        settings.touchpadUseNativeZoom = nativeZoom
        settings.touchpadZoomToPanRatio = zoomRatio
    }
}
