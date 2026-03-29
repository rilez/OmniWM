import AppKit
import Foundation

@MainActor
final class MouseWarpHandler: NSObject {
    /// Cached bounds for the active event tap clamp. Updated when lastMonitorId changes.
    /// Contains the current monitor frame and all spatially-adjacent monitor frames.
    /// Any cursor position outside these frames gets clamped before delivery.
    struct WarpBounds {
        let currentFrame: CGRect
        let allowedFrames: [CGRect]

        func shouldClamp(_ point: CGPoint) -> Bool {
            !allowedFrames.contains { $0.contains(point) }
        }

        func clamped(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(point.x, currentFrame.minX + 1), currentFrame.maxX - 1),
                y: min(max(point.y, currentFrame.minY + 1), currentFrame.maxY - 1)
            )
        }
    }

    struct State {
        struct PendingWarpEvents {
            var pendingLocation: CGPoint?
            var drainScheduled = false

            var hasPendingEvents: Bool {
                pendingLocation != nil
            }

            mutating func clear() {
                pendingLocation = nil
                drainScheduled = false
            }
        }

        struct DebugCounters: Equatable {
            var queuedTransientEvents = 0
            var coalescedTransientEvents = 0
            var drainedTransientEvents = 0
            var drainRuns = 0
        }

        var eventTap: CFMachPort?
        var runLoopSource: CFRunLoopSource?
        var cooldownTimer: Timer?
        var isWarping = false
        var lastMonitorId: Monitor.ID?
        var warpBounds: WarpBounds?
        var pendingWarpEvents = PendingWarpEvents()
        var debugCounters = DebugCounters()
    }

    nonisolated(unsafe) static weak var _instance: MouseWarpHandler?
    static let cooldownSeconds: TimeInterval = 0.05

    weak var controller: WMController?
    var state = State()
    var warpCursor: (CGPoint) -> Void = { CGWarpMouseCursorPosition($0) }
    var postMouseMovedEvent: (CGPoint) -> Void = { point in
        if let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            moveEvent.post(tap: .cghidEventTap)
        }
    }

    init(controller: WMController) {
        self.controller = controller
        super.init()
    }

    func setup() {
        guard state.eventTap == nil else { return }

        if let source = CGEventSource(stateID: .combinedSessionState) {
            source.localEventsSuppressionInterval = 0.0
        }

        MouseWarpHandler._instance = self

        let eventMask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = MouseWarpHandler._instance?.state.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            let location = event.location
            let screenLocation = ScreenCoordinateSpace.toAppKit(point: location)
            precondition(Thread.isMainThread, "Mouse warp taps are expected on the main run loop")

            MainActor.assumeIsolated {
                guard let instance = MouseWarpHandler._instance else { return }

                // Active clamp: if cursor would escape to a non-adjacent monitor,
                // rewrite the event position before it's delivered.
                if let bounds = instance.state.warpBounds,
                   !instance.state.isWarping,
                   bounds.shouldClamp(screenLocation) {
                    let clamped = bounds.clamped(screenLocation)
                    event.location = ScreenCoordinateSpace.toWindowServer(point: clamped)
                    instance.receiveTapMouseWarpMoved(at: clamped)
                    return
                }

                instance.receiveTapMouseWarpMoved(at: screenLocation)
            }

            return Unmanaged.passUnretained(event)
        }

        state.eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: nil
        )

        if let tap = state.eventTap {
            state.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let source = state.runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            }
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func cleanup() {
        if let source = state.runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            state.runLoopSource = nil
        }
        if let tap = state.eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            state.eventTap = nil
        }
        state.cooldownTimer?.invalidate()
        state.cooldownTimer = nil
        MouseWarpHandler._instance = nil
        state.isWarping = false
        state.lastMonitorId = nil
        state.warpBounds = nil
        state.pendingWarpEvents.clear()
        state.debugCounters = .init()
    }

    /// Rebuild the cached warp bounds for the given monitor. The bounds include
    /// the monitor's own frame plus the actual frames of all spatially-adjacent monitors.
    private func rebuildWarpBounds(for monitor: Monitor) {
        guard let controller else {
            state.warpBounds = nil
            return
        }
        let entries = controller.settings.spatialMonitorLayout
        guard let entry = spatialEntry(for: monitor, in: entries) else {
            state.warpBounds = nil
            return
        }
        let layout = SpatialMonitorLayout(entries: entries)
        let monitors = controller.workspaceManager.monitors

        var allowed = [monitor.frame]
        for edge in [SpatialMonitorLayout.Edge.left, .right, .top, .bottom] {
            let probePositions: [CGFloat]
            switch edge {
            case .left, .right:
                probePositions = [entry.frame.minY + 1, entry.frame.midY, entry.frame.maxY - 1]
            case .top, .bottom:
                probePositions = [entry.frame.minX + 1, entry.frame.midX, entry.frame.maxX - 1]
            }
            for pos in probePositions {
                if let neighbor = layout.adjacentMonitor(from: entry, edge: edge, atPosition: pos),
                   let neighborMonitor = monitors.first(where: {
                       $0.displayId == neighbor.displayId && $0.name == neighbor.monitorName
                   }),
                   !allowed.contains(where: { $0 == neighborMonitor.frame }) {
                    allowed.append(neighborMonitor.frame)
                }
            }
        }
        state.warpBounds = WarpBounds(currentFrame: monitor.frame, allowedFrames: allowed)
    }

    func flushPendingWarpEventsForTests() {
        flushPendingWarpEvents()
    }

    func mouseWarpDebugSnapshot() -> State.DebugCounters {
        state.debugCounters
    }

    func resetDebugStateForTests() {
        state.debugCounters = .init()
        state.pendingWarpEvents.clear()
    }

    func receiveTapMouseWarpMoved(at location: CGPoint) {
        enqueuePendingWarpMove(at: location)
    }

    private func handleMouseWarpMoved(at location: CGPoint) {
        guard let controller else { return }
        guard !state.isWarping else { return }
        guard controller.isEnabled else { return }

        let monitors = controller.workspaceManager.monitors
        guard monitors.count > 1 else { return }

        let layoutEntries = controller.settings.spatialMonitorLayout
        guard !layoutEntries.isEmpty else { return }
        let layout = SpatialMonitorLayout(entries: layoutEntries)
        let margin = CGFloat(controller.settings.mouseWarpMargin)

        guard let currentMonitor = monitors.first(where: { $0.frame.contains(location) }) else {
            spatialClampToMonitor(location: location, margin: margin)
            return
        }

        // Cross-monitor: cursor appeared on a different monitor than last tracked.
        // Find the connecting edge via the spatial layout and warp proportionally.
        if let lastId = state.lastMonitorId, lastId != currentMonitor.id {
            guard let lastMonitor = monitors.first(where: { $0.id == lastId }),
                  let lastEntry = spatialEntry(for: lastMonitor, in: layoutEntries),
                  let currentEntry = spatialEntry(for: currentMonitor, in: layoutEntries) else {
                spatialClampToMonitor(location: location, margin: margin)
                return
            }

            // Find which edge of the last spatial entry connects to the current one.
            // Convert the actual cursor position to the spatial coordinate system
            // so the adjacency position check works correctly.
            for edge in [SpatialMonitorLayout.Edge.left, .right, .top, .bottom] {
                let spatialPos = actualToSpatial(
                    position: edge.isHorizontal ? location.y : location.x,
                    edge: edge, monitor: lastMonitor, entry: lastEntry
                )
                if let neighbor = layout.adjacentMonitor(from: lastEntry, edge: edge, atPosition: spatialPos),
                   neighbor.displayId == currentEntry.displayId,
                   neighbor.monitorName == currentEntry.monitorName {
                    warpToAdjacentMonitor(
                        sourceEntry: lastEntry, sourceMonitor: lastMonitor,
                        targetEntry: neighbor, edge: edge,
                        cursorPosition: edge.isHorizontal ? location.y : location.x,
                        layout: layout, monitors: monitors, margin: margin
                    )
                    return
                }
            }

            spatialClampToMonitor(location: location, margin: margin)
            return
        }

        state.lastMonitorId = currentMonitor.id
        rebuildWarpBounds(for: currentMonitor)

        guard let entry = spatialEntry(for: currentMonitor, in: layoutEntries) else { return }

        let frame = currentMonitor.frame

        // Edge margin trigger zone check.
        // Convert cursor position to spatial coordinates for the adjacency lookup,
        // then use actual monitor frames for the landing computation.
        if location.x <= frame.minX + margin {
            let spatialY = actualToSpatial(position: location.y, edge: .left, monitor: currentMonitor, entry: entry)
            warpViaEdge(entry: entry, monitor: currentMonitor, edge: .left,
                        spatialPosition: spatialY, cursorPosition: location.y,
                        layout: layout, monitors: monitors, margin: margin)
        } else if location.x >= frame.maxX - margin {
            let spatialY = actualToSpatial(position: location.y, edge: .right, monitor: currentMonitor, entry: entry)
            warpViaEdge(entry: entry, monitor: currentMonitor, edge: .right,
                        spatialPosition: spatialY, cursorPosition: location.y,
                        layout: layout, monitors: monitors, margin: margin)
        } else if location.y <= frame.minY + margin {
            let spatialX = actualToSpatial(position: location.x, edge: .bottom, monitor: currentMonitor, entry: entry)
            warpViaEdge(entry: entry, monitor: currentMonitor, edge: .bottom,
                        spatialPosition: spatialX, cursorPosition: location.x,
                        layout: layout, monitors: monitors, margin: margin)
        } else if location.y >= frame.maxY - margin {
            let spatialX = actualToSpatial(position: location.x, edge: .top, monitor: currentMonitor, entry: entry)
            warpViaEdge(entry: entry, monitor: currentMonitor, edge: .top,
                        spatialPosition: spatialX, cursorPosition: location.x,
                        layout: layout, monitors: monitors, margin: margin)
        }
    }

    // MARK: - Spatial warp helpers

    private func spatialEntry(for monitor: Monitor, in entries: [SpatialMonitorEntry]) -> SpatialMonitorEntry? {
        entries.first { $0.displayId == monitor.displayId && $0.monitorName == monitor.name }
    }

    /// Convert a cursor position (actual screen coords) to the spatial layout coordinate system.
    /// For horizontal edges (left/right), position is Y; for vertical edges (top/bottom), position is X.
    private func actualToSpatial(
        position: CGFloat,
        edge: SpatialMonitorLayout.Edge,
        monitor: Monitor,
        entry: SpatialMonitorEntry
    ) -> CGFloat {
        if edge.isHorizontal {
            let h = monitor.frame.height
            guard h > 0 else { return entry.frame.minY }
            return entry.frame.minY + (position - monitor.frame.minY) / h * entry.size.height
        } else {
            let w = monitor.frame.width
            guard w > 0 else { return entry.frame.minX }
            return entry.frame.minX + (position - monitor.frame.minX) / w * entry.size.width
        }
    }

    /// Convert a spatial layout position back to actual screen coordinates on a target monitor.
    private func spatialToActual(
        position: CGFloat,
        edge: SpatialMonitorLayout.Edge,
        monitor: Monitor,
        entry: SpatialMonitorEntry
    ) -> CGFloat {
        if edge.isHorizontal {
            let h = entry.size.height
            guard h > 0 else { return monitor.frame.minY }
            return monitor.frame.minY + (position - entry.frame.minY) / h * monitor.frame.height
        } else {
            let w = entry.size.width
            guard w > 0 else { return monitor.frame.minX }
            return monitor.frame.minX + (position - entry.frame.minX) / w * monitor.frame.width
        }
    }

    /// Find adjacent monitor and warp. Used by the edge-trigger path.
    private func warpViaEdge(
        entry: SpatialMonitorEntry,
        monitor: Monitor,
        edge: SpatialMonitorLayout.Edge,
        spatialPosition: CGFloat,
        cursorPosition: CGFloat,
        layout: SpatialMonitorLayout,
        monitors: [Monitor],
        margin: CGFloat
    ) {
        guard let targetEntry = layout.adjacentMonitor(from: entry, edge: edge, atPosition: spatialPosition) else {
            return
        }
        warpToAdjacentMonitor(
            sourceEntry: entry, sourceMonitor: monitor,
            targetEntry: targetEntry, edge: edge,
            cursorPosition: cursorPosition,
            layout: layout, monitors: monitors, margin: margin
        )
    }

    /// Core warp: compute proportional landing on the target monitor using actual frames.
    /// The spatial layout is used only for overlap range computation (determining which
    /// portion of the shared edge connects the two monitors).
    private func warpToAdjacentMonitor(
        sourceEntry: SpatialMonitorEntry,
        sourceMonitor: Monitor,
        targetEntry: SpatialMonitorEntry,
        edge: SpatialMonitorLayout.Edge,
        cursorPosition: CGFloat,
        layout: SpatialMonitorLayout,
        monitors: [Monitor],
        margin: CGFloat
    ) {
        guard let targetMonitor = monitors.first(where: {
            $0.displayId == targetEntry.displayId && $0.name == targetEntry.monitorName
        }) else { return }

        // Compute overlap ranges in spatial coordinates
        guard let srcOverlap = layout.overlapRange(from: sourceEntry, to: targetEntry, edge: edge) else { return }
        let dstOverlap = layout.overlapRange(from: targetEntry, to: sourceEntry, edge: oppositeEdge(edge)) ?? srcOverlap

        // Convert cursor position to spatial coords, compute ratio within source overlap
        let spatialPos = actualToSpatial(position: cursorPosition, edge: edge, monitor: sourceMonitor, entry: sourceEntry)
        let srcLen = srcOverlap.upperBound - srcOverlap.lowerBound
        let ratio: CGFloat = srcLen > 0 ? min(max((spatialPos - srcOverlap.lowerBound) / srcLen, 0), 1) : 0.5

        // Map ratio to target overlap in spatial coords, then convert to actual coords
        let dstLen = dstOverlap.upperBound - dstOverlap.lowerBound
        let targetSpatialPos = dstOverlap.lowerBound + ratio * dstLen
        let mappedPosition = spatialToActual(position: targetSpatialPos, edge: edge, monitor: targetMonitor, entry: targetEntry)

        // Compute landing point on the actual target monitor frame
        let targetFrame = targetMonitor.frame
        let inset = margin + 1
        var landingX: CGFloat
        var landingY: CGFloat

        switch edge {
        case .left:
            landingX = targetFrame.maxX - inset
            landingY = mappedPosition
        case .right:
            landingX = targetFrame.minX + inset
            landingY = mappedPosition
        case .bottom:
            landingX = mappedPosition
            landingY = targetFrame.maxY - inset
        case .top:
            landingX = mappedPosition
            landingY = targetFrame.minY + inset
        }

        landingX = min(max(landingX, targetFrame.minX + inset), targetFrame.maxX - inset)
        landingY = min(max(landingY, targetFrame.minY + inset), targetFrame.maxY - inset)

        state.isWarping = true
        state.lastMonitorId = targetMonitor.id
        rebuildWarpBounds(for: targetMonitor)
        let warpPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(x: landingX, y: landingY))
        postMouseMovedEvent(warpPoint)
        scheduleWarpCooldownReset()
    }

    /// Clamp cursor back to the last known monitor. Used when the cursor
    /// escapes to a different monitor or ends up off-screen.
    private func spatialClampToMonitor(location: CGPoint, margin: CGFloat) {
        guard let controller,
              let lastId = state.lastMonitorId,
              let lastMonitor = controller.workspaceManager.monitor(byId: lastId) else {
            return
        }

        let frame = lastMonitor.frame
        let inset = margin + 1
        let clampedX = min(max(location.x, frame.minX + inset), frame.maxX - inset)
        let clampedY = min(max(location.y, frame.minY + inset), frame.maxY - inset)
        let clamped = CGPoint(x: clampedX, y: clampedY)

        guard clamped != location else { return }

        state.isWarping = true
        let warpPoint = ScreenCoordinateSpace.toWindowServer(point: clamped)
        warpCursor(warpPoint)
        scheduleWarpCooldownReset()
    }

    private func oppositeEdge(_ edge: SpatialMonitorLayout.Edge) -> SpatialMonitorLayout.Edge {
        switch edge {
        case .left: return .right
        case .right: return .left
        case .top: return .bottom
        case .bottom: return .top
        }
    }

    private func scheduleWarpCooldownReset() {
        state.cooldownTimer?.invalidate()
        state.cooldownTimer = Timer(
            fireAt: Date(timeIntervalSinceNow: MouseWarpHandler.cooldownSeconds),
            interval: 0,
            target: self,
            selector: #selector(handleWarpCooldownTimer(_:)),
            userInfo: nil,
            repeats: false
        )

        if let cooldownTimer = state.cooldownTimer {
            RunLoop.main.add(cooldownTimer, forMode: .common)
        }
    }

    @objc private func handleWarpCooldownTimer(_ timer: Timer) {
        timer.invalidate()
        if state.cooldownTimer === timer {
            state.cooldownTimer = nil
        }
        state.isWarping = false
    }

    private func schedulePendingWarpDrainIfNeeded() {
        guard !state.pendingWarpEvents.drainScheduled else { return }
        state.pendingWarpEvents.drainScheduled = true

        let mainRunLoop = CFRunLoopGetMain()
        CFRunLoopPerformBlock(mainRunLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.flushPendingWarpEvents()
            }
        }
        CFRunLoopWakeUp(mainRunLoop)
    }

    private func enqueuePendingWarpMove(at location: CGPoint) {
        state.debugCounters.queuedTransientEvents += 1
        let didCoalesce = state.pendingWarpEvents.pendingLocation != nil
        state.pendingWarpEvents.pendingLocation = location
        if didCoalesce {
            state.debugCounters.coalescedTransientEvents += 1
        }
        schedulePendingWarpDrainIfNeeded()
    }

    private func flushPendingWarpEvents() {
        guard state.pendingWarpEvents.hasPendingEvents,
              let pendingLocation = state.pendingWarpEvents.pendingLocation else {
            state.pendingWarpEvents.clear()
            return
        }

        state.pendingWarpEvents.clear()
        state.debugCounters.drainRuns += 1
        state.debugCounters.drainedTransientEvents += 1
        handleMouseWarpMoved(at: pendingLocation)
    }
}
