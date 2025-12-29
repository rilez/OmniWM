import Foundation
import SwiftUI

struct SpringConfig {
    var duration: Double
    var bounce: Double
    var epsilon: Double
    var velocityEpsilon: Double

    init(duration: Double = 0.35, bounce: Double = 0.0, epsilon: Double = 0.5, velocityEpsilon: Double = 50.0) {
        self.duration = max(0.1, duration)
        self.bounce = min(max(bounce, -1.0), 1.0)
        self.epsilon = max(0, epsilon)
        self.velocityEpsilon = max(0, velocityEpsilon)
    }

    static let snappy = SpringConfig(duration: 0.30, bounce: 0.0)
    static let smooth = SpringConfig(duration: 0.50, bounce: 0.0)
    static let bouncy = SpringConfig(duration: 0.45, bounce: 0.25)
    static let responsive = SpringConfig(duration: 0.25, bounce: -0.1)

    var appleSpring: Spring {
        Spring(duration: duration, bounce: bounce)
    }
}

final class SpringAnimation {
    private let from: Double
    let target: Double
    private let initialVelocity: Double
    private let startTime: TimeInterval
    let config: SpringConfig
    private let clock: AnimationClock?

    private let spring: Spring
    private let displacement: Double

    init(
        from: Double,
        to: Double,
        initialVelocity: Double = 0,
        startTime: TimeInterval,
        config: SpringConfig = .snappy,
        clock: AnimationClock? = nil
    ) {
        self.from = from
        self.target = to
        self.startTime = startTime
        self.config = config
        self.clock = clock

        let scaledVelocity = initialVelocity / max(clock?.rate ?? 1.0, 0.001)
        self.initialVelocity = scaledVelocity

        self.spring = config.appleSpring
        self.displacement = to - from
    }

    func value(at time: TimeInterval) -> Double {
        if clock?.shouldCompleteInstantly == true {
            return target
        }

        let currentTime = clock?.now() ?? time
        let elapsed = max(0, currentTime - startTime)

        let springValue = spring.value(
            target: displacement,
            initialVelocity: initialVelocity,
            time: elapsed
        )

        return from + springValue
    }

    func isComplete(at time: TimeInterval) -> Bool {
        if clock?.shouldCompleteInstantly == true {
            return true
        }

        let position = value(at: time)
        let currentVelocity = velocity(at: time)

        let positionSettled = abs(position - target) < config.epsilon
        let velocitySettled = abs(currentVelocity) < config.velocityEpsilon

        return positionSettled && velocitySettled
    }

    func duration() -> TimeInterval {
        return spring.settlingDuration
    }

    func velocity(at time: TimeInterval) -> Double {
        let currentTime = clock?.now() ?? time
        let elapsed = max(0, currentTime - startTime)

        return spring.velocity(
            target: displacement,
            initialVelocity: initialVelocity,
            time: elapsed
        )
    }
}
