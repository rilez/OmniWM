import Foundation
import QuartzCore

enum WorkspaceSwitch {
    case animation(SpringAnimation)

    func currentIndex() -> Double {
        switch self {
        case let .animation(anim):
            anim.value(at: CACurrentMediaTime())
        }
    }

    func isAnimating() -> Bool {
        switch self {
        case let .animation(anim):
            !anim.isComplete(at: CACurrentMediaTime())
        }
    }

    mutating func tick(at time: TimeInterval) -> Bool {
        switch self {
        case let .animation(anim):
            !anim.isComplete(at: time)
        }
    }
}
