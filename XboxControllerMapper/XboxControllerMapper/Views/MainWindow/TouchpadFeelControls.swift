import SwiftUI

/// All tuning edits flow through the existing profile publisher and apply live.
struct TouchpadFeelControls: View {
    @EnvironmentObject var profileManager: ProfileManager
    private var settings: JoystickSettings { profileManager.activeProfile?.joystickSettings ?? .default }

    var body: some View {
        Section("触控板手感 · 即时生效") {
            Text("只调整触控板，不更改你的键位。先保存一份对照，再边操作边调。")
                .font(.caption).foregroundColor(.secondary)
            HStack {
                Button("保存当前作对照") {
                    var value = settings
                    value.touchpadComparison = TouchpadFeelSnapshot(settings)
                    profileManager.updateJoystickSettings(value)
                }
                Button("切换当前 / 对照") {
                    guard let saved = settings.touchpadComparison else { return }
                    let current = TouchpadFeelSnapshot(settings)
                    var value = settings
                    saved.apply(to: &value)
                    value.touchpadComparison = current
                    profileManager.updateJoystickSettings(value)
                }.disabled(settings.touchpadComparison == nil)
                Button("恢复建议参数") {
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
        Section("指针 · 慢划精细 / 快划跨屏") {
            slider("低速增益", \.slowGain, 0.05...1, step: 0.05, unit: "×")
            slider("高速增益", \.fastGain, 1...6, step: 0.1, unit: "×")
            slider("开始加速的手速", \.accelerationStart, 0.05...3, step: 0.05)
            slider("达到高速的手速", \.accelerationEnd, 0.2...10, step: 0.1)
            Text("手速以触板坐标变化/秒计算，数值越小越早提速。原有 Acceleration 控制曲线整体强度；0 为线性。")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var noise: some View {
        Section("滤抖 · 左右独立") {
            slider("左触板静止滤抖", \.leftJitter, 0...0.06, step: 0.001, scale: 50, unit: "% 板宽")
            slider("右触板静止滤抖", \.rightJitter, 0...0.06, step: 0.001, scale: 50, unit: "% 板宽")
            slider("抬手保护", \.liftGuard, 0...0.06, step: 0.002, scale: 1000, unit: "ms")
            Text("保护时间更长会增加移动延迟；滤抖过强会影响微调。")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var feedback: some View {
        Section("触觉 · 滑动不震") {
            toggle("按下反馈", \.clickFeedback)
            slider("左触板按下强度", \.leftClickStrength, 0...1, step: 0.05, scale: 100, unit: "%")
            slider("右触板按下强度", \.rightClickStrength, 0...1, step: 0.05, scale: 100, unit: "%")
            toggle("轻点反馈", \.tapFeedback)
            slider("左触板轻点强度", \.leftTapStrength, 0...1, step: 0.05, scale: 100, unit: "%")
            slider("右触板轻点强度", \.rightTapStrength, 0...1, step: 0.05, scale: 100, unit: "%")
            Text("按下沿用手柄的点击阈值；没有第二档压力或长按动作。强度为 0 时不震。")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var gestures: some View {
        Section("轻点 / 按下 / 拖拽") {
            slider("轻点最长时间", \.tapDuration, 0.08...0.6, step: 0.02, scale: 1000, unit: "ms")
            slider("轻点允许位移", \.tapTravel, 0.01...0.25, step: 0.005, scale: 50, unit: "% 板宽")
            slider("按下稳定时间", \.clickSettle, 0...0.1, step: 0.005, scale: 1000, unit: "ms")
            slider("拖拽启动距离", \.dragTravel, 0.01...0.25, step: 0.005, scale: 50, unit: "% 板宽")
            Text("滑动过的这次接触不再补发轻点。按下后明确移动才进入拖拽，不把按压抖动补成跳动。Tap / Press 的动作仍在 Buttons 中分别绑定。")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var inertia: some View {
        Section("左触板 · 惯性滚动") {
            toggle("启用惯性", \.inertiaEnabled)
            slider("衰减时间", \.inertiaDecay, 0.08...1.5, step: 0.02, scale: 1000, unit: "ms")
            slider("惯性启动速度", \.inertiaMinSpeed, 20...1000, step: 20, unit: "px/s")
            slider("最大惯性速度", \.inertiaMaxSpeed, 200...8000, step: 100, unit: "px/s")
            Text("衰减时间越长，摩擦越小。重新触摸立即停止惯性；摇杆滚动不受影响。")
                .font(.caption).foregroundColor(.secondary)
        }
    }
    private var zoom: some View {
        Section("双触板 · 缩放") {
            toggle("启用缩放", \.zoomEnabled)
            slider("连续缩放增益", \.zoomGain, 0.05...3, step: 0.05)
            slider("单次连续缩放上限", \.zoomMaxDelta, 0.005...0.2, step: 0.005, scale: 100, unit: "%")
            slider("开始缩放的距离", \.zoomStartTravel, 0.005...0.2, step: 0.005, scale: 50, unit: "% 板宽")
            slider("每档需要的距离", \.zoomStepTravel, 0.02...0.5, step: 0.01, scale: 50, unit: "% 板宽")
            slider("步进最短间隔", \.zoomStepInterval, 0.05...1, step: 0.025, scale: 1000, unit: "ms")
            Stepper("每次最多 \(settings.touchpadTuning.zoomSteps) 档", value: binding(\.zoomSteps), in: 1...3)
            Text("Native Zoom 开启时使用连续缩放；关闭时按应用的 ⌘+/⌘− 档位缩放。松手清空累计，不继续补发。")
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
