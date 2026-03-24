import AppKit
import Foundation

@MainActor
final class MouseWarpHandler: NSObject {
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
                MouseWarpHandler._instance?.receiveTapMouseWarpMoved(at: screenLocation)
            }

            return Unmanaged.passUnretained(event)
        }

        state.eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
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
        state.pendingWarpEvents.clear()
        state.debugCounters = .init()
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

        // Find which monitor the cursor is currently inside
        guard let currentMonitor = monitors.first(where: { $0.frame.contains(location) }) else {
            // Off-screen: clamp back to last known monitor
            spatialClampToMonitor(location: location, margin: margin)
            return
        }

        // Cross-monitor detection: cursor jumped to a different monitor than
        // the one we last tracked — clamp it back to the previous monitor.
        if let lastId = state.lastMonitorId, lastId != currentMonitor.id {
            spatialClampToMonitor(location: location, margin: margin)
            return
        }

        state.lastMonitorId = currentMonitor.id

        // Find the spatial entry matching this monitor
        guard let entry = layoutEntries.first(where: {
            $0.displayId == currentMonitor.displayId && $0.monitorName == currentMonitor.name
        }) else { return }

        let frame = currentMonitor.frame

        // Check all 4 edges for margin trigger zone and attempt spatial warp.
        // AppKit space: .left = minX, .right = maxX, .bottom = minY, .top = maxY.
        if location.x <= frame.minX + margin {
            spatialWarpToAdjacentMonitor(
                from: entry, edge: .left, position: location.y,
                location: location, layout: layout, monitors: monitors, margin: margin
            )
        } else if location.x >= frame.maxX - margin {
            spatialWarpToAdjacentMonitor(
                from: entry, edge: .right, position: location.y,
                location: location, layout: layout, monitors: monitors, margin: margin
            )
        } else if location.y <= frame.minY + margin {
            spatialWarpToAdjacentMonitor(
                from: entry, edge: .bottom, position: location.x,
                location: location, layout: layout, monitors: monitors, margin: margin
            )
        } else if location.y >= frame.maxY - margin {
            spatialWarpToAdjacentMonitor(
                from: entry, edge: .top, position: location.x,
                location: location, layout: layout, monitors: monitors, margin: margin
            )
        }
    }

    // MARK: - Spatial warp helpers

    /// Attempt to warp cursor to the adjacent monitor on the given edge.
    /// If no adjacent monitor exists, this is a no-op (macOS constrains the cursor at physical edges).
    private func spatialWarpToAdjacentMonitor(
        from entry: SpatialMonitorEntry,
        edge: SpatialMonitorLayout.Edge,
        position: CGFloat,
        location: CGPoint,
        layout: SpatialMonitorLayout,
        monitors: [Monitor],
        margin: CGFloat
    ) {
        guard let target = layout.adjacentMonitor(from: entry, edge: edge, atPosition: position) else {
            return
        }
        guard let overlapRange = layout.overlapRange(from: entry, to: target, edge: edge) else {
            return
        }

        // Compute ratio of cursor position within the source's overlap range
        let rangeLength = overlapRange.upperBound - overlapRange.lowerBound
        let ratio: CGFloat
        if rangeLength > 0 {
            ratio = min(max((position - overlapRange.lowerBound) / rangeLength, 0), 1)
        } else {
            ratio = 0.5
        }

        // Map ratio to the target's overlap range for the perpendicular coordinate
        let targetRange = layout.overlapRange(from: target, to: entry, edge: oppositeEdge(edge))
        let targetRangeActual = targetRange ?? overlapRange
        let targetLength = targetRangeActual.upperBound - targetRangeActual.lowerBound
        let mappedPosition = targetRangeActual.lowerBound + (ratio * targetLength)

        // Compute landing point on the target monitor
        let targetFrame = target.frame
        let inset = margin + 1
        var landingX: CGFloat
        var landingY: CGFloat

        switch edge {
        case .left:
            // Warping left → landing on target's right edge
            landingX = targetFrame.maxX - inset
            landingY = mappedPosition
        case .right:
            // Warping right → landing on target's left edge
            landingX = targetFrame.minX + inset
            landingY = mappedPosition
        case .bottom:
            // Warping down → landing on target's top edge
            landingX = mappedPosition
            landingY = targetFrame.maxY - inset
        case .top:
            // Warping up → landing on target's bottom edge
            landingX = mappedPosition
            landingY = targetFrame.minY + inset
        }

        // Clamp landing within target frame (inset by margin + 1 on all sides)
        landingX = min(max(landingX, targetFrame.minX + inset), targetFrame.maxX - inset)
        landingY = min(max(landingY, targetFrame.minY + inset), targetFrame.maxY - inset)

        let destination = CGPoint(x: landingX, y: landingY)

        // Find the target Monitor object to update lastMonitorId
        let targetMonitor = monitors.first(where: {
            $0.displayId == target.displayId && $0.name == target.monitorName
        })

        state.isWarping = true
        state.lastMonitorId = targetMonitor?.id
        let warpPoint = ScreenCoordinateSpace.toWindowServer(point: destination)
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
