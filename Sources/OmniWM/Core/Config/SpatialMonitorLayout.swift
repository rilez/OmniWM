import CoreGraphics

// MARK: - SpatialMonitorEntry

/// A monitor's position in the shared 2D spatial layout.
/// Identity is the combination of `displayId` + `monitorName`.
/// Coordinates are AppKit space (y=0 at bottom of main display).
struct SpatialMonitorEntry: Codable, Equatable, Sendable {
    var monitorName: String
    var displayId: CGDirectDisplayID
    var origin: CGPoint
    var size: CGSize

    var frame: CGRect {
        CGRect(origin: origin, size: size)
    }
}

// MARK: - SpatialMonitorLayout

/// Stores monitor positions as origin-offset rectangles in a shared 2D
/// coordinate space, with geometric adjacency queries.
struct SpatialMonitorLayout: Codable, Equatable, Sendable {
    var entries: [SpatialMonitorEntry]

    init(entries: [SpatialMonitorEntry] = []) {
        self.entries = entries
    }

    // MARK: - Edge

    enum Edge: Sendable {
        case left, right, top, bottom

        /// Left/right edges have a perpendicular Y axis; top/bottom have X.
        var isHorizontal: Bool {
            self == .left || self == .right
        }
    }

    // MARK: - Adjacency queries

    /// Find the first other monitor whose opposite edge aligns (within ≤1pt
    /// tolerance) with the given edge of `entry`, and whose perpendicular
    /// range includes `atPosition`.
    func adjacentMonitor(
        from entry: SpatialMonitorEntry,
        edge: Edge,
        atPosition: CGFloat
    ) -> SpatialMonitorEntry? {
        let src = entry.frame
        for candidate in entries where candidate != entry {
            let dst = candidate.frame
            switch edge {
            case .right:
                // Source's right edge → candidate's left edge
                guard abs(dst.minX - src.maxX) <= 1 else { continue }
                guard atPosition >= dst.minY, atPosition <= dst.maxY else { continue }
            case .left:
                // Source's left edge → candidate's right edge
                guard abs(dst.maxX - src.minX) <= 1 else { continue }
                guard atPosition >= dst.minY, atPosition <= dst.maxY else { continue }
            case .top:
                // Source's top edge → candidate's bottom edge
                guard abs(dst.minY - src.maxY) <= 1 else { continue }
                guard atPosition >= dst.minX, atPosition <= dst.maxX else { continue }
            case .bottom:
                // Source's bottom edge → candidate's top edge
                guard abs(dst.maxY - src.minY) <= 1 else { continue }
                guard atPosition >= dst.minX, atPosition <= dst.maxX else { continue }
            }
            return candidate
        }
        return nil
    }

    /// Returns the overlapping perpendicular pixel segment between two
    /// monitors on a shared edge, or `nil` if edges don't align or don't
    /// overlap.
    func overlapRange(
        from: SpatialMonitorEntry,
        to: SpatialMonitorEntry,
        edge: Edge
    ) -> ClosedRange<CGFloat>? {
        let srcFrame = from.frame
        let dstFrame = to.frame

        switch edge {
        case .left, .right:
            // Check edge alignment
            if edge == .right {
                guard abs(dstFrame.minX - srcFrame.maxX) <= 1 else { return nil }
            } else {
                guard abs(dstFrame.maxX - srcFrame.minX) <= 1 else { return nil }
            }
            // Overlap is intersection of Y ranges
            let lo = max(srcFrame.minY, dstFrame.minY)
            let hi = min(srcFrame.maxY, dstFrame.maxY)
            guard lo < hi else { return nil }
            return lo...hi

        case .top, .bottom:
            // Check edge alignment
            if edge == .top {
                guard abs(dstFrame.minY - srcFrame.maxY) <= 1 else { return nil }
            } else {
                guard abs(dstFrame.maxY - srcFrame.minY) <= 1 else { return nil }
            }
            // Overlap is intersection of X ranges
            let lo = max(srcFrame.minX, dstFrame.minX)
            let hi = min(srcFrame.maxX, dstFrame.maxX)
            guard lo < hi else { return nil }
            return lo...hi
        }
    }

    /// Convenience: true if there is an adjacent monitor from the given edge
    /// at the given position.
    func hasAdjacentMonitor(
        from entry: SpatialMonitorEntry,
        edge: Edge,
        atPosition: CGFloat
    ) -> Bool {
        adjacentMonitor(from: entry, edge: edge, atPosition: atPosition) != nil
    }

    // MARK: - Factory

    /// Build an initial layout from the currently connected displays.
    /// Returns an empty layout if no screens are detected.
    @MainActor
    static func seedFromCurrentDisplays() -> SpatialMonitorLayout {
        let monitors = Monitor.current()
        let entries = monitors.map { monitor in
            SpatialMonitorEntry(
                monitorName: monitor.name,
                displayId: monitor.displayId,
                origin: monitor.frame.origin,
                size: monitor.frame.size
            )
        }
        return SpatialMonitorLayout(entries: entries)
    }
}
