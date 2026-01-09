import Foundation

struct AlphaAnimation {
    let animation: SpringAnimation
    let fromAlpha: CGFloat
    let toAlpha: CGFloat

    func currentAlpha(at time: TimeInterval) -> CGFloat {
        let progress = CGFloat(animation.value(at: time))
        return fromAlpha + (toAlpha - fromAlpha) * progress
    }

    func isComplete(at time: TimeInterval) -> Bool {
        animation.isComplete(at: time)
    }
}
