import SwiftUI

/// All tuning edits flow through the existing profile publisher and apply live.
struct TouchpadFeelControls: View {
    @EnvironmentObject var profileManager: ProfileManager
    private var settings: JoystickSettings { profileManager.activeProfile?.joystickSettings ?? .default }

    var body: some View {
        Section("Touchpad Feel · Live Tuning") {
            Text("Adjust touchpad feel without changing button mappings. Save a comparison before trying different settings.")
                .font(.caption).foregroundColor(.secondary)
            HStack {
                Button("Save Comparison") {
                    var value = settings
                    value.touchpadComparison = TouchpadFeelSnapshot(settings)
                    profileManager.updateJoystickSettings(value)
                }
                Button("Swap with Comparison") {
                    guard let saved = settings.touchpadComparison else { return }
                    let current = TouchpadFeelSnapshot(settings)
                    var value = settings
                    saved.apply(to: &value)
                    value.touchpadComparison = current
                    profileManager.updateJoystickSettings(value)
                }.disabled(settings.touchpadComparison == nil)
                Button("Reset Tuning") {
                    var value = settings
                    value.touchpadComparison = TouchpadFeelSnapshot(settings)
                    value.touchpadTuning = .default
                    profileManager.updateJoystickSettings(value)
                }
            }
        }
        speed
        noise
        feedback
        gestures
        inertia
        zoom
    }

    private var speed: some View {
        Section("Pointer Acceleration") {
            slider("Low-Speed Gain", \.slowGain, 0.05...1, step: 0.05, unit: "×")
            slider("High-Speed Gain", \.fastGain, 1...6, step: 0.1, unit: "×")
            slider("Acceleration Start Speed", \.accelerationStart, 0.05...3, step: 0.05)
            slider("Full Acceleration Speed", \.accelerationEnd, 0.2...10, step: 0.1)
            Text("Speed is measured in pad coordinates per second. Lower thresholds accelerate sooner. Acceleration under Advanced Cursor Tuning controls overall strength; 0 disables acceleration.")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var noise: some View {
        Section("Motion Filtering") {
            slider("Left Pad Jitter Radius", \.leftJitter, 0...0.06, step: 0.001, scale: 50, unit: "% pad width")
            slider("Right Pad Jitter Radius", \.rightJitter, 0...0.06, step: 0.001, scale: 50, unit: "% pad width")
            slider("Lift-Off Guard", \.liftGuard, 0...0.06, step: 0.002, scale: 1000, unit: "ms")
            Text("A longer lift-off guard adds latency. A larger jitter radius reduces fine motion.")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var feedback: some View {
        Section("Haptic Feedback") {
            toggle("Press Feedback", \.clickFeedback)
            slider("Left Pad Press Strength", \.leftClickStrength, 0...1, step: 0.05, scale: 100, unit: "%")
            slider("Right Pad Press Strength", \.rightClickStrength, 0...1, step: 0.05, scale: 100, unit: "%")
            toggle("Tap Feedback", \.tapFeedback)
            slider("Left Pad Tap Strength", \.leftTapStrength, 0...1, step: 0.05, scale: 100, unit: "%")
            slider("Right Pad Tap Strength", \.rightTapStrength, 0...1, step: 0.05, scale: 100, unit: "%")
            Text("Press feedback follows the controller's physical click threshold. A strength of 0 disables feedback. Sliding does not vibrate.")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var gestures: some View {
        Section("Tap, Press & Drag") {
            slider("Maximum Tap Duration", \.tapDuration, 0.08...0.6, step: 0.02, scale: 1000, unit: "ms")
            slider("Tap Travel Limit", \.tapTravel, 0.01...0.25, step: 0.005, scale: 50, unit: "% pad width")
            slider("Press Settle Time", \.clickSettle, 0...0.1, step: 0.005, scale: 1000, unit: "ms")
            slider("Drag Start Distance", \.dragTravel, 0.01...0.25, step: 0.005, scale: 50, unit: "% pad width")
            Text("Sliding cancels tap recognition. Press and move deliberately to drag; suppressed motion is never replayed. Assign Tap and Press actions separately under Buttons.")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var inertia: some View {
        Section("Left Pad Momentum Scrolling") {
            toggle("Enable Momentum", \.inertiaEnabled)
            slider("Decay Time", \.inertiaDecay, 0.08...1.5, step: 0.02, scale: 1000, unit: "ms")
            slider("Minimum Flick Speed", \.inertiaMinSpeed, 20...1000, step: 20, unit: "px/s")
            slider("Maximum Momentum Speed", \.inertiaMaxSpeed, 200...8000, step: 100, unit: "px/s")
            Text("Longer decay means less friction. Touch the pad again to stop momentum. Joystick scrolling is unchanged.")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var zoom: some View {
        Section("Two-Pad Zoom") {
            toggle("Enable Zoom", \.zoomEnabled)
            slider("Continuous Zoom Gain", \.zoomGain, 0.05...3, step: 0.05)
            slider("Maximum Zoom per Update", \.zoomMaxDelta, 0.005...0.2, step: 0.005, scale: 100, unit: "%")
            slider("Zoom Start Distance", \.zoomStartTravel, 0.005...0.2, step: 0.005, scale: 50, unit: "% pad width")
            slider("Travel per Zoom Step", \.zoomStepTravel, 0.02...0.5, step: 0.01, scale: 50, unit: "% pad width")
            slider("Minimum Step Interval", \.zoomStepInterval, 0.05...1, step: 0.025, scale: 1000, unit: "ms")
            Stepper("Maximum Steps per Update: \(settings.touchpadTuning.zoomSteps)", value: binding(\.zoomSteps), in: 1...3)
            Text("Native Zoom uses continuous magnification. When disabled, zoom uses the app's ⌘+/⌘− shortcuts. Lifting clears any pending steps.")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private func binding<T>(_ key: WritableKeyPath<TouchpadTuning, T>) -> Binding<T> {
        Binding(get: { settings.touchpadTuning[keyPath: key] }, set: { newValue in
            var value = settings
            value.touchpadTuning[keyPath: key] = newValue
            profileManager.updateJoystickSettings(value)
        })
    }
    private func toggle(_ label: String, _ key: WritableKeyPath<TouchpadTuning, Bool>) -> some View {
        Toggle(label, isOn: binding(key))
    }
    private func slider(_ label: String, _ key: WritableKeyPath<TouchpadTuning, Double>,
                        _ range: ClosedRange<Double>, step: Double, scale: Double = 1, unit: String = "") -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.2f %@", settings.touchpadTuning[keyPath: key] * scale, unit)).monospacedDigit()
            }
            Slider(value: binding(key), in: range, step: step).accessibilityLabel(label)
        }
    }
}
