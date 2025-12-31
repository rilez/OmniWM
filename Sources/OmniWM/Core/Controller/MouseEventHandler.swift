import AppKit
import Foundation

@MainActor
final class MouseEventHandler {
    private weak var controller: WMController?

    private var mouseMovedMonitor: Any?
    private var mouseMovedLocalMonitor: Any?
    private var mouseDownMonitor: Any?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?
    private var scrollWheelMonitor: Any?
    private var gestureMonitor: Any?
    private var currentHoveredEdges: ResizeEdge = []
    private var isResizing: Bool = false
    private var isMoving: Bool = false
    private var gesturePhase: GesturePhase = .idle
    private var gestureStartX: CGFloat = 0.0
    private var gestureStartY: CGFloat = 0.0
    private var gestureLastDeltaX: CGFloat = 0.0

    private enum GesturePhase {
        case idle
        case armed
        case committed
    }
    private var lastFocusFollowsMouseTime: Date = .distantPast
    private var lastFocusFollowsMouseHandle: WindowHandle?
    private let focusFollowsMouseDebounce: TimeInterval = 0.1

    init(controller: WMController) {
        self.controller = controller
    }

    func setup() {
        mouseMovedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseMoved()
            }
        }

        mouseMovedLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseMoved()
            }
            return event
        }

        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseDown()
            }
        }

        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseDragged()
            }
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseUp()
            }
        }

        scrollWheelMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            Task { @MainActor in
                self?.handleScrollWheel(event)
            }
        }

        gestureMonitor = NSEvent.addGlobalMonitorForEvents(matching: .gesture) { [weak self] event in
            Task { @MainActor in
                self?.handleGestureEvent(event)
            }
        }
    }

    func cleanup() {
        if let monitor = mouseMovedMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMovedMonitor = nil
        }
        if let monitor = mouseMovedLocalMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMovedLocalMonitor = nil
        }
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
        if let monitor = mouseDraggedMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDraggedMonitor = nil
        }
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            mouseUpMonitor = nil
        }
        if let monitor = scrollWheelMonitor {
            NSEvent.removeMonitor(monitor)
            scrollWheelMonitor = nil
        }
        if let monitor = gestureMonitor {
            NSEvent.removeMonitor(monitor)
            gestureMonitor = nil
        }
        currentHoveredEdges = []
        isResizing = false
        gesturePhase = .idle
    }

    private func handleMouseMoved() {
        guard let controller else { return }
        guard controller.isEnabled else {
            if !currentHoveredEdges.isEmpty {
                NSCursor.arrow.set()
                currentHoveredEdges = []
            }
            return
        }

        let location = NSEvent.mouseLocation

        if controller.internalFocusFollowsMouseEnabled, !isResizing {
            handleFocusFollowsMouse(at: location)
        }

        guard !isResizing else { return }

        guard let engine = controller.internalNiriEngine,
              let wsId = controller.activeWorkspace()?.id
        else {
            if !currentHoveredEdges.isEmpty {
                NSCursor.arrow.set()
                currentHoveredEdges = []
            }
            return
        }

        if let hitResult = engine.hitTestResize(point: location, in: wsId) {
            if hitResult.edges != currentHoveredEdges {
                hitResult.edges.cursor.set()
                currentHoveredEdges = hitResult.edges
            }
        } else {
            if !currentHoveredEdges.isEmpty {
                NSCursor.arrow.set()
                currentHoveredEdges = []
            }
        }
    }

    private func handleFocusFollowsMouse(at location: CGPoint) {
        guard let controller else { return }
        guard !controller.internalIsNonManagedFocusActive, !controller.internalIsAppFullscreenActive else {
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastFocusFollowsMouseTime) >= focusFollowsMouseDebounce else {
            return
        }

        guard let engine = controller.internalNiriEngine,
              let wsId = controller.activeWorkspace()?.id
        else {
            return
        }

        if let tiledWindow = engine.hitTestTiled(point: location, in: wsId) {
            let handle = tiledWindow.handle
            if handle != lastFocusFollowsMouseHandle, handle != controller.internalFocusedHandle {
                lastFocusFollowsMouseTime = now
                lastFocusFollowsMouseHandle = handle
                var state = controller.internalWorkspaceManager.niriViewportState(for: wsId)
                state.selectedNodeId = tiledWindow.id
                controller.internalWorkspaceManager.updateNiriViewportState(state, for: wsId)
                engine.updateFocusTimestamp(for: tiledWindow.id)
                controller.internalFocusedHandle = handle
                controller.internalLastFocusedByWorkspace[wsId] = handle
                controller.focusWindow(handle)
            }
            return
        }
    }

    private func handleMouseDown() {
        guard let controller else { return }
        guard controller.isEnabled else { return }

        guard let engine = controller.internalNiriEngine,
              let wsId = controller.activeWorkspace()?.id
        else {
            return
        }

        let location = NSEvent.mouseLocation
        let modifiers = NSEvent.modifierFlags

        if modifiers.contains(.option) {
            if let tiledWindow = engine.hitTestTiled(point: location, in: wsId) {
                if engine.interactiveMoveBegin(
                    windowId: tiledWindow.id,
                    windowHandle: tiledWindow.handle,
                    startLocation: location,
                    in: wsId
                ) {
                    isMoving = true
                    NSCursor.closedHand.set()
                    return
                }
            }
        }

        guard !currentHoveredEdges.isEmpty else { return }

        if let hitResult = engine.hitTestResize(point: location, in: wsId) {
            if engine.interactiveResizeBegin(
                windowId: hitResult.nodeId,
                edges: hitResult.edges,
                startLocation: location,
                in: wsId
            ) {
                isResizing = true
                controller.internalLayoutRefreshController?.invalidateLayout()

                hitResult.edges.cursor.set()
            }
        }
    }

    private func handleMouseDragged() {
        guard let controller else { return }
        guard controller.isEnabled else { return }

        let location = NSEvent.mouseLocation

        if isMoving {
            guard let engine = controller.internalNiriEngine,
                  let wsId = controller.activeWorkspace()?.id
            else {
                return
            }

            _ = engine.interactiveMoveUpdate(currentLocation: location, in: wsId)
            return
        }

        guard isResizing else { return }

        guard let engine = controller.internalNiriEngine,
              let monitor = controller.monitorForInteraction()
        else {
            return
        }

        let gaps = LayoutGaps(
            horizontal: CGFloat(controller.internalWorkspaceManager.gaps),
            vertical: CGFloat(controller.internalWorkspaceManager.gaps),
            outer: controller.internalWorkspaceManager.outerGaps
        )
        let insetFrame = controller.insetWorkingFrame(from: monitor.visibleFrame)

        if engine.interactiveResizeUpdate(
            currentLocation: location,
            monitorFrame: insetFrame,
            gaps: gaps
        ) {
            controller.internalLayoutRefreshController?.executeLayoutRefreshImmediate()
        }
    }

    private func handleMouseUp() {
        guard let controller else { return }
        let location = NSEvent.mouseLocation

        if isMoving {
            if let engine = controller.internalNiriEngine,
               let wsId = controller.activeWorkspace()?.id,
               let monitor = controller.internalWorkspaceManager.monitor(for: wsId)
            {
                var state = controller.internalWorkspaceManager.niriViewportState(for: wsId)
                let workingFrame = controller.insetWorkingFrame(from: monitor.visibleFrame)
                let gaps = CGFloat(controller.internalWorkspaceManager.gaps)
                if engine.interactiveMoveEnd(at: location, in: wsId, state: &state, workingFrame: workingFrame, gaps: gaps) {
                    controller.internalWorkspaceManager.updateNiriViewportState(state, for: wsId)
                    controller.internalLayoutRefreshController?.executeLayoutRefreshImmediate()
                }
            }

            isMoving = false
            NSCursor.arrow.set()
            return
        }

        guard isResizing else { return }

        if let engine = controller.internalNiriEngine {
            engine.interactiveResizeEnd()
        }

        isResizing = false

        if let engine = controller.internalNiriEngine,
           let wsId = controller.activeWorkspace()?.id,
           let hitResult = engine.hitTestResize(point: location, in: wsId)
        {
            hitResult.edges.cursor.set()
            currentHoveredEdges = hitResult.edges
        } else {
            NSCursor.arrow.set()
            currentHoveredEdges = []
        }
    }

    private func handleScrollWheel(_ event: NSEvent) {
        guard let controller else { return }
        guard controller.isEnabled, controller.internalSettings.scrollGestureEnabled else { return }
        guard !isResizing, !isMoving else { return }
        guard let engine = controller.internalNiriEngine, let wsId = controller.activeWorkspace()?.id else { return }

        let isTrackpad = event.momentumPhase != [] || event.phase != []
        if isTrackpad {
            return
        }

        guard event.modifierFlags.contains(controller.internalSettings.scrollModifierKey.eventModifierFlag) else {
            return
        }

        let deltaX: CGFloat
        if event.modifierFlags.contains(.shift) {
            deltaX = event.scrollingDeltaX
        } else {
            deltaX = -event.scrollingDeltaY
        }

        guard abs(deltaX) > 0.5 else { return }

        let timestamp = CACurrentMediaTime()

        var state = controller.internalWorkspaceManager.niriViewportState(for: wsId)

        if state.viewOffsetPixels.isAnimating {
            state.cancelAnimation()
        }

        if !state.viewOffsetPixels.isGesture {
            state.beginGesture(isTrackpad: false)
        }

        guard let monitor = controller.monitorForInteraction() else { return }
        let insetFrame = controller.insetWorkingFrame(from: monitor.visibleFrame)
        let viewportWidth = insetFrame.width
        let gap = CGFloat(controller.internalWorkspaceManager.gaps)
        let columns = engine.columns(in: wsId)

        let sensitivity = CGFloat(controller.internalSettings.scrollSensitivity)
        let adjustedDelta = deltaX * sensitivity

        var targetWindowHandle: WindowHandle?
        if let steps = state.updateGesture(
            deltaPixels: adjustedDelta,
            timestamp: timestamp,
            columns: columns,
            gap: gap,
            viewportWidth: viewportWidth
        ) {
            if let currentId = state.selectedNodeId,
               let currentNode = engine.findNode(by: currentId),
               let newNode = engine.moveSelectionByColumns(
                   steps: steps,
                   currentSelection: currentNode,
                   in: wsId
               )
            {
                state.selectedNodeId = newNode.id

                if let windowNode = newNode as? NiriWindow {
                    controller.internalFocusedHandle = windowNode.handle
                    engine.updateFocusTimestamp(for: windowNode.id)
                    targetWindowHandle = windowNode.handle
                }
            }
        }

        controller.internalWorkspaceManager.updateNiriViewportState(state, for: wsId)
        controller.internalLayoutRefreshController?.executeLayoutRefreshImmediate()

        if let handle = targetWindowHandle {
            controller.focusWindow(handle)
        }
    }

    private func handleGestureEvent(_ event: NSEvent) {
        guard let controller else { return }
        guard controller.isEnabled, controller.internalSettings.scrollGestureEnabled else { return }
        guard !isResizing, !isMoving else { return }
        guard let engine = controller.internalNiriEngine, let wsId = controller.activeWorkspace()?.id else { return }

        let requiredFingers = controller.internalSettings.gestureFingerCount.rawValue
        let invertDirection = controller.internalSettings.gestureInvertDirection

        let phase = event.phase
        if phase == .ended || phase == .cancelled {
            if gesturePhase == .committed {
                guard let monitor = controller.monitorForInteraction() else {
                    resetGestureState()
                    return
                }
                let insetFrame = controller.insetWorkingFrame(from: monitor.visibleFrame)
                let columns = engine.columns(in: wsId)
                let gap = CGFloat(controller.internalWorkspaceManager.gaps)

                var endState = controller.internalWorkspaceManager.niriViewportState(for: wsId)
                endState.endGesture(
                    columns: columns,
                    gap: gap,
                    viewportWidth: insetFrame.width
                )
                controller.internalWorkspaceManager.updateNiriViewportState(endState, for: wsId)
                controller.internalLayoutRefreshController?.startScrollAnimation(for: wsId)
            }
            resetGestureState()
            return
        }

        if phase == .began {
            resetGestureState()
        }

        let touches = event.allTouches()
        guard !touches.isEmpty else {
            resetGestureState()
            return
        }

        var sumX: CGFloat = 0.0
        var sumY: CGFloat = 0.0
        var touchCount = 0
        var activeCount = 0
        var tooManyTouches = false

        for touch in touches {
            let touchPhase = touch.phase
            if touchPhase == .stationary {
                continue
            }

            touchCount += 1
            if touchCount > requiredFingers {
                tooManyTouches = true
                break
            }

            let isEnded = touchPhase == .ended || touchPhase == .cancelled
            if !isEnded {
                let pos = touch.normalizedPosition
                sumX += pos.x
                sumY += pos.y
                activeCount += 1
            }
        }

        if tooManyTouches || touchCount != requiredFingers || activeCount == 0 {
            resetGestureState()
            return
        }

        let avgX = sumX / CGFloat(activeCount)
        let avgY = sumY / CGFloat(activeCount)

        switch gesturePhase {
        case .idle:
            gestureStartX = avgX
            gestureStartY = avgY
            gestureLastDeltaX = 0.0
            gesturePhase = .armed

        case .armed, .committed:
            let dx = avgX - gestureStartX
            let currentDeltaX = dx
            let deltaNorm = currentDeltaX - gestureLastDeltaX
            gestureLastDeltaX = currentDeltaX

            var deltaUnits = deltaNorm * CGFloat(controller.internalSettings.scrollSensitivity) * 500.0
            if invertDirection {
                deltaUnits = -deltaUnits
            }

            if abs(deltaUnits) < 0.5 {
                gesturePhase = .committed
                return
            }

            gesturePhase = .committed

            var state = controller.internalWorkspaceManager.niriViewportState(for: wsId)

            if state.viewOffsetPixels.isAnimating {
                state.cancelAnimation()
            }

            if !state.viewOffsetPixels.isGesture {
                state.beginGesture(isTrackpad: true)
            }

            guard let monitor = controller.monitorForInteraction() else { return }
            let insetFrame = controller.insetWorkingFrame(from: monitor.visibleFrame)
            let viewportWidth = insetFrame.width
            let gap = CGFloat(controller.internalWorkspaceManager.gaps)
            let columns = engine.columns(in: wsId)

            let timestamp = CACurrentMediaTime()
            var targetWindowHandle: WindowHandle?
            if let steps = state.updateGesture(
                deltaPixels: deltaUnits,
                timestamp: timestamp,
                columns: columns,
                gap: gap,
                viewportWidth: viewportWidth
            ) {
                if let currentId = state.selectedNodeId,
                   let currentNode = engine.findNode(by: currentId),
                   let newNode = engine.moveSelectionByColumns(
                       steps: steps,
                       currentSelection: currentNode,
                       in: wsId
                   )
                {
                    state.selectedNodeId = newNode.id

                    if let windowNode = newNode as? NiriWindow {
                        controller.internalFocusedHandle = windowNode.handle
                        engine.updateFocusTimestamp(for: windowNode.id)
                        targetWindowHandle = windowNode.handle
                    }
                }
            }

            controller.internalWorkspaceManager.updateNiriViewportState(state, for: wsId)
            controller.internalLayoutRefreshController?.executeLayoutRefreshImmediate()

            if let handle = targetWindowHandle {
                controller.focusWindow(handle)
            }
        }
    }

    private func resetGestureState() {
        gesturePhase = .idle
        gestureStartX = 0.0
        gestureStartY = 0.0
        gestureLastDeltaX = 0.0
    }
}
