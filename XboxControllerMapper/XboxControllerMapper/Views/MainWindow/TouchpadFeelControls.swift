import SwiftUI

/// All tuning edits flow through the existing profile publisher and apply live.
struct TouchpadFeelControls: View {
    @EnvironmentObject var profileManager: ProfileManager
    private var settings: JoystickSettings { profileManager.activeProfile?.joystickSettings ?? .default }

    var body: some View {
        Section("Touchpad Feel") {
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
                SettingInfoTip(title: "Tuning Controls", text: "Changes apply immediately to this profile. Save Comparison stores the current touchpad settings; Swap exchanges them with the saved version. Reset Tuning restores the new tuning controls to their defaults and saves the current settings for comparison. Button mappings and joystick settings are unchanged.")
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
            slider("Low-Speed Gain", \.slowGain, 0.05...1, step: 0.05, unit: "×", help: "Pointer speed during slow swipes. Lower values allow finer adjustments. The Acceleration setting controls how strongly this gain is applied.")
            slider("High-Speed Gain", \.fastGain, 1...6, step: 0.1, unit: "×", help: "Pointer speed during fast swipes. Higher values cover more screen distance. The Acceleration setting controls how strongly this gain is applied.")
            slider("Acceleration Start Speed", \.accelerationStart, 0.05...3, step: 0.05, help: "Hand speed at which the pointer begins accelerating, in pad coordinates per second. Lower values accelerate sooner.")
            slider("Full Acceleration Speed", \.accelerationEnd, 0.2...10, step: 0.1, help: "Hand speed at which the pointer reaches its high-speed gain, in pad coordinates per second. Set this above Acceleration Start Speed.")
        }
    }
    private var noise: some View {
        Section("Motion Filtering") {
            slider("Left Pad Jitter Radius", \.leftJitter, 0...0.06, step: 0.001, scale: 50, unit: "% pad width", help: "Filters small resting-finger movements on the left pad. Larger values reject more jitter but require more travel before fine motion starts.")
            slider("Right Pad Jitter Radius", \.rightJitter, 0...0.06, step: 0.001, scale: 50, unit: "% pad width", help: "Filters small resting-finger movements on the right pad. Larger values reject more jitter but require more travel before fine motion starts.")
            slider("Lift-Off Guard", \.liftGuard, 0...0.06, step: 0.002, scale: 1000, unit: "ms", help: "Buffers the end of each swipe and discards it when you lift your finger. Longer values suppress more lift-off motion but add latency.")
        }
    }
    private var feedback: some View {
        Section("Haptic Feedback") {
            toggle("Press Feedback", \.clickFeedback, help: "Vibrate when the controller reports a physical pad click. This uses the same threshold as the press action; sliding does not vibrate.")
            slider("Left Pad Press Strength", \.leftClickStrength, 0...1, step: 0.05, scale: 100, unit: "%", help: "Left pad feedback strength for a physical press. Set to 0 to disable it.")
            slider("Right Pad Press Strength", \.rightClickStrength, 0...1, step: 0.05, scale: 100, unit: "%", help: "Right pad feedback strength for a physical press. Set to 0 to disable it.")
            toggle("Tap Feedback", \.tapFeedback, help: "Give a short vibration when a light touch and release is recognized as a tap. Sliding cancels tap recognition.")
            slider("Left Pad Tap Strength", \.leftTapStrength, 0...1, step: 0.05, scale: 100, unit: "%", help: "Left pad feedback strength for a light tap. Set to 0 to disable it.")
            slider("Right Pad Tap Strength", \.rightTapStrength, 0...1, step: 0.05, scale: 100, unit: "%", help: "Right pad feedback strength for a light tap. Set to 0 to disable it.")
        }
    }
    private var gestures: some View {
        Section("Tap, Press & Drag") {
            slider("Maximum Tap Duration", \.tapDuration, 0.08...0.6, step: 0.02, scale: 1000, unit: "ms", help: "Maximum contact time for a light tap. Movement is held while the contact can still become a tap, so a longer duration can delay the start of very slow swipes.")
            slider("Tap Travel Limit", \.tapTravel, 0.01...0.25, step: 0.005, scale: 50, unit: "% pad width", help: "Maximum movement allowed for a light tap. Moving beyond this limit starts a slide and cancels the tap, even if you return to the starting point.")
            slider("Press Settle Time", \.clickSettle, 0...0.1, step: 0.005, scale: 1000, unit: "ms", help: "Minimum time after pressing before deliberate movement can start a drag. Filters movement caused by pressing the pad.")
            slider("Drag Start Distance", \.dragTravel, 0.01...0.25, step: 0.005, scale: 50, unit: "% pad width", help: "Distance to move while physically pressed before dragging starts. The suppressed displacement is discarded so the pointer does not jump.")
        }
    }
    private var inertia: some View {
        Section("Left Pad Momentum Scrolling") {
            toggle("Enable Momentum", \.inertiaEnabled, help: "Continue scrolling after a flick. Touch the left pad again to stop. Joystick scrolling is unaffected.")
            slider("Decay Time", \.inertiaDecay, 0.08...1.5, step: 0.02, scale: 1000, unit: "ms", help: "Controls how long momentum lasts. Longer decay means less friction and a longer glide.")
            slider("Minimum Flick Speed", \.inertiaMinSpeed, 20...1000, step: 20, unit: "px/s", help: "Minimum scrolling speed at lift-off needed to start momentum, in pixels per second.")
            slider("Maximum Momentum Speed", \.inertiaMaxSpeed, 200...8000, step: 100, unit: "px/s", help: "Maximum starting speed of momentum scrolling, in pixels per second.")
        }
    }
    private var zoom: some View {
        Section("Two-Pad Zoom") {
            toggle("Enable Zoom", \.zoomEnabled, help: "Use both pads to zoom. Native Zoom uses continuous magnification; when disabled, zoom uses the app's Command-plus and Command-minus shortcuts.")
            slider("Continuous Zoom Gain", \.zoomGain, 0.05...3, step: 0.05, help: "Sensitivity of continuous magnification when Native Zoom is enabled.")
            slider("Maximum Zoom per Update", \.zoomMaxDelta, 0.005...0.2, step: 0.005, scale: 100, unit: "%", help: "Limits magnification in one update to prevent large jumps. Applies only when Native Zoom is enabled.")
            slider("Zoom Start Distance", \.zoomStartTravel, 0.005...0.2, step: 0.005, scale: 50, unit: "% pad width", help: "Minimum pinch movement before zoom begins. Raising this reduces accidental zoom.")
            slider("Travel per Zoom Step", \.zoomStepTravel, 0.02...0.5, step: 0.01, scale: 50, unit: "% pad width", help: "Pinch distance required for each Command-plus or Command-minus step when Native Zoom is disabled.")
            slider("Minimum Step Interval", \.zoomStepInterval, 0.05...1, step: 0.025, scale: 1000, unit: "ms", help: "Minimum time between zoom steps. A longer interval reduces bursts. Lifting clears pending steps.")
            HStack {
                Stepper("Maximum Steps per Update: \(settings.touchpadTuning.zoomSteps)", value: binding(\.zoomSteps), in: 1...3)
                SettingInfoTip(title: "Maximum Steps per Update", text: "Caps the number of zoom shortcut presses sent at once. Use 1 for the finest control. Applies when Native Zoom is disabled.")
            }
        }
    }
    private func binding<T>(_ key: WritableKeyPath<TouchpadTuning, T>) -> Binding<T> {
        Binding(get: { settings.touchpadTuning[keyPath: key] }, set: { newValue in
            var value = settings
            value.touchpadTuning[keyPath: key] = newValue
            profileManager.updateJoystickSettings(value)
        })
    }
    private func toggle(_ label: String, _ key: WritableKeyPath<TouchpadTuning, Bool>, help: String) -> some View {
        HStack {
            Toggle(label, isOn: binding(key))
            SettingInfoTip(title: label, text: help)
        }
    }
    private func slider(_ label: String, _ key: WritableKeyPath<TouchpadTuning, Double>,
                        _ range: ClosedRange<Double>, step: Double, scale: Double = 1, unit: String = "", help: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                SettingInfoTip(title: label, text: help)
                Spacer()
                Text(String(format: "%.2f %@", settings.touchpadTuning[keyPath: key] * scale, unit)).monospacedDigit()
            }
            Slider(value: binding(key), in: range, step: step).accessibilityLabel(label)
        }
    }
}

/// Uses the native hover tooltip without adding another interactive control.
struct SettingInfoTip: View {
    let title: String
    let text: String

    var body: some View {
        Image(systemName: "info.circle")
            .foregroundStyle(.secondary)
            .help(text)
            .accessibilityLabel("About " + title)
            .accessibilityHint(text)
    }
}
