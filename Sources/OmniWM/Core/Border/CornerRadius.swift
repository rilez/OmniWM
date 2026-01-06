import Foundation

struct CornerRadius: Equatable {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat

    static let zero = CornerRadius(topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0)

    init(uniform: CGFloat) {
        topLeft = uniform
        topRight = uniform
        bottomLeft = uniform
        bottomRight = uniform
    }

    init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    func fitTo(width: CGFloat, height: CGFloat) -> CornerRadius {
        let maxRadius = min(width, height) / 2
        return CornerRadius(
            topLeft: min(topLeft, maxRadius),
            topRight: min(topRight, maxRadius),
            bottomLeft: min(bottomLeft, maxRadius),
            bottomRight: min(bottomRight, maxRadius)
        )
    }

    func expanded(by amount: CGFloat) -> CornerRadius {
        CornerRadius(
            topLeft: topLeft + amount,
            topRight: topRight + amount,
            bottomLeft: bottomLeft + amount,
            bottomRight: bottomRight + amount
        )
    }

    func normalized() -> CornerRadius {
        let values = [topLeft, topRight, bottomLeft, bottomRight].sorted()
        let median = (values[1] + values[2]) / 2
        func clamp(_ v: CGFloat) -> CGFloat {
            abs(v - median) > 1 ? median : v
        }
        return CornerRadius(
            topLeft: clamp(topLeft),
            topRight: clamp(topRight),
            bottomLeft: clamp(bottomLeft),
            bottomRight: clamp(bottomRight)
        )
    }
}
