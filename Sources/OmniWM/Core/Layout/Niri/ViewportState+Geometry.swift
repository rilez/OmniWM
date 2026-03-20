import Foundation

extension ViewportState {
    private func allowedOffsetRange(
        targetPos: CGFloat,
        totalSpan: CGFloat,
        viewportSpan: CGFloat
    ) -> ClosedRange<CGFloat>? {
        guard totalSpan > viewportSpan else { return nil }

        let minOffset = -targetPos
        let maxOffset = totalSpan - viewportSpan - targetPos
        return minOffset ... maxOffset
    }

    func columnX(at index: Int, columns: [NiriContainer], gap: CGFloat) -> CGFloat {
        containerPosition(at: index, containers: columns, gap: gap, sizeKeyPath: \.cachedWidth)
    }

    func totalWidth(columns: [NiriContainer], gap: CGFloat) -> CGFloat {
        totalSpan(containers: columns, gap: gap, sizeKeyPath: \.cachedWidth)
    }

    func containerPosition(at index: Int, containers: [NiriContainer], gap: CGFloat, sizeKeyPath: KeyPath<NiriContainer, CGFloat>) -> CGFloat {
        var pos: CGFloat = 0
        for i in 0 ..< index {
            guard i < containers.count else { break }
            pos += containers[i][keyPath: sizeKeyPath] + gap
        }
        return pos
    }

    func totalSpan(containers: [NiriContainer], gap: CGFloat, sizeKeyPath: KeyPath<NiriContainer, CGFloat>) -> CGFloat {
        guard !containers.isEmpty else { return 0 }
        let sizeSum = containers.reduce(0) { $0 + $1[keyPath: sizeKeyPath] }
        let gapSum = CGFloat(max(0, containers.count - 1)) * gap
        return sizeSum + gapSum
    }

    func computeCenteredOffset(containerIndex: Int, containers: [NiriContainer], gap: CGFloat, viewportSpan: CGFloat, sizeKeyPath: KeyPath<NiriContainer, CGFloat>) -> CGFloat {
        guard !containers.isEmpty, containerIndex < containers.count else { return 0 }

        let total = totalSpan(containers: containers, gap: gap, sizeKeyPath: sizeKeyPath)
        let pos = containerPosition(at: containerIndex, containers: containers, gap: gap, sizeKeyPath: sizeKeyPath)

        if total <= viewportSpan {
            return -pos - (viewportSpan - total) / 2
        }

        let containerSize = containers[containerIndex][keyPath: sizeKeyPath]
        let centeredOffset = -(viewportSpan - containerSize) / 2

        guard let allowedOffsetRange = allowedOffsetRange(
            targetPos: pos,
            totalSpan: total,
            viewportSpan: viewportSpan
        ) else {
            return centeredOffset
        }

        return centeredOffset.clamped(to: allowedOffsetRange)
    }

    private func computeFitOffset(
        currentViewPos: CGFloat,
        viewSpan: CGFloat,
        targetPos: CGFloat,
        targetSpan: CGFloat,
        scale: CGFloat = 2.0
    ) -> CGFloat {
        let pixelEpsilon: CGFloat = 1.0 / max(scale, 1.0)

        if viewSpan <= targetSpan + pixelEpsilon {
            return 0
        }

        let targetEnd = targetPos + targetSpan

        // Padding is a preference for clipped targets, not a reason to move a
        // viewport when the focused container is already fully visible.
        if currentViewPos - pixelEpsilon <= targetPos
            && targetEnd <= currentViewPos + viewSpan + pixelEpsilon
        {
            return currentViewPos - targetPos
        }

        let exactStart = targetPos
        let exactEnd = targetEnd - viewSpan

        let distToStart = abs(currentViewPos - exactStart)
        let distToEnd = abs(currentViewPos - exactEnd)

        if distToStart <= distToEnd {
            return exactStart - targetPos
        } else {
            return exactEnd - targetPos
        }
    }

    func computeVisibleOffset(
        containerIndex: Int,
        containers: [NiriContainer],
        gap: CGFloat,
        viewportSpan: CGFloat,
        sizeKeyPath: KeyPath<NiriContainer, CGFloat>,
        currentViewStart: CGFloat,
        centerMode: CenterFocusedColumn,
        alwaysCenterSingleColumn: Bool = false,
        fromContainerIndex: Int? = nil,
        scale: CGFloat = 2.0
    ) -> CGFloat {
        guard !containers.isEmpty, containerIndex >= 0, containerIndex < containers.count else { return 0 }

        let effectiveCenterMode = (containers.count == 1 && alwaysCenterSingleColumn) ? .always : centerMode
        let currentViewEnd = currentViewStart + viewportSpan
        let pixelEpsilon: CGFloat = 1.0 / max(scale, 1.0)

        let targetPos = containerPosition(at: containerIndex, containers: containers, gap: gap, sizeKeyPath: sizeKeyPath)
        let targetSize = containers[containerIndex][keyPath: sizeKeyPath]
        let targetEnd = targetPos + targetSize

        func isFullyVisible(pos: CGFloat, end: CGFloat) -> Bool {
            currentViewStart - pixelEpsilon <= pos && end <= currentViewEnd + pixelEpsilon
        }

        var targetOffset: CGFloat

        switch effectiveCenterMode {
        case .always:
            targetOffset = computeCenteredOffset(
                containerIndex: containerIndex,
                containers: containers,
                gap: gap,
                viewportSpan: viewportSpan,
                sizeKeyPath: sizeKeyPath
            )

        case .onOverflow:
            if targetSize > viewportSpan {
                targetOffset = computeCenteredOffset(
                    containerIndex: containerIndex,
                    containers: containers,
                    gap: gap,
                    viewportSpan: viewportSpan,
                    sizeKeyPath: sizeKeyPath
                )
            } else if let fromIdx = fromContainerIndex,
                      fromIdx != containerIndex,
                      containers.indices.contains(fromIdx)
            {
                let sourcePos = containerPosition(at: fromIdx, containers: containers, gap: gap, sizeKeyPath: sizeKeyPath)
                let sourceSize = containers[fromIdx][keyPath: sizeKeyPath]
                let sourceEnd = sourcePos + sourceSize
                let pairStart = min(sourcePos, targetPos)
                let pairEnd = max(sourceEnd, targetEnd)
                let pairSpan = pairEnd - pairStart

                if (isFullyVisible(pos: sourcePos, end: sourceEnd) && isFullyVisible(pos: targetPos, end: targetEnd))
                    || pairSpan <= viewportSpan
                {
                    targetOffset = computeFitOffset(
                        currentViewPos: currentViewStart,
                        viewSpan: viewportSpan,
                        targetPos: targetPos,
                        targetSpan: targetSize,
                        scale: scale
                    )
                } else {
                    targetOffset = computeCenteredOffset(
                        containerIndex: containerIndex,
                        containers: containers,
                        gap: gap,
                        viewportSpan: viewportSpan,
                        sizeKeyPath: sizeKeyPath
                    )
                }
            } else {
                targetOffset = computeFitOffset(
                    currentViewPos: currentViewStart,
                    viewSpan: viewportSpan,
                    targetPos: targetPos,
                    targetSpan: targetSize,
                    scale: scale
                )
            }

        case .never:
            targetOffset = computeFitOffset(
                currentViewPos: currentViewStart,
                viewSpan: viewportSpan,
                targetPos: targetPos,
                targetSpan: targetSize,
                scale: scale
            )
        }

        let total = totalSpan(containers: containers, gap: gap, sizeKeyPath: sizeKeyPath)
        if let allowedOffsetRange = allowedOffsetRange(
            targetPos: targetPos,
            totalSpan: total,
            viewportSpan: viewportSpan
        ) {
            targetOffset = targetOffset.clamped(to: allowedOffsetRange)
        }

        return targetOffset
    }

    func computeCenteredOffset(
        columnIndex: Int,
        columns: [NiriContainer],
        gap: CGFloat,
        viewportWidth: CGFloat
    ) -> CGFloat {
        computeCenteredOffset(containerIndex: columnIndex, containers: columns, gap: gap, viewportSpan: viewportWidth, sizeKeyPath: \.cachedWidth)
    }

    func computeVisibleOffset(
        columnIndex: Int,
        columns: [NiriContainer],
        gap: CGFloat,
        viewportWidth: CGFloat,
        currentOffset: CGFloat,
        centerMode: CenterFocusedColumn,
        alwaysCenterSingleColumn: Bool = false,
        fromColumnIndex: Int? = nil,
        scale: CGFloat = 2.0
    ) -> CGFloat {
        let colX = columnX(at: columnIndex, columns: columns, gap: gap)
        return computeVisibleOffset(
            containerIndex: columnIndex,
            containers: columns,
            gap: gap,
            viewportSpan: viewportWidth,
            sizeKeyPath: \.cachedWidth,
            currentViewStart: colX + currentOffset,
            centerMode: centerMode,
            alwaysCenterSingleColumn: alwaysCenterSingleColumn,
            fromContainerIndex: fromColumnIndex,
            scale: scale
        )
    }
}
