import Foundation
import CoreGraphics

/// Pure math functions for analog input processing, extracted for testability.
/// The live pipeline (JoystickHandler, TouchpadInputHandler) calls these same functions.
enum JoystickMath {

    /// Circular deadzone check. Returns the stick magnitude if outside the deadzone, nil if inside.
    /// Uses `>` (not `>=`), so exactly-at-boundary is filtered.
    static func circularDeadzone(x: Double, y: Double, deadzone: Double) -> Double? {
        let magnitudeSquared = x * x + y * y
        let deadzoneSquared = deadzone * deadzone
        guard magnitudeSquared > deadzoneSquared else { return nil }
        return sqrt(magnitudeSquared)
    }

    /// Normalizes magnitude from [deadzone, 1.0] to [0.0, 1.0].
    static func normalizedMagnitude(_ magnitude: Double, deadzone: Double) -> Double {
        (magnitude - deadzone) / (1.0 - deadzone)
    }

    /// Smooth deadzone ramp: returns 0 below deadzone, quadratic ease-in through
    /// a transition zone of width `deadzone`, then linear above `2 * deadzone`.
    /// Eliminates the hard cutoff discontinuity that causes stutter at the boundary.
    static func smoothDeadzone(_ value: Double, deadzone: Double) -> Double {
        if value <= deadzone { return 0 }
        let excess = value - deadzone
        if excess < deadzone {
            let t = excess / deadzone
            return t * t * deadzone
        }
        return excess
    }

    /// 1-Euro inspired low-pass filter for stick smoothing.
    /// `minCutoff`/`maxCutoff` control the frequency range (Hz).
    static func smoothStick(_ raw: CGPoint, previous: CGPoint, dt: TimeInterval,
                            minCutoff: Double, maxCutoff: Double) -> CGPoint {
        let magnitude = sqrt(Double(raw.x * raw.x + raw.y * raw.y))
        let t = min(1.0, magnitude * 1.2)
        let cutoff = minCutoff + (maxCutoff - minCutoff) * t
        let alpha = 1.0 - exp(-2.0 * Double.pi * cutoff * max(0.0, dt))
        let newX = Double(previous.x) + alpha * (Double(raw.x) - Double(previous.x))
        let newY = Double(previous.y) + alpha * (Double(raw.y) - Double(previous.y))
        return CGPoint(x: newX, y: newY)
    }

    /// Computes EMA alpha from touchpad smoothing slider value (0-1).
    /// Higher smoothing → lower alpha → heavier filtering.
    static func touchpadSmoothingAlpha(smoothing: Double, minAlpha: Double) -> Double {
        max(minAlpha, 1.0 - smoothing)
    }

    /// Velocity-dependent pointer gain. Slow motion gets precision while fast
    /// swipes retain the existing sensitivity as their ceiling. Using distance
    /// per second keeps the curve independent of HID report rate.
    static func touchpadAccelerationGain(
        distance: Double,
        elapsed: TimeInterval,
        amount: Double
    ) -> Double {
        guard distance.isFinite, elapsed.isFinite, amount.isFinite else { return 1 }
        let strength = min(1, max(0, amount))
        guard strength > 0 else { return 1 }
        let minimumGain = 1 - 0.8 * strength
        // A fresh touch has no velocity history. Start conservatively instead
        // of interpreting its first position delta as a high-speed flick.
        guard elapsed > 0 else { return minimumGain }
        let speed = max(0, distance) / max(elapsed, 0.001)
        let t = min(1, max(0, (speed - 0.25) / (4.0 - 0.25)))
        let eased = t * t * (3 - 2 * t)
        return minimumGain + (1 - minimumGain) * eased
    }

    /// Horizontal scroll suppression: zeroes X component when Y is dominant.
    static func scrollEffectiveX(stickX: Double, stickY: Double, thresholdRatio: Double) -> Double {
        let absX = abs(stickX)
        let absY = abs(stickY)
        if absY > absX && absX < absY * thresholdRatio {
            return 0
        }
        return stickX
    }

    /// Converts stick axes into scroll-event deltas, preserving the historical
    /// defaults while allowing each axis to be reversed independently.
    static func scrollDelta(
		effectiveX: Double,
		stickY: Double,
		scale: Double,
		invertX: Bool,
		invertY: Bool
    ) -> CGPoint {
		let dx = (invertX ? effectiveX : -effectiveX) * scale
		let dy = (invertY ? -stickY : stickY) * scale
		return CGPoint(x: CGFloat(dx), y: CGFloat(dy))
    }
}
