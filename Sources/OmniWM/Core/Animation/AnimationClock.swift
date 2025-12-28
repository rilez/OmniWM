import Foundation
import QuartzCore

final class AnimationClock {
    private var currentTime: TimeInterval
    private var lastSeenTime: TimeInterval
    private(set) var rate: Double
    private(set) var shouldCompleteInstantly: Bool

    init(time: TimeInterval = CACurrentMediaTime()) {
        self.currentTime = time
        self.lastSeenTime = time
        self.rate = 1.0
        self.shouldCompleteInstantly = false
    }

    func now() -> TimeInterval {
        let time = CACurrentMediaTime()
        guard lastSeenTime != time else { return currentTime }

        let delta = time - lastSeenTime
        currentTime += delta * rate
        lastSeenTime = time
        return currentTime
    }

    func setRate(_ newRate: Double) {
        _ = now()
        rate = min(max(newRate, 0.0), 1000.0)
    }

    func setCompleteInstantly(_ value: Bool) {
        shouldCompleteInstantly = value
    }
}
