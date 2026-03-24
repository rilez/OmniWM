import CoreGraphics
import Foundation
import Testing

@testable import OmniWM

// MARK: - Test helpers

private final class WarpEffectRecorder: @unchecked Sendable {
    var warpedPoints: [CGPoint] = []
    var postedPoints: [CGPoint] = []
}

private func makeSpatialWarpTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: "com.omniwm.spatial-warp.test.\(UUID().uuidString)")!
}

private func makeTestMonitor(
    displayId: CGDirectDisplayID,
    name: String,
    x: CGFloat,
    y: CGFloat = 0,
    width: CGFloat = 1920,
    height: CGFloat = 1080
) -> Monitor {
    let frame = CGRect(x: x, y: y, width: width, height: height)
    return Monitor(
        id: Monitor.ID(displayId: displayId),
        displayId: displayId,
        frame: frame,
        visibleFrame: frame,
        hasNotch: false,
        name: name
    )
}

private func makeTestEntry(
    name: String,
    displayId: CGDirectDisplayID,
    x: CGFloat,
    y: CGFloat = 0,
    width: CGFloat = 1920,
    height: CGFloat = 1080
) -> SpatialMonitorEntry {
    SpatialMonitorEntry(
        monitorName: name,
        displayId: displayId,
        origin: CGPoint(x: x, y: y),
        size: CGSize(width: width, height: height)
    )
}

@MainActor
private func makeSpatialWarpTestFixture(
    entries: [SpatialMonitorEntry],
    monitors: [Monitor],
    margin: Int = 2
) -> (
    controller: WMController,
    handler: MouseWarpHandler,
    recorder: WarpEffectRecorder
) {
    let settings = SettingsStore(defaults: makeSpatialWarpTestDefaults())
    settings.spatialMonitorLayout = entries
    settings.mouseWarpMargin = margin

    let operations = WindowFocusOperations(
        activateApp: { _ in },
        focusSpecificWindow: { _, _, _ in },
        raiseWindow: { _ in }
    )

    let controller = WMController(
        settings: settings,
        windowFocusOperations: operations
    )
    controller.workspaceManager.applyMonitorConfigurationChange(monitors)

    let recorder = WarpEffectRecorder()
    let handler = controller.mouseWarpHandler
    handler.warpCursor = { point in recorder.warpedPoints.append(point) }
    handler.postMouseMovedEvent = { point in recorder.postedPoints.append(point) }
    return (controller, handler, recorder)
}

// MARK: - Tests

@Suite struct SpatialMouseWarpTests {

    // MARK: Horizontal 2-monitor warps

    @Test @MainActor func horizontalWarpLeftToRight() {
        let leftEntry = makeTestEntry(name: "Left", displayId: 1, x: 0)
        let rightEntry = makeTestEntry(name: "Right", displayId: 2, x: 1920)
        let leftMonitor = makeTestMonitor(displayId: 1, name: "Left", x: 0)
        let rightMonitor = makeTestMonitor(displayId: 2, name: "Right", x: 1920)

        let fixture = makeSpatialWarpTestFixture(
            entries: [leftEntry, rightEntry],
            monitors: [leftMonitor, rightMonitor]
        )
        defer { fixture.handler.cleanup() }

        // Cursor at right edge of left monitor (within margin zone)
        let margin = CGFloat(fixture.controller.settings.mouseWarpMargin)
        let location = CGPoint(
            x: leftMonitor.frame.maxX - margin + 1,
            y: leftMonitor.frame.minY + 270
        )

        fixture.handler.resetDebugStateForTests()
        fixture.handler.receiveTapMouseWarpMoved(at: location)
        fixture.handler.flushPendingWarpEventsForTests()

        // Overlap range: 0...1080 (full height, same-size monitors)
        // Ratio: 270 / 1080 = 0.25, mapped = 270
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: rightMonitor.frame.minX + margin + 1,
            y: 270
        ))

        #expect(fixture.handler.state.lastMonitorId == rightMonitor.id)
        #expect(fixture.recorder.warpedPoints.isEmpty)
        #expect(fixture.recorder.postedPoints == [expectedPoint])
    }

    @Test @MainActor func horizontalWarpRightToLeft() {
        let leftEntry = makeTestEntry(name: "Left", displayId: 1, x: 0)
        let rightEntry = makeTestEntry(name: "Right", displayId: 2, x: 1920)
        let leftMonitor = makeTestMonitor(displayId: 1, name: "Left", x: 0)
        let rightMonitor = makeTestMonitor(displayId: 2, name: "Right", x: 1920)

        let fixture = makeSpatialWarpTestFixture(
            entries: [leftEntry, rightEntry],
            monitors: [leftMonitor, rightMonitor]
        )
        defer { fixture.handler.cleanup() }

        let margin = CGFloat(fixture.controller.settings.mouseWarpMargin)
        let location = CGPoint(
            x: rightMonitor.frame.minX + margin - 1,
            y: rightMonitor.frame.minY + 810
        )

        fixture.handler.resetDebugStateForTests()
        fixture.handler.receiveTapMouseWarpMoved(at: location)
        fixture.handler.flushPendingWarpEventsForTests()

        // Overlap range: 0...1080, ratio: 810/1080 = 0.75, mapped = 810
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: leftMonitor.frame.maxX - margin - 1,
            y: 810
        ))

        #expect(fixture.handler.state.lastMonitorId == leftMonitor.id)
        #expect(fixture.recorder.warpedPoints.isEmpty)
        #expect(fixture.recorder.postedPoints == [expectedPoint])
    }

    // MARK: Vertical 2-monitor warps

    @Test @MainActor func verticalWarpBottomToTop() {
        let bottomEntry = makeTestEntry(name: "Bottom", displayId: 1, x: 0, y: 0)
        let topEntry = makeTestEntry(name: "Top", displayId: 2, x: 0, y: 1080)
        let bottomMonitor = makeTestMonitor(displayId: 1, name: "Bottom", x: 0, y: 0)
        let topMonitor = makeTestMonitor(displayId: 2, name: "Top", x: 0, y: 1080)

        let fixture = makeSpatialWarpTestFixture(
            entries: [bottomEntry, topEntry],
            monitors: [bottomMonitor, topMonitor]
        )
        defer { fixture.handler.cleanup() }

        let margin = CGFloat(fixture.controller.settings.mouseWarpMargin)
        let location = CGPoint(
            x: bottomMonitor.frame.minX + 960,
            y: bottomMonitor.frame.maxY - margin + 1
        )

        fixture.handler.resetDebugStateForTests()
        fixture.handler.receiveTapMouseWarpMoved(at: location)
        fixture.handler.flushPendingWarpEventsForTests()

        // Overlap range on .top edge: X = 0...1920. Ratio: 960/1920 = 0.5, mapped = 960
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: 960,
            y: topMonitor.frame.minY + margin + 1
        ))

        #expect(fixture.handler.state.lastMonitorId == topMonitor.id)
        #expect(fixture.recorder.warpedPoints.isEmpty)
        #expect(fixture.recorder.postedPoints == [expectedPoint])
    }

    @Test @MainActor func verticalWarpTopToBottom() {
        let bottomEntry = makeTestEntry(name: "Bottom", displayId: 1, x: 0, y: 0)
        let topEntry = makeTestEntry(name: "Top", displayId: 2, x: 0, y: 1080)
        let bottomMonitor = makeTestMonitor(displayId: 1, name: "Bottom", x: 0, y: 0)
        let topMonitor = makeTestMonitor(displayId: 2, name: "Top", x: 0, y: 1080)

        let fixture = makeSpatialWarpTestFixture(
            entries: [bottomEntry, topEntry],
            monitors: [bottomMonitor, topMonitor]
        )
        defer { fixture.handler.cleanup() }

        let margin = CGFloat(fixture.controller.settings.mouseWarpMargin)
        let location = CGPoint(
            x: topMonitor.frame.minX + 480,
            y: topMonitor.frame.minY + margin - 1
        )

        fixture.handler.resetDebugStateForTests()
        fixture.handler.receiveTapMouseWarpMoved(at: location)
        fixture.handler.flushPendingWarpEventsForTests()

        // Overlap range on .bottom edge: X = 0...1920. Ratio: 480/1920 = 0.25, mapped = 480
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: 480,
            y: bottomMonitor.frame.maxY - margin - 1
        ))

        #expect(fixture.handler.state.lastMonitorId == bottomMonitor.id)
        #expect(fixture.recorder.warpedPoints.isEmpty)
        #expect(fixture.recorder.postedPoints == [expectedPoint])
    }

    // MARK: Non-adjacent edge — no warp

    @Test @MainActor func noWarpAtNonAdjacentEdge() {
        let leftEntry = makeTestEntry(name: "Left", displayId: 1, x: 0)
        let rightEntry = makeTestEntry(name: "Right", displayId: 2, x: 1920)
        let leftMonitor = makeTestMonitor(displayId: 1, name: "Left", x: 0)
        let rightMonitor = makeTestMonitor(displayId: 2, name: "Right", x: 1920)

        let fixture = makeSpatialWarpTestFixture(
            entries: [leftEntry, rightEntry],
            monitors: [leftMonitor, rightMonitor]
        )
        defer { fixture.handler.cleanup() }

        // Cursor at left edge of leftmost monitor (no neighbor to the left)
        let margin = CGFloat(fixture.controller.settings.mouseWarpMargin)
        let location = CGPoint(
            x: leftMonitor.frame.minX + margin - 1,
            y: leftMonitor.frame.midY
        )

        fixture.handler.resetDebugStateForTests()
        fixture.handler.receiveTapMouseWarpMoved(at: location)
        fixture.handler.flushPendingWarpEventsForTests()

        // No warp, no clamp — cursor stays where it is
        #expect(fixture.handler.state.lastMonitorId == leftMonitor.id)
        #expect(fixture.recorder.warpedPoints.isEmpty)
        #expect(fixture.recorder.postedPoints.isEmpty)
    }

    // MARK: Clamp when cursor escapes to different monitor

    @Test @MainActor func clampWhenCursorEscapesToDifferentMonitor() {
        let leftEntry = makeTestEntry(name: "Left", displayId: 1, x: 0)
        let rightEntry = makeTestEntry(name: "Right", displayId: 2, x: 1920)
        let leftMonitor = makeTestMonitor(displayId: 1, name: "Left", x: 0)
        let rightMonitor = makeTestMonitor(displayId: 2, name: "Right", x: 1920)

        let fixture = makeSpatialWarpTestFixture(
            entries: [leftEntry, rightEntry],
            monitors: [leftMonitor, rightMonitor]
        )
        defer { fixture.handler.cleanup() }

        let margin = CGFloat(fixture.controller.settings.mouseWarpMargin)

        // Pretend the cursor was last on the left monitor
        fixture.handler.state.lastMonitorId = leftMonitor.id

        // Now send a location inside the right monitor
        let location = CGPoint(
            x: rightMonitor.frame.midX,
            y: rightMonitor.frame.midY
        )

        fixture.handler.resetDebugStateForTests()
        fixture.handler.receiveTapMouseWarpMoved(at: location)
        fixture.handler.flushPendingWarpEventsForTests()

        // Spatial engine: cursor jumped to a different monitor → clamp back to last (left)
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: leftMonitor.frame.maxX - margin - 1,
            y: leftMonitor.frame.midY
        ))

        #expect(fixture.handler.state.lastMonitorId == leftMonitor.id)
        #expect(fixture.recorder.postedPoints.isEmpty)
        #expect(fixture.recorder.warpedPoints == [expectedPoint])
    }
}
