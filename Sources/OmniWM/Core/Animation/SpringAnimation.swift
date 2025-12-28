import Foundation
import SwiftUI

struct SpringConfig {
    var stiffness: Double
    var dampingRatio: Double
    var epsilon: Double

    init(stiffness: Double = 800, dampingRatio: Double = 1.0, epsilon: Double = 0.0001) {
        self.stiffness = max(0, stiffness)
        self.dampingRatio = max(0, dampingRatio)
        self.epsilon = max(0, epsilon)
    }

    static let snappy = SpringConfig(stiffness: 800, dampingRatio: 1.0)
    static let smooth = SpringConfig(stiffness: 400, dampingRatio: 1.0)
    static let bouncy = SpringConfig(stiffness: 600, dampingRatio: 0.7)

    var appleSpring: Spring {
        let mass = 1.0
        let absoluteDamping = 2.0 * dampingRatio * sqrt(stiffness * mass)
        return Spring(mass: mass, stiffness: stiffness, damping: absoluteDamping)
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
        return abs(position - target) < config.epsilon
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
