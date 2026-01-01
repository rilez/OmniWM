import Foundation

enum BorderPiece: Int, CaseIterable {
    case topEdge = 0
    case bottomEdge = 1
    case leftEdge = 2
    case rightEdge = 3
    case topLeftCorner = 4
    case topRightCorner = 5
    case bottomRightCorner = 6
    case bottomLeftCorner = 7
}

struct BorderGeometry {
    var sizes: [CGSize]
    var locations: [CGPoint]
    var cornerSizes: (topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat)
    var outerCornerRadius: CornerRadius
    var innerCornerRadius: CornerRadius

    init() {
        sizes = Array(repeating: .zero, count: 8)
        locations = Array(repeating: .zero, count: 8)
        cornerSizes = (0, 0, 0, 0)
        outerCornerRadius = .zero
        innerCornerRadius = .zero
    }
}

func calculateBorderGeometry(
    windowSize: CGSize,
    borderWidth: CGFloat,
    windowCornerRadius: CornerRadius,
    scale: CGFloat
) -> BorderGeometry {
    var geometry = BorderGeometry()

    let width = borderWidth
    let fullSize = CGSize(
        width: windowSize.width + width * 2,
        height: windowSize.height + width * 2
    )

    let ceil = { (logical: CGFloat) -> CGFloat in
        (logical * scale).rounded(.up) / scale
    }

    let outerRadius = windowCornerRadius.expanded(by: width)
        .fitTo(width: fullSize.width, height: fullSize.height)

    geometry.outerCornerRadius = outerRadius
    geometry.innerCornerRadius = windowCornerRadius

    let topLeft = max(width, ceil(outerRadius.topLeft))
    let topRight = min(
        fullSize.width - topLeft,
        max(width, ceil(outerRadius.topRight))
    )
    let bottomLeft = min(
        fullSize.height - topLeft,
        max(width, ceil(outerRadius.bottomLeft))
    )
    let bottomRight = min(
        fullSize.height - topRight,
        min(
            fullSize.width - bottomLeft,
            max(width, ceil(outerRadius.bottomRight))
        )
    )

    geometry.cornerSizes = (topLeft, topRight, bottomLeft, bottomRight)

    geometry.sizes[BorderPiece.topEdge.rawValue] = CGSize(
        width: windowSize.width + width * 2 - topLeft - topRight,
        height: width
    )
    geometry.locations[BorderPiece.topEdge.rawValue] = CGPoint(
        x: -width + topLeft,
        y: -width
    )

    geometry.sizes[BorderPiece.bottomEdge.rawValue] = CGSize(
        width: windowSize.width + width * 2 - bottomLeft - bottomRight,
        height: width
    )
    geometry.locations[BorderPiece.bottomEdge.rawValue] = CGPoint(
        x: -width + bottomLeft,
        y: windowSize.height
    )

    geometry.sizes[BorderPiece.leftEdge.rawValue] = CGSize(
        width: width,
        height: windowSize.height + width * 2 - topLeft - bottomLeft
    )
    geometry.locations[BorderPiece.leftEdge.rawValue] = CGPoint(
        x: -width,
        y: -width + topLeft
    )

    geometry.sizes[BorderPiece.rightEdge.rawValue] = CGSize(
        width: width,
        height: windowSize.height + width * 2 - topRight - bottomRight
    )
    geometry.locations[BorderPiece.rightEdge.rawValue] = CGPoint(
        x: windowSize.width,
        y: -width + topRight
    )

    geometry.sizes[BorderPiece.topLeftCorner.rawValue] = CGSize(
        width: topLeft,
        height: topLeft
    )
    geometry.locations[BorderPiece.topLeftCorner.rawValue] = CGPoint(
        x: -width,
        y: -width
    )

    geometry.sizes[BorderPiece.topRightCorner.rawValue] = CGSize(
        width: topRight,
        height: topRight
    )
    geometry.locations[BorderPiece.topRightCorner.rawValue] = CGPoint(
        x: windowSize.width + width - topRight,
        y: -width
    )

    geometry.sizes[BorderPiece.bottomRightCorner.rawValue] = CGSize(
        width: bottomRight,
        height: bottomRight
    )
    geometry.locations[BorderPiece.bottomRightCorner.rawValue] = CGPoint(
        x: windowSize.width + width - bottomRight,
        y: windowSize.height + width - bottomRight
    )

    geometry.sizes[BorderPiece.bottomLeftCorner.rawValue] = CGSize(
        width: bottomLeft,
        height: bottomLeft
    )
    geometry.locations[BorderPiece.bottomLeftCorner.rawValue] = CGPoint(
        x: -width,
        y: windowSize.height + width - bottomLeft
    )

    return geometry
}
