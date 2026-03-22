import CoreGraphics
import Foundation

enum HideSide {
    case left
    case right
}

enum AxisHideEdge {
    case minimum
    case maximum

    init(encodedHideSide: HideSide) {
        switch encodedHideSide {
        case .left:
            self = .minimum
        case .right:
            self = .maximum
        }
    }

    var encodedHideSide: HideSide {
        switch self {
        case .minimum:
            .left
        case .maximum:
            .right
        }
    }

    var opposite: AxisHideEdge {
        switch self {
        case .minimum:
            .maximum
        case .maximum:
            .minimum
        }
    }
}

struct HiddenPlacementMonitorContext {
    let id: Monitor.ID
    let frame: CGRect
    let visibleFrame: CGRect

    init(id: Monitor.ID, frame: CGRect, visibleFrame: CGRect) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
    }

    init(_ monitor: Monitor) {
        self.init(id: monitor.id, frame: monitor.frame, visibleFrame: monitor.visibleFrame)
    }

    init(_ monitor: NiriMonitor) {
        self.init(id: monitor.id, frame: monitor.frame, visibleFrame: monitor.visibleFrame)
    }
}

struct HiddenWindowPlacement {
    let requestedEdge: AxisHideEdge
    let resolvedEdge: AxisHideEdge
    let origin: CGPoint

    func frame(for size: CGSize) -> CGRect {
        CGRect(origin: origin, size: size)
    }
}

enum HiddenWindowPlacementResolver {
    static func placement(
        for size: CGSize,
        requestedEdge: AxisHideEdge,
        orthogonalOrigin: CGFloat,
        baseReveal: CGFloat,
        scale: CGFloat,
        orientation: Monitor.Orientation,
        monitor: HiddenPlacementMonitorContext,
        monitors: [HiddenPlacementMonitorContext]
    ) -> HiddenWindowPlacement {
        let reveal = baseReveal / max(1.0, scale)

        func origin(for edge: AxisHideEdge) -> CGPoint {
            switch orientation {
            case .horizontal:
                switch edge {
                case .minimum:
                    return CGPoint(
                        x: monitor.visibleFrame.minX - size.width + reveal,
                        y: orthogonalOrigin
                    )
                case .maximum:
                    return CGPoint(
                        x: monitor.visibleFrame.maxX - reveal,
                        y: orthogonalOrigin
                    )
                }
            case .vertical:
                switch edge {
                case .minimum:
                    return CGPoint(
                        x: orthogonalOrigin,
                        y: monitor.visibleFrame.minY - size.height + reveal
                    )
                case .maximum:
                    return CGPoint(
                        x: orthogonalOrigin,
                        y: monitor.visibleFrame.maxY - reveal
                    )
                }
            }
        }

        func overlapArea(for origin: CGPoint) -> CGFloat {
            let rect = CGRect(origin: origin, size: size)
            var area: CGFloat = 0
            for other in monitors where other.id != monitor.id {
                let intersection = rect.intersection(other.frame)
                if intersection.isNull { continue }
                area += intersection.width * intersection.height
            }
            return area
        }

        let primaryOrigin = origin(for: requestedEdge)
        let primaryOverlap = overlapArea(for: primaryOrigin)
        if primaryOverlap == 0 {
            return HiddenWindowPlacement(
                requestedEdge: requestedEdge,
                resolvedEdge: requestedEdge,
                origin: primaryOrigin
            )
        }

        let alternateEdge = requestedEdge.opposite
        let alternateOrigin = origin(for: alternateEdge)
        let alternateOverlap = overlapArea(for: alternateOrigin)
        if alternateOverlap < primaryOverlap {
            return HiddenWindowPlacement(
                requestedEdge: requestedEdge,
                resolvedEdge: alternateEdge,
                origin: alternateOrigin
            )
        }

        return HiddenWindowPlacement(
            requestedEdge: requestedEdge,
            resolvedEdge: requestedEdge,
            origin: primaryOrigin
        )
    }
}
