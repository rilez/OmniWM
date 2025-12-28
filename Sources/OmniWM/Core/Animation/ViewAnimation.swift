import Foundation

enum EasingCurve: Equatable, Hashable {
    case linear
    case easeOutQuad
    case easeOutCubic
    case easeOutExpo
    case cubicBezier(x1: Double, y1: Double, x2: Double, y2: Double)

    static let allSimpleCases: [EasingCurve] = [.linear, .easeOutQuad, .easeOutCubic, .easeOutExpo]

    var displayName: String {
        switch self {
        case .linear: "Linear"
        case .easeOutQuad: "Ease Out (Quad)"
        case .easeOutCubic: "Ease Out (Cubic)"
        case .easeOutExpo: "Ease Out (Expo)"
        case .cubicBezier: "Cubic Bezier"
        }
    }

    var isSimpleCase: Bool {
        switch self {
        case .cubicBezier: false
        default: true
        }
    }

    func apply(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        switch self {
        case .linear:
            return clamped
        case .easeOutQuad:
            let inv = 1 - clamped
            return 1 - inv * inv
        case .easeOutCubic:
            let inv = 1 - clamped
            return 1 - inv * inv * inv
        case .easeOutExpo:
            return clamped >= 1 ? 1 : 1 - pow(2, -10 * clamped)
        case .cubicBezier(let x1, let y1, let x2, let y2):
            return Self.evaluateCubicBezier(t: clamped, x1: x1, y1: y1, x2: x2, y2: y2)
        }
    }

    private static func evaluateCubicBezier(t: Double, x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        let bezierT = solveBezierX(x: t, x1: x1, x2: x2)
        return bezierY(t: bezierT, y1: y1, y2: y2)
    }

    private static func solveBezierX(x: Double, x1: Double, x2: Double, epsilon: Double = 0.0001) -> Double {
        var low = 0.0
        var high = 1.0
        var mid = x

        for _ in 0..<31 {
            let xAtMid = bezierX(t: mid, x1: x1, x2: x2)
            if abs(xAtMid - x) < epsilon {
                return mid
            }
            if xAtMid < x {
                low = mid
            } else {
                high = mid
            }
            mid = (low + high) / 2
        }
        return mid
    }

    private static func bezierX(t: Double, x1: Double, x2: Double) -> Double {
        let t2 = t * t
        let t3 = t2 * t
        let mt = 1 - t
        let mt2 = mt * mt
        return 3 * mt2 * t * x1 + 3 * mt * t2 * x2 + t3
    }

    private static func bezierY(t: Double, y1: Double, y2: Double) -> Double {
        let t2 = t * t
        let t3 = t2 * t
        let mt = 1 - t
        let mt2 = mt * mt
        return 3 * mt2 * t * y1 + 3 * mt * t2 * y2 + t3
    }
}

extension EasingCurve: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case x1, y1, x2, y2
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "linear":
            self = .linear
        case "easeOutQuad":
            self = .easeOutQuad
        case "easeOutCubic":
            self = .easeOutCubic
        case "easeOutExpo":
            self = .easeOutExpo
        case "cubicBezier":
            let x1 = try container.decode(Double.self, forKey: .x1)
            let y1 = try container.decode(Double.self, forKey: .y1)
            let x2 = try container.decode(Double.self, forKey: .x2)
            let y2 = try container.decode(Double.self, forKey: .y2)
            self = .cubicBezier(x1: x1, y1: y1, x2: x2, y2: y2)
        case "easeInCubic", "easeInOutCubic", "easeInExpo", "easeInOutExpo":
            self = .easeOutCubic
        default:
            self = .easeOutCubic
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .linear:
            try container.encode("linear", forKey: .type)
        case .easeOutQuad:
            try container.encode("easeOutQuad", forKey: .type)
        case .easeOutCubic:
            try container.encode("easeOutCubic", forKey: .type)
        case .easeOutExpo:
            try container.encode("easeOutExpo", forKey: .type)
        case .cubicBezier(let x1, let y1, let x2, let y2):
            try container.encode("cubicBezier", forKey: .type)
            try container.encode(x1, forKey: .x1)
            try container.encode(y1, forKey: .y1)
            try container.encode(x2, forKey: .x2)
            try container.encode(y2, forKey: .y2)
        }
    }
}

final class ViewAnimation {
    let from: Double
    let to: Double
    let duration: TimeInterval
    let curve: EasingCurve
    let startTime: TimeInterval
    private let clock: AnimationClock?

    init(
        from: Double,
        to: Double,
        duration: TimeInterval = 0.3,
        curve: EasingCurve = .easeOutCubic,
        startTime: TimeInterval,
        clock: AnimationClock? = nil
    ) {
        self.from = from
        self.to = to
        self.duration = duration
        self.curve = curve
        self.startTime = startTime
        self.clock = clock
    }

    func value(at time: TimeInterval) -> Double {
        if clock?.shouldCompleteInstantly == true {
            return to
        }

        let currentTime = clock?.now() ?? time
        let elapsed = currentTime - startTime
        guard elapsed >= 0 else { return from }
        guard elapsed < duration else { return to }

        let t = elapsed / duration
        let eased = curve.apply(t)

        return from + (to - from) * eased
    }

    func isComplete(at time: TimeInterval) -> Bool {
        if clock?.shouldCompleteInstantly == true {
            return true
        }
        let currentTime = clock?.now() ?? time
        return currentTime - startTime >= duration
    }

    var targetValue: Double { to }
}

final class DecelerationAnimation {
    static let defaultDecelerationRate: Double = 0.997

    let from: Double
    let initialVelocity: Double
    let startTime: TimeInterval
    let decelerationRate: Double
    private let clock: AnimationClock?

    private let coeff: Double
    private let projectedEnd: Double

    init(
        from: Double,
        initialVelocity: Double,
        startTime: TimeInterval,
        decelerationRate: Double = DecelerationAnimation.defaultDecelerationRate,
        clock: AnimationClock? = nil
    ) {
        self.from = from
        self.startTime = startTime
        self.decelerationRate = decelerationRate
        self.clock = clock

        let scaledVelocity = initialVelocity / max(clock?.rate ?? 1.0, 0.001)
        self.initialVelocity = scaledVelocity
        self.coeff = 1000.0 * log(decelerationRate)
        self.projectedEnd = from - scaledVelocity / coeff
    }

    func value(at time: TimeInterval) -> Double {
        if clock?.shouldCompleteInstantly == true {
            return projectedEnd
        }

        let currentTime = clock?.now() ?? time
        let elapsed = currentTime - startTime
        guard elapsed >= 0 else { return from }

        let decayFactor = pow(decelerationRate, 1000.0 * elapsed)
        return from + (decayFactor - 1) / coeff * initialVelocity
    }

    func velocityAt(_ time: TimeInterval) -> Double {
        if clock?.shouldCompleteInstantly == true {
            return 0
        }

        let currentTime = clock?.now() ?? time
        let elapsed = currentTime - startTime
        guard elapsed >= 0 else { return initialVelocity }

        return initialVelocity * pow(decelerationRate, 1000.0 * elapsed)
    }

    func isComplete(at time: TimeInterval, threshold: Double = 0.001) -> Bool {
        if clock?.shouldCompleteInstantly == true {
            return true
        }
        return abs(velocityAt(time)) < threshold && abs(value(at: time) - projectedEnd) < 0.01
    }

    var targetValue: Double { projectedEnd }
}
