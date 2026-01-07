import AppKit
import Foundation

extension CGFloat {
    func roundedToPhysicalPixel(scale: CGFloat) -> CGFloat {
        (self * scale).rounded() / scale
    }
}

extension CGPoint {
    func roundedToPhysicalPixels(scale: CGFloat) -> CGPoint {
        CGPoint(
            x: x.roundedToPhysicalPixel(scale: scale),
            y: y.roundedToPhysicalPixel(scale: scale)
        )
    }
}

extension CGSize {
    func roundedToPhysicalPixels(scale: CGFloat) -> CGSize {
        CGSize(
            width: width.roundedToPhysicalPixel(scale: scale),
            height: height.roundedToPhysicalPixel(scale: scale)
        )
    }
}

extension CGRect {
    func roundedToPhysicalPixels(scale: CGFloat) -> CGRect {
        CGRect(
            origin: origin.roundedToPhysicalPixels(scale: scale),
            size: size.roundedToPhysicalPixels(scale: scale)
        )
    }
}

struct LayoutResult {
    let frames: [WindowHandle: CGRect]
    let hiddenHandles: [WindowHandle: HideSide]
}

extension NiriLayoutEngine {
    func calculateLayout(
        state: ViewportState,
        workspaceId: WorkspaceDescriptor.ID,
        monitorFrame: CGRect,
        screenFrame: CGRect? = nil,
        gaps: (horizontal: CGFloat, vertical: CGFloat),
        focusedColumnIndex _: Int? = nil,
        scale: CGFloat = 2.0,
        workingArea: WorkingAreaContext? = nil,
        orientation: Monitor.Orientation = .horizontal
    ) -> [WindowHandle: CGRect] {
        calculateLayoutWithVisibility(
            state: state,
            workspaceId: workspaceId,
            monitorFrame: monitorFrame,
            screenFrame: screenFrame,
            gaps: gaps,
            scale: scale,
            workingArea: workingArea,
            orientation: orientation
        ).frames
    }

    func calculateLayoutWithVisibility(
        state: ViewportState,
        workspaceId: WorkspaceDescriptor.ID,
        monitorFrame: CGRect,
        screenFrame: CGRect? = nil,
        gaps: (horizontal: CGFloat, vertical: CGFloat),
        scale: CGFloat = 2.0,
        workingArea: WorkingAreaContext? = nil,
        orientation: Monitor.Orientation = .horizontal,
        animationTime: TimeInterval? = nil
    ) -> LayoutResult {
        switch orientation {
        case .horizontal:
            calculateHorizontalLayoutWithVisibility(
                state: state,
                workspaceId: workspaceId,
                monitorFrame: monitorFrame,
                screenFrame: screenFrame,
                gaps: gaps,
                scale: scale,
                workingArea: workingArea,
                animationTime: animationTime
            )
        case .vertical:
            calculateVerticalLayoutWithVisibility(
                state: state,
                workspaceId: workspaceId,
                monitorFrame: monitorFrame,
                screenFrame: screenFrame,
                gaps: gaps,
                scale: scale,
                workingArea: workingArea,
                animationTime: animationTime
            )
        }
    }

    private func calculateHorizontalLayoutWithVisibility(
        state: ViewportState,
        workspaceId: WorkspaceDescriptor.ID,
        monitorFrame: CGRect,
        screenFrame: CGRect? = nil,
        gaps: (horizontal: CGFloat, vertical: CGFloat),
        scale: CGFloat = 2.0,
        workingArea: WorkingAreaContext? = nil,
        animationTime: TimeInterval? = nil
    ) -> LayoutResult {
        var frames: [WindowHandle: CGRect] = [:]
        var hiddenHandles: [WindowHandle: HideSide] = [:]

        let cols = columns(in: workspaceId)
        guard !cols.isEmpty else { return LayoutResult(frames: frames, hiddenHandles: hiddenHandles) }

        let workingFrame = workingArea?.workingFrame ?? monitorFrame
        let viewFrame = workingArea?.viewFrame ?? screenFrame ?? monitorFrame
        let effectiveScale = workingArea?.scale ?? scale

        let horizontalGap = gaps.horizontal

        let time = animationTime ?? CACurrentMediaTime()

        for column in cols {
            if column.cachedWidth <= 0 {
                column.resolveAndCacheWidth(workingAreaWidth: workingFrame.width, gaps: horizontalGap)
            }
        }

        var columnXPositions = [CGFloat]()
        columnXPositions.reserveCapacity(cols.count)
        var runningX: CGFloat = 0
        var totalColumnsWidth: CGFloat = 0
        for (i, column) in cols.enumerated() {
            columnXPositions.append(runningX)
            runningX += column.cachedWidth + horizontalGap
            totalColumnsWidth += column.cachedWidth
            if i < cols.count - 1 {
                totalColumnsWidth += horizontalGap
            }
        }

        let viewOffset = state.viewOffsetPixels.value(at: time)
        let activeColIdx = state.activeColumnIndex.clamped(to: 0 ... max(0, cols.count - 1))
        let activeColX = cols.isEmpty ? 0 : columnXPositions[activeColIdx]
        let viewPos = activeColX + viewOffset
        let viewLeft = viewPos
        let viewRight = viewLeft + workingFrame.width

        var usedIndices = Set<Int>()

        for (idx, column) in cols.enumerated() {
            let colX = columnXPositions[idx]
            let colRight = colX + column.cachedWidth
            let columnRenderOffset = column.renderOffset(at: time)

            let isVisible = colRight > viewLeft && colX < viewRight

            if isVisible {
                usedIndices.insert(idx)

                let screenX = workingFrame.origin.x + colX - viewPos + columnRenderOffset.x
                let width = column.cachedWidth.roundedToPhysicalPixel(scale: effectiveScale)

                let columnRect = CGRect(
                    x: screenX,
                    y: workingFrame.origin.y,
                    width: width,
                    height: workingFrame.height
                ).roundedToPhysicalPixels(scale: effectiveScale)

                layoutColumn(
                    column: column,
                    columnRect: columnRect,
                    screenRect: viewFrame,
                    verticalGap: gaps.vertical,
                    scale: effectiveScale,
                    columnRenderOffset: columnRenderOffset,
                    animationTime: time,
                    result: &frames
                )
            } else {
                let hideSide: HideSide = colRight <= viewLeft ? .left : .right
                for window in column.windowNodes {
                    hiddenHandles[window.handle] = hideSide
                }
            }
        }

        if cols.count > usedIndices.count {
            let avgWidth = totalColumnsWidth / CGFloat(max(1, cols.count))
            let hiddenWidth = max(1, avgWidth).roundedToPhysicalPixel(scale: effectiveScale)
            for (idx, column) in cols.enumerated() {
                if usedIndices.contains(idx) { continue }

                let hiddenRect = hiddenColumnRect(
                    screenRect: viewFrame,
                    width: hiddenWidth,
                    height: workingFrame.height
                ).roundedToPhysicalPixels(scale: effectiveScale)

                layoutColumn(
                    column: column,
                    columnRect: hiddenRect,
                    screenRect: viewFrame,
                    verticalGap: gaps.vertical,
                    scale: effectiveScale,
                    columnRenderOffset: .zero,
                    animationTime: time,
                    result: &frames
                )
            }
        }

        return LayoutResult(frames: frames, hiddenHandles: hiddenHandles)
    }

    private func calculateVerticalLayoutWithVisibility(
        state: ViewportState,
        workspaceId: WorkspaceDescriptor.ID,
        monitorFrame: CGRect,
        screenFrame: CGRect? = nil,
        gaps: (horizontal: CGFloat, vertical: CGFloat),
        scale: CGFloat = 2.0,
        workingArea: WorkingAreaContext? = nil,
        animationTime: TimeInterval? = nil
    ) -> LayoutResult {
        var frames: [WindowHandle: CGRect] = [:]
        var hiddenHandles: [WindowHandle: HideSide] = [:]

        let rows = columns(in: workspaceId)
        guard !rows.isEmpty else { return LayoutResult(frames: frames, hiddenHandles: hiddenHandles) }

        let workingFrame = workingArea?.workingFrame ?? monitorFrame
        let viewFrame = workingArea?.viewFrame ?? screenFrame ?? monitorFrame
        let effectiveScale = workingArea?.scale ?? scale

        let verticalGap = gaps.vertical

        let time = animationTime ?? CACurrentMediaTime()

        for row in rows {
            if row.cachedHeight <= 0 {
                row.resolveAndCacheHeight(workingAreaHeight: workingFrame.height, gaps: verticalGap)
            }
        }

        var rowYPositions = [CGFloat]()
        rowYPositions.reserveCapacity(rows.count)
        var runningY: CGFloat = 0
        var totalRowsHeight: CGFloat = 0
        for (i, row) in rows.enumerated() {
            rowYPositions.append(runningY)
            runningY += row.cachedHeight + verticalGap
            totalRowsHeight += row.cachedHeight
            if i < rows.count - 1 {
                totalRowsHeight += verticalGap
            }
        }

        let viewOffset = state.viewOffsetPixels.value(at: time)
        let activeRowIdx = state.activeColumnIndex.clamped(to: 0 ... max(0, rows.count - 1))
        let activeRowY = rows.isEmpty ? 0 : rowYPositions[activeRowIdx]
        let viewPos = activeRowY + viewOffset
        let viewTop = viewPos
        let viewBottom = viewTop + workingFrame.height

        var usedIndices = Set<Int>()

        for (idx, row) in rows.enumerated() {
            let rowYPos = rowYPositions[idx]
            let rowBottom = rowYPos + row.cachedHeight
            let rowRenderOffset = row.renderOffset(at: time)

            let isVisible = rowBottom > viewTop && rowYPos < viewBottom

            if isVisible {
                usedIndices.insert(idx)

                let screenY = workingFrame.origin.y + rowYPos - viewPos + rowRenderOffset.y
                let height = row.cachedHeight.roundedToPhysicalPixel(scale: effectiveScale)

                let rowRect = CGRect(
                    x: workingFrame.origin.x,
                    y: screenY,
                    width: workingFrame.width,
                    height: height
                ).roundedToPhysicalPixels(scale: effectiveScale)

                layoutRow(
                    row: row,
                    rowRect: rowRect,
                    screenRect: viewFrame,
                    horizontalGap: gaps.horizontal,
                    scale: effectiveScale,
                    rowRenderOffset: rowRenderOffset,
                    animationTime: time,
                    result: &frames
                )
            } else {
                let hideSide: HideSide = rowBottom <= viewTop ? .left : .right
                for window in row.windowNodes {
                    hiddenHandles[window.handle] = hideSide
                }
            }
        }

        if rows.count > usedIndices.count {
            let avgHeight = totalRowsHeight / CGFloat(max(1, rows.count))
            let hiddenHeight = max(1, avgHeight).roundedToPhysicalPixel(scale: effectiveScale)
            for (idx, row) in rows.enumerated() {
                if usedIndices.contains(idx) { continue }

                let hiddenRect = hiddenRowRect(
                    screenRect: viewFrame,
                    width: workingFrame.width,
                    height: hiddenHeight
                ).roundedToPhysicalPixels(scale: effectiveScale)

                layoutRow(
                    row: row,
                    rowRect: hiddenRect,
                    screenRect: viewFrame,
                    horizontalGap: gaps.horizontal,
                    scale: effectiveScale,
                    rowRenderOffset: .zero,
                    animationTime: time,
                    result: &frames
                )
            }
        }

        return LayoutResult(frames: frames, hiddenHandles: hiddenHandles)
    }

    private func layoutRow(
        row: NiriContainer,
        rowRect: CGRect,
        screenRect: CGRect,
        horizontalGap: CGFloat,
        scale: CGFloat,
        rowRenderOffset: CGPoint = .zero,
        animationTime: TimeInterval? = nil,
        result: inout [WindowHandle: CGRect]
    ) {
        row.frame = rowRect

        let tabOffset = row.isTabbed ? renderStyle.tabIndicatorWidth : 0
        let contentRect = CGRect(
            x: rowRect.origin.x + tabOffset,
            y: rowRect.origin.y,
            width: max(0, rowRect.width - tabOffset),
            height: rowRect.height
        )

        let windows = row.windowNodes
        guard !windows.isEmpty else { return }

        let isTabbed = row.isTabbed
        let time = animationTime ?? CACurrentMediaTime()

        let resolvedWidths = resolveWindowWidths(
            windows: windows,
            availableWidth: contentRect.width,
            horizontalGap: horizontalGap,
            isTabbed: isTabbed
        )

        var x = contentRect.origin.x

        for (i, window) in windows.enumerated() {
            let windowWidth = resolvedWidths[i]

            let frame: CGRect = switch window.sizingMode {
            case .fullscreen:
                screenRect.roundedToPhysicalPixels(scale: scale)
            case .normal:
                CGRect(
                    x: isTabbed ? contentRect.origin.x : x,
                    y: contentRect.origin.y,
                    width: windowWidth,
                    height: contentRect.height
                ).roundedToPhysicalPixels(scale: scale)
            }

            window.frame = frame
            window.resolvedWidth = windowWidth

            let windowOffset = window.renderOffset(at: time)
            let totalOffset = CGPoint(
                x: rowRenderOffset.x + windowOffset.x,
                y: rowRenderOffset.y + windowOffset.y
            )
            let animatedFrame = frame.offsetBy(dx: totalOffset.x, dy: totalOffset.y)
                .roundedToPhysicalPixels(scale: scale)
            result[window.handle] = animatedFrame

            if !isTabbed {
                x += windowWidth
                if i < windows.count - 1 {
                    x += horizontalGap
                }
            }
        }
    }

    private func resolveWindowWidths(
        windows: [NiriWindow],
        availableWidth: CGFloat,
        horizontalGap: CGFloat,
        isTabbed: Bool = false
    ) -> [CGFloat] {
        guard !windows.isEmpty else { return [] }

        let inputs: [NiriRowWidthSolver.WindowInput] = windows.map { window in
            let weight = window.widthWeight

            let isFixedWidth: Bool
            let fixedWidth: CGFloat?
            switch window.windowWidth {
            case let .fixed(w):
                isFixedWidth = true
                fixedWidth = w
            case .auto:
                isFixedWidth = false
                fixedWidth = nil
            }

            return NiriRowWidthSolver.WindowInput(
                weight: max(0.1, weight),
                constraints: window.constraints,
                isFixedWidth: isFixedWidth,
                fixedWidth: fixedWidth
            )
        }

        let outputs = NiriRowWidthSolver.solve(
            windows: inputs,
            availableWidth: availableWidth,
            gapSize: horizontalGap,
            isTabbed: isTabbed
        )

        for (i, output) in outputs.enumerated() {
            windows[i].widthFixedByConstraint = output.wasConstrained
        }

        return outputs.map(\.width)
    }

    private func hiddenRowRect(
        screenRect: CGRect,
        width: CGFloat,
        height: CGFloat
    ) -> CGRect {
        let origin = CGPoint(
            x: screenRect.maxX - 2,
            y: screenRect.maxY - 2
        )
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    private func layoutColumn(
        column: NiriContainer,
        columnRect: CGRect,
        screenRect: CGRect,
        verticalGap: CGFloat,
        scale: CGFloat,
        columnRenderOffset: CGPoint = .zero,
        animationTime: TimeInterval? = nil,
        result: inout [WindowHandle: CGRect]
    ) {
        column.frame = columnRect

        let tabOffset = column.isTabbed ? renderStyle.tabIndicatorWidth : 0
        let contentRect = CGRect(
            x: columnRect.origin.x + tabOffset,
            y: columnRect.origin.y,
            width: max(0, columnRect.width - tabOffset),
            height: columnRect.height
        )

        let rows = column.windowNodes
        guard !rows.isEmpty else { return }

        let isTabbed = column.isTabbed
        let time = animationTime ?? CACurrentMediaTime()

        let resolvedHeights = resolveWindowHeights(
            windows: rows,
            availableHeight: contentRect.height,
            verticalGap: verticalGap,
            isTabbed: isTabbed
        )

        var y = contentRect.origin.y

        for (i, row) in rows.enumerated() {
            let rowHeight = resolvedHeights[i]

            let frame: CGRect = switch row.sizingMode {
            case .fullscreen:
                screenRect.roundedToPhysicalPixels(scale: scale)
            case .normal:
                CGRect(
                    x: contentRect.origin.x,
                    y: isTabbed ? contentRect.origin.y : y,
                    width: contentRect.width,
                    height: rowHeight
                ).roundedToPhysicalPixels(scale: scale)
            }

            row.frame = frame
            row.resolvedHeight = rowHeight

            let windowOffset = row.renderOffset(at: time)
            let totalOffset = CGPoint(
                x: columnRenderOffset.x + windowOffset.x,
                y: columnRenderOffset.y + windowOffset.y
            )
            let animatedFrame = frame.offsetBy(dx: totalOffset.x, dy: totalOffset.y)
                .roundedToPhysicalPixels(scale: scale)
            result[row.handle] = animatedFrame

            if !isTabbed {
                y += rowHeight
                if i < rows.count - 1 {
                    y += verticalGap
                }
            }
        }
    }

    private func resolveWindowHeights(
        windows: [NiriWindow],
        availableHeight: CGFloat,
        verticalGap: CGFloat,
        isTabbed: Bool = false
    ) -> [CGFloat] {
        guard !windows.isEmpty else { return [] }

        let inputs: [NiriColumnHeightSolver.WindowInput] = windows.map { window in
            let weight = window.size

            let isFixedHeight: Bool
            let fixedHeight: CGFloat?
            switch window.height {
            case let .fixed(h):
                isFixedHeight = true
                fixedHeight = h
            case .auto:
                isFixedHeight = false
                fixedHeight = nil
            }

            return NiriColumnHeightSolver.WindowInput(
                weight: max(0.1, weight),
                constraints: window.constraints,
                isFixedHeight: isFixedHeight,
                fixedHeight: fixedHeight
            )
        }

        let outputs = NiriColumnHeightSolver.solve(
            windows: inputs,
            availableHeight: availableHeight,
            gapSize: verticalGap,
            isTabbed: isTabbed
        )

        for (i, output) in outputs.enumerated() {
            windows[i].heightFixedByConstraint = output.wasConstrained
        }

        return outputs.map(\.height)
    }

    private func hiddenColumnRect(
        screenRect: CGRect,
        width: CGFloat,
        height: CGFloat
    ) -> CGRect {
        let origin = CGPoint(
            x: screenRect.maxX - 2,
            y: screenRect.maxY - 2
        )
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }
}
