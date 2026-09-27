import Foundation
import CoreGraphics

/// Pure, clock-injected gesture state. No timers or native event posting here.
struct DesktopZoomDynamics {
    struct Output {
        var begin = false
        var end = false
        var magnification = 0.0
        var steps = 0
        var active = false
    }
    private(set) var active = false
    var nativeActive: Bool { active && nativeMode == true }
    private var nativeMode: Bool?
    private var candidate = 0.0
    private var stepDistance = 0.0
    private var lastStep: TimeInterval?

    mutating func update(distance: Double, pan: Double, touching: Bool, native: Bool,
                         ratio: Double, now: TimeInterval, tuning: TouchpadTuning) -> Output {
        guard touching, tuning.zoomEnabled else {
            let ended = active && nativeMode == true
            self = Self()
            return Output(end: ended)
        }
        if let previous = nativeMode, previous != native {
            let ended = active && previous
            self = Self()
            nativeMode = native
            return Output(end: ended)
        }
        nativeMode = native
        guard distance.isFinite, pan.isFinite else { return Output(active: active) }
        let dominant = abs(distance) > 0.00001 && (pan < 0.002 || abs(distance) > pan * ratio)
        guard dominant else { return Output(active: active) }
        var delta = distance
        var begin = false
        if !active {
            candidate += distance
            guard abs(candidate) >= tuning.zoomStartTravel else { return Output() }
            delta = (candidate > 0 ? 1 : -1) * (abs(candidate) - tuning.zoomStartTravel)
            candidate = 0
            active = true
            begin = native
        }
        if native {
            let amount = min(tuning.zoomMaxDelta, max(-tuning.zoomMaxDelta, delta * tuning.zoomGain))
            return Output(begin: begin, magnification: amount, active: true)
        }
        let threshold = max(0.001, tuning.zoomStepTravel)
        // Never accumulate an unbounded backlog while rate-limited.
        let limit = threshold * Double(tuning.zoomSteps)
        stepDistance = min(limit, max(-limit, stepDistance + delta))
        guard abs(stepDistance) >= threshold,
              lastStep.map({ now - $0 >= tuning.zoomStepInterval }) ?? true else {
            return Output(active: true)
        }
        let count = min(tuning.zoomSteps, max(1, Int(abs(stepDistance) / threshold)))
        let steps = stepDistance > 0 ? count : -count
        stepDistance -= Double(steps) * threshold
        lastStep = now
        return Output(steps: steps, active: true)
    }
}

/// Continuous pixel scrolling plus exponential momentum. Only filtered motion
/// while touching contributes velocity; a new contact or zoom cancels momentum.
struct DesktopScrollDynamics {
    private struct Sample { let delta: CGPoint; let time: TimeInterval }
    private var samples: [Sample] = []
    private var lastMotion: TimeInterval?
    private var lastTick: TimeInterval?
    private var touching = false
    private var scrolling = false
    private var momentum = false
    private var velocity = CGPoint.zero

    var endEvents: [ScrollEvent] {
        var events: [ScrollEvent] = []
        if scrolling { events.append(.init(dx: 0, dy: 0, phase: .ended, isContinuous: true)) }
        if momentum { events.append(.init(dx: 0, dy: 0, momentumPhase: .end, isContinuous: true)) }
        return events
    }

    mutating func move(_ delta: CGPoint, now: TimeInterval) -> [ScrollEvent] {
        guard delta.x.isFinite, delta.y.isFinite else { return [] }
        var events: [ScrollEvent] = []
        if momentum {
            events.append(.init(dx: 0, dy: 0, momentumPhase: .end, isContinuous: true))
            momentum = false
            velocity = .zero
        }
        touching = true
        samples.append(.init(delta: delta, time: now))
        samples.removeAll { now - $0.time > 0.08 }
        if samples.count > 64 { samples.removeFirst(samples.count - 64) }
        lastMotion = now
        lastTick = now
        events.append(.init(dx: delta.x, dy: delta.y, phase: scrolling ? .changed : .began, isContinuous: true))
        scrolling = true
        return events
    }

    mutating func tick(touching contact: Bool, suppressed: Bool, now: TimeInterval,
                       tuning: TouchpadTuning) -> [ScrollEvent] {
        var events: [ScrollEvent] = []
        let dt = min(0.05, max(0, lastTick.map { now - $0 } ?? 0))
        lastTick = now
        if suppressed || (contact && !touching) || (!tuning.inertiaEnabled && momentum) {
            if momentum { events.append(.init(dx: 0, dy: 0, momentumPhase: .end, isContinuous: true)) }
            if scrolling { events.append(.init(dx: 0, dy: 0, phase: .ended, isContinuous: true)) }
            samples.removeAll(keepingCapacity: true)
            scrolling = false
            momentum = false
            velocity = .zero
        }
        if !contact && touching && scrolling {
            events.append(.init(dx: 0, dy: 0, phase: .ended, isContinuous: true))
            scrolling = false
            if !suppressed, tuning.inertiaEnabled, samples.count >= 2,
               let first = samples.first, let lastMotion, now - lastMotion < 0.08 {
                let span = max(0.016, lastMotion - first.time + 1.0 / 120)
                let total = samples.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.delta.x, y: $0.y + $1.delta.y) }
                let speed = hypot(total.x, total.y) / span
                if speed >= tuning.inertiaMinSpeed {
                    let scale = min(speed, tuning.inertiaMaxSpeed) / max(0.001, hypot(total.x, total.y))
                    velocity = CGPoint(x: total.x * scale, y: total.y * scale)
                    momentum = true
                    events.append(.init(dx: 0, dy: 0, momentumPhase: .begin, isContinuous: true))
                }
            }
            samples.removeAll(keepingCapacity: true)
        }
        touching = contact
        guard !contact, !suppressed, momentum else { return events }
        let decay = exp(-dt / max(0.01, tuning.inertiaDecay))
        let next = CGPoint(x: velocity.x * decay, y: velocity.y * decay)
        // Exact integral of exponential decay keeps distance independent of tick rate.
        let delta = CGPoint(x: (velocity.x - next.x) * tuning.inertiaDecay,
                            y: (velocity.y - next.y) * tuning.inertiaDecay)
        velocity = next
        if hypot(next.x, next.y) < 8 {
            momentum = false
            events.append(.init(dx: 0, dy: 0, momentumPhase: .end, isContinuous: true))
        } else {
            events.append(.init(dx: delta.x, dy: delta.y, momentumPhase: .continuous, isContinuous: true))
        }
        return events
    }
}
