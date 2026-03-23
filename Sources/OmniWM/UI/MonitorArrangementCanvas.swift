import SwiftUI

// MARK: - MonitorArrangementCanvas

/// A 2D spatial canvas that renders monitors from `SpatialMonitorEntry` at
/// proportional sizes, supports drag-to-reposition, and magnetically snaps
/// edges to neighboring monitors on drag end.
///
/// Coordinate spaces:
/// - **AppKit** (stored): y=0 at bottom, increases upward.
/// - **Canvas** (rendered): y=0 at top, increases downward (SwiftUI).
/// - **Gesture**: y-down, same as canvas — deltas apply directly.
struct MonitorArrangementCanvas: View {
    @Binding var entries: [SpatialMonitorEntry]
    let connectedMonitors: [Monitor]
    @Binding var selectedMonitorId: Monitor.ID?

    @State private var dragOffset: CGSize = .zero
    @State private var draggingIndex: Int?

    /// Canvas-space snap threshold in points. Divided by scale at snap time
    /// so the feel is consistent regardless of zoom level.
    private let snapThresholdPt: CGFloat = 20.0

    /// Padding factor so monitors don't touch canvas edges.
    private let paddingFactor: CGFloat = 0.85

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let available = geometry.size
            let layout = CanvasLayout(entries: entries, availableSize: available, padding: paddingFactor)

            ZStack {
                // Monitor cards
                ForEach(entries.indices, id: \.self) { index in
                    let entry = entries[index]
                    let rect = layout.canvasRect(for: entry)
                    let isDragging = draggingIndex == index
                    let offset = isDragging ? dragOffset : .zero

                    monitorCard(
                        entry: entry,
                        index: index,
                        scaledSize: rect.size
                    )
                    .position(
                        x: rect.midX + offset.width,
                        y: rect.midY + offset.height
                    )
                    .zIndex(isDragging ? 1 : 0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                draggingIndex = index
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                applyDragEnd(
                                    index: index,
                                    translation: value.translation,
                                    layout: layout
                                )
                            }
                    )
                    .onTapGesture {
                        selectMonitor(at: index)
                    }
                }
            }
            .frame(width: available.width, height: available.height)
        }
    }

    // MARK: - Monitor card view

    @ViewBuilder
    private func monitorCard(
        entry: SpatialMonitorEntry,
        index: Int,
        scaledSize: CGSize
    ) -> some View {
        let monitor = connectedMonitors.first { $0.displayId == entry.displayId }
        let isSelected = selectedMonitorId == monitor?.id
        let labels = MonitorSettingsTabModel.displayLabels(for: connectedMonitors)
        let displayLabel = monitor.flatMap { labels[$0.id] }
        let isMain = monitor?.isMain ?? false

        RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .overlay(
                VStack(spacing: 4) {
                    Text(displayLabel?.name ?? entry.monitorName)
                        .font(.system(size: max(10, min(14, scaledSize.width / 12)), weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: 4) {
                        if let badgeText = displayLabel?.badgeText {
                            CanvasBadge(text: badgeText)
                        }
                        if isMain {
                            CanvasBadge(text: "Main")
                        }
                    }
                }
                .padding(6)
            )
            .frame(width: scaledSize.width, height: scaledSize.height)
    }

    // MARK: - Selection

    private func selectMonitor(at index: Int) {
        guard entries.indices.contains(index) else { return }
        let entry = entries[index]
        if let monitor = connectedMonitors.first(where: { $0.displayId == entry.displayId }) {
            selectedMonitorId = monitor.id
        }
    }

    // MARK: - Drag end → snap → write back

    private func applyDragEnd(
        index: Int,
        translation: CGSize,
        layout: CanvasLayout
    ) {
        guard entries.indices.contains(index) else {
            draggingIndex = nil
            dragOffset = .zero
            return
        }

        let entry = entries[index]
        let originalRect = layout.canvasRect(for: entry)

        // New canvas-space origin after drag.
        let newCanvasX = originalRect.minX + translation.width
        let newCanvasY = originalRect.minY + translation.height

        // Convert canvas-space back to AppKit-space.
        var newAppKitOrigin = layout.canvasToAppKit(
            canvasOrigin: CGPoint(x: newCanvasX, y: newCanvasY),
            entrySize: entry.size
        )

        // Snap to neighbors.
        newAppKitOrigin = snapToNeighbors(
            draggedIndex: index,
            proposedOrigin: newAppKitOrigin,
            draggedSize: entry.size,
            scale: layout.scale
        )

        entries[index].origin = newAppKitOrigin
        draggingIndex = nil
        dragOffset = .zero
    }

    // MARK: - Edge-snapping algorithm

    /// Snaps the dragged monitor's edges to the nearest neighboring edge
    /// within threshold. Horizontal and vertical axes snap independently.
    private func snapToNeighbors(
        draggedIndex: Int,
        proposedOrigin: CGPoint,
        draggedSize: CGSize,
        scale: CGFloat
    ) -> CGPoint {
        let threshold = snapThresholdPt / scale
        let draggedFrame = CGRect(origin: proposedOrigin, size: draggedSize)

        var bestHSnap: (offset: CGFloat, distance: CGFloat)?
        var bestVSnap: (offset: CGFloat, distance: CGFloat)?

        for (i, other) in entries.enumerated() where i != draggedIndex {
            let otherFrame = other.frame

            // Horizontal snapping: dragged right → other left
            let rightToLeft = otherFrame.minX - draggedFrame.maxX
            if abs(rightToLeft) < (bestHSnap?.distance ?? threshold) {
                bestHSnap = (rightToLeft, abs(rightToLeft))
            }

            // Horizontal snapping: dragged left → other right
            let leftToRight = otherFrame.maxX - draggedFrame.minX
            if abs(leftToRight) < (bestHSnap?.distance ?? threshold) {
                bestHSnap = (leftToRight, abs(leftToRight))
            }

            // Horizontal snapping: dragged left → other left (alignment)
            let leftToLeft = otherFrame.minX - draggedFrame.minX
            if abs(leftToLeft) < (bestHSnap?.distance ?? threshold) {
                bestHSnap = (leftToLeft, abs(leftToLeft))
            }

            // Horizontal snapping: dragged right → other right (alignment)
            let rightToRight = otherFrame.maxX - draggedFrame.maxX
            if abs(rightToRight) < (bestHSnap?.distance ?? threshold) {
                bestHSnap = (rightToRight, abs(rightToRight))
            }

            // Vertical snapping: dragged top → other bottom
            let topToBottom = otherFrame.minY - draggedFrame.maxY
            if abs(topToBottom) < (bestVSnap?.distance ?? threshold) {
                bestVSnap = (topToBottom, abs(topToBottom))
            }

            // Vertical snapping: dragged bottom → other top
            let bottomToTop = otherFrame.maxY - draggedFrame.minY
            if abs(bottomToTop) < (bestVSnap?.distance ?? threshold) {
                bestVSnap = (bottomToTop, abs(bottomToTop))
            }

            // Vertical snapping: dragged bottom → other bottom (alignment)
            let bottomToBottom = otherFrame.minY - draggedFrame.minY
            if abs(bottomToBottom) < (bestVSnap?.distance ?? threshold) {
                bestVSnap = (bottomToBottom, abs(bottomToBottom))
            }

            // Vertical snapping: dragged top → other top (alignment)
            let topToTop = otherFrame.maxY - draggedFrame.maxY
            if abs(topToTop) < (bestVSnap?.distance ?? threshold) {
                bestVSnap = (topToTop, abs(topToTop))
            }
        }

        var snapped = proposedOrigin
        if let h = bestHSnap {
            snapped.x += h.offset
        }
        if let v = bestVSnap {
            snapped.y += v.offset
        }
        return snapped
    }
}

// MARK: - CanvasLayout

/// Pure-value computation of the scale, offsets, and coordinate transforms
/// for rendering AppKit-space entries in a SwiftUI canvas.
private struct CanvasLayout {
    let scale: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    let bounds: CGRect
    let availableSize: CGSize

    init(entries: [SpatialMonitorEntry], availableSize: CGSize, padding: CGFloat) {
        self.availableSize = availableSize

        guard !entries.isEmpty else {
            self.bounds = .zero
            self.scale = 1
            self.xOffset = 0
            self.yOffset = 0
            return
        }

        // Compute bounding box of all entries in AppKit space.
        var union = entries[0].frame
        for entry in entries.dropFirst() {
            union = union.union(entry.frame)
        }
        self.bounds = union

        // Guard against zero-size bounding box (all entries at same point).
        let boundsWidth = max(union.width, 1)
        let boundsHeight = max(union.height, 1)

        // Uniform scale with padding.
        self.scale = min(
            availableSize.width / boundsWidth,
            availableSize.height / boundsHeight
        ) * padding

        // Center the scaled layout in available space.
        let scaledWidth = boundsWidth * scale
        let scaledHeight = boundsHeight * scale
        self.xOffset = (availableSize.width - scaledWidth) / 2
        self.yOffset = (availableSize.height - scaledHeight) / 2
    }

    /// Convert an AppKit-space entry to a canvas-space rect (y-flipped).
    func canvasRect(for entry: SpatialMonitorEntry) -> CGRect {
        let w = entry.size.width * scale
        let h = entry.size.height * scale

        // x: straightforward scale + offset
        let x = (entry.origin.x - bounds.minX) * scale + xOffset

        // y: flip — AppKit y=0 at bottom, SwiftUI y=0 at top.
        // relY = distance from bottom of bounding box in AppKit, scaled.
        // In canvas (top-down), bottommost entries get the highest y.
        let scaledBoundsHeight = bounds.height * scale
        let relY = (entry.origin.y - bounds.minY) * scale
        let y = yOffset + (scaledBoundsHeight - relY - h)

        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Convert a canvas-space origin back to AppKit-space origin.
    func canvasToAppKit(canvasOrigin: CGPoint, entrySize: CGSize) -> CGPoint {
        // Reverse of canvasRect:
        // canvasX = (appKitX - bounds.minX) * scale + xOffset
        // → appKitX = (canvasX - xOffset) / scale + bounds.minX
        let appKitX = (canvasOrigin.x - xOffset) / scale + bounds.minX

        // canvasY = yOffset + (scaledBoundsHeight - relY - h)
        // where relY = (appKitY - bounds.minY) * scale, h = entrySize.height * scale
        // → relY = scaledBoundsHeight - (canvasY - yOffset) - h
        // → appKitY = relY / scale + bounds.minY
        let scaledBoundsHeight = bounds.height * scale
        let h = entrySize.height * scale
        let relY = scaledBoundsHeight - (canvasOrigin.y - yOffset) - h
        let appKitY = relY / scale + bounds.minY

        return CGPoint(x: appKitX, y: appKitY)
    }
}

// MARK: - CanvasBadge

/// Small badge pill for monitor labels inside the canvas.
private struct CanvasBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
    }
}
