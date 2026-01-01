import AppKit
import QuartzCore

final class BorderWindow: NSWindow {
    private var edgeLayers: [CAShapeLayer] = []
    private var cornerLayers: [CAShapeLayer] = []
    private var config: BorderConfig
    private var lastTargetWid: UInt32?
    private var currentGeometry: BorderGeometry?
    private var currentCornerRadius: CornerRadius = .zero

    init(config: BorderConfig) {
        self.config = config

        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        ignoresMouseEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        let rootLayer = CALayer()
        rootLayer.masksToBounds = false

        for _ in 0..<4 {
            let layer = CAShapeLayer()
            layer.fillColor = config.color.cgColor
            layer.strokeColor = nil
            layer.lineWidth = 0
            edgeLayers.append(layer)
            rootLayer.addSublayer(layer)
        }

        for _ in 0..<4 {
            let layer = CAShapeLayer()
            layer.fillColor = config.color.cgColor
            layer.strokeColor = nil
            layer.lineWidth = 0
            cornerLayers.append(layer)
            rootLayer.addSublayer(layer)
        }

        contentView?.layer = rootLayer
        contentView?.wantsLayer = true
    }

    private var wid: UInt32 { UInt32(windowNumber) }

    func update(frame targetFrame: CGRect, windowCornerRadius: CornerRadius, targetWid: UInt32? = nil) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        let geometry = calculateBorderGeometry(
            windowSize: targetFrame.size,
            borderWidth: config.width,
            windowCornerRadius: windowCornerRadius,
            scale: scale
        )

        currentGeometry = geometry
        currentCornerRadius = windowCornerRadius

        let borderFrame = CGRect(
            x: targetFrame.origin.x - config.width,
            y: targetFrame.origin.y - config.width,
            width: targetFrame.width + config.width * 2,
            height: targetFrame.height + config.width * 2
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        setFrame(borderFrame, display: false)
        updateEdgeLayers(geometry: geometry)
        updateCornerLayers(geometry: geometry, scale: scale)

        CATransaction.commit()

        if let targetWid {
            lastTargetWid = targetWid
            SkyLight.shared.moveAndOrderWindow(wid, to: borderFrame.origin, relativeTo: targetWid, order: .below)
        }
    }

    private func updateEdgeLayers(geometry: BorderGeometry) {
        for i in 0..<4 {
            let size = geometry.sizes[i]
            let location = geometry.locations[i]

            let localOrigin = CGPoint(
                x: location.x + config.width,
                y: location.y + config.width
            )

            edgeLayers[i].frame = CGRect(origin: localOrigin, size: size)
            edgeLayers[i].path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        }
    }

    private func updateCornerLayers(geometry: BorderGeometry, scale: CGFloat) {
        let corners: [BorderPiece] = [
            .topLeftCorner,
            .topRightCorner,
            .bottomRightCorner,
            .bottomLeftCorner
        ]

        for (index, piece) in corners.enumerated() {
            let size = geometry.sizes[piece.rawValue]
            let location = geometry.locations[piece.rawValue]

            let localOrigin = CGPoint(
                x: location.x + config.width,
                y: location.y + config.width
            )

            cornerLayers[index].frame = CGRect(origin: localOrigin, size: size)

            let path = createCornerPath(
                cornerSize: size,
                geometry: geometry,
                corner: piece,
                thickenCorners: config.thickenCorners
            )
            cornerLayers[index].path = path
        }
    }

    private func createCornerPath(
        cornerSize: CGSize,
        geometry: BorderGeometry,
        corner: BorderPiece,
        thickenCorners: Bool
    ) -> CGPath {
        let path = CGMutablePath()
        let extra: CGFloat = thickenCorners ? 0.5 : 0

        let (outerR, rawInnerR): (CGFloat, CGFloat) = {
            switch corner {
            case .topLeftCorner:
                return (geometry.outerCornerRadius.topLeft, geometry.innerCornerRadius.topLeft)
            case .topRightCorner:
                return (geometry.outerCornerRadius.topRight, geometry.innerCornerRadius.topRight)
            case .bottomRightCorner:
                return (geometry.outerCornerRadius.bottomRight, geometry.innerCornerRadius.bottomRight)
            case .bottomLeftCorner:
                return (geometry.outerCornerRadius.bottomLeft, geometry.innerCornerRadius.bottomLeft)
            default:
                return (0, 0)
            }
        }()

        let innerR = max(0, rawInnerR - extra)

        if outerR <= 0 {
            path.addRect(CGRect(origin: .zero, size: cornerSize))
            return path
        }

        switch corner {
        case .topLeftCorner:
            path.move(to: CGPoint(x: 0, y: outerR))
            path.addArc(
                center: CGPoint(x: outerR, y: outerR),
                radius: outerR,
                startAngle: .pi,
                endAngle: -.pi / 2,
                clockwise: false
            )
            if innerR > 0 {
                path.addLine(to: CGPoint(x: outerR, y: outerR - innerR))
                path.addArc(
                    center: CGPoint(x: outerR, y: outerR),
                    radius: innerR,
                    startAngle: -.pi / 2,
                    endAngle: .pi,
                    clockwise: true
                )
            } else {
                path.addLine(to: CGPoint(x: outerR, y: outerR))
            }
            path.closeSubpath()

        case .topRightCorner:
            path.move(to: CGPoint(x: outerR, y: outerR))
            path.addArc(
                center: CGPoint(x: 0, y: outerR),
                radius: outerR,
                startAngle: 0,
                endAngle: -.pi / 2,
                clockwise: true
            )
            if innerR > 0 {
                path.addLine(to: CGPoint(x: 0, y: outerR - innerR))
                path.addArc(
                    center: CGPoint(x: 0, y: outerR),
                    radius: innerR,
                    startAngle: -.pi / 2,
                    endAngle: 0,
                    clockwise: false
                )
            } else {
                path.addLine(to: CGPoint(x: 0, y: outerR))
            }
            path.closeSubpath()

        case .bottomRightCorner:
            path.move(to: CGPoint(x: 0, y: outerR))
            path.addArc(
                center: CGPoint(x: 0, y: 0),
                radius: outerR,
                startAngle: .pi / 2,
                endAngle: 0,
                clockwise: true
            )
            if innerR > 0 {
                path.addLine(to: CGPoint(x: innerR, y: 0))
                path.addArc(
                    center: CGPoint(x: 0, y: 0),
                    radius: innerR,
                    startAngle: 0,
                    endAngle: .pi / 2,
                    clockwise: false
                )
            } else {
                path.addLine(to: CGPoint(x: 0, y: 0))
            }
            path.closeSubpath()

        case .bottomLeftCorner:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addArc(
                center: CGPoint(x: outerR, y: 0),
                radius: outerR,
                startAngle: .pi,
                endAngle: .pi / 2,
                clockwise: false
            )
            if innerR > 0 {
                path.addLine(to: CGPoint(x: outerR, y: innerR))
                path.addArc(
                    center: CGPoint(x: outerR, y: 0),
                    radius: innerR,
                    startAngle: .pi / 2,
                    endAngle: .pi,
                    clockwise: true
                )
            } else {
                path.addLine(to: CGPoint(x: outerR, y: 0))
            }
            path.closeSubpath()

        default:
            path.addRect(CGRect(origin: .zero, size: cornerSize))
        }

        return path
    }

    func updateConfig(_ newConfig: BorderConfig) {
        config = newConfig
        let cgColor = config.color.cgColor

        for layer in edgeLayers {
            layer.fillColor = cgColor
        }
        for layer in cornerLayers {
            layer.fillColor = cgColor
        }
    }
}
