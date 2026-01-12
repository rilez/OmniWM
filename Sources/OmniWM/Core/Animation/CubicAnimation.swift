import Foundation
import QuartzCore

struct CubicConfig {
    let duration: Double

    init(duration: Double = 0.3) {
        self.duration = max(0.01, duration)
    }

    static let `default` = CubicConfig()
}

final class CubicAnimation {
    private(set) var from: Double
    private(set) var target: Double
    private let startTime: TimeInterval
    let config: CubicConfig
    private let clock: AnimationClock?

    init(
        from: Double,
        to: Double,
        startTime: TimeInterval,
        config: CubicConfig = .default,
        clock: AnimationClock? = nil
    ) {
        self.from = from
        target = to
        self.startTime = startTime
        self.config = config
        self.clock = clock
    }

    func value(at time: TimeInterval) -> Double {
        if clock?.shouldCompleteInstantly ?? false {
            return target
        }

        let elapsed = max(0, time - startTime)
        let progress = min(1.0, elapsed / config.duration)
        let easedProgress = 1.0 - pow(1.0 - progress, 3)

        return from + easedProgress * (target - from)
    }

    func isComplete(at time: TimeInterval) -> Bool {
        if clock?.shouldCompleteInstantly ?? false {
            return true
        }

        let elapsed = max(0, time - startTime)
        return elapsed >= config.duration
    }

    func duration() -> TimeInterval {
        config.duration
    }

    func offsetBy(_ delta: Double) {
        from += delta
        target += delta
    }
}
