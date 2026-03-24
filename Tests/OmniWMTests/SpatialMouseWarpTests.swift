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

@MainActor
private func makeThreeMonitorStackedFixture(margin: Int = 2) -> (
    controller: WMController,
    handler: MouseWarpHandler,
    recorder: WarpEffectRecorder,
    topLeft: Monitor,
    topRight: Monitor,
    bottom: Monitor
) {
    let topLeftEntry = makeTestEntry(
        name: "TopLeft", displayId: 1, x: 0, y: 1440, width: 2560, height: 1440)
    let topRightEntry = makeTestEntry(
        name: "TopRight", displayId: 2, x: 2560, y: 1440, width: 2560, height: 1440)
    let bottomEntry = makeTestEntry(
        name: "Bottom", displayId: 3, x: 840, y: 0, width: 3440, height: 1440)

    let topLeft = makeTestMonitor(
        displayId: 1, name: "TopLeft", x: 0, y: 1440, width: 2560, height: 1440)
    let topRight = makeTestMonitor(
        displayId: 2, name: "TopRight", x: 2560, y: 1440, width: 2560, height: 1440)
    let bottom = makeTestMonitor(
        displayId: 3, name: "Bottom", x: 840, y: 0, width: 3440, height: 1440)

    let fixture = makeSpatialWarpTestFixture(
        entries: [topLeftEntry, topRightEntry, bottomEntry],
        monitors: [topLeft, topRight, bottom],
        margin: margin
    )

    return (fixture.controller, fixture.handler, fixture.recorder, topLeft, topRight, bottom)
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

    // MARK: - 3-monitor stacked layout (R015)

    @Test @MainActor func threeMonitorTopLeftToTopRight() {
        let f = makeThreeMonitorStackedFixture()
        defer { f.handler.cleanup() }

        let margin = CGFloat(f.controller.settings.mouseWarpMargin)
        // Cursor at right edge of topLeft, midpoint Y
        let location = CGPoint(
            x: f.topLeft.frame.maxX - margin + 1,
            y: f.topLeft.frame.minY + 720
        )

        f.handler.resetDebugStateForTests()
        f.handler.receiveTapMouseWarpMoved(at: location)
        f.handler.flushPendingWarpEventsForTests()

        // Full height overlap (1440...2880), ratio = 720/1440 = 0.5, mapped = 2160
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: f.topRight.frame.minX + margin + 1,
            y: f.topLeft.frame.minY + 720
        ))

        #expect(f.handler.state.lastMonitorId == f.topRight.id)
        #expect(f.recorder.warpedPoints.isEmpty)
        #expect(f.recorder.postedPoints == [expectedPoint])
    }

    @Test @MainActor func threeMonitorTopRightToTopLeft() {
        let f = makeThreeMonitorStackedFixture()
        defer { f.handler.cleanup() }

        let margin = CGFloat(f.controller.settings.mouseWarpMargin)
        // Cursor at left edge of topRight, midpoint Y
        let location = CGPoint(
            x: f.topRight.frame.minX + margin - 1,
            y: f.topRight.frame.minY + 720
        )

        f.handler.resetDebugStateForTests()
        f.handler.receiveTapMouseWarpMoved(at: location)
        f.handler.flushPendingWarpEventsForTests()

        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: f.topLeft.frame.maxX - margin - 1,
            y: f.topRight.frame.minY + 720
        ))

        #expect(f.handler.state.lastMonitorId == f.topLeft.id)
        #expect(f.recorder.warpedPoints.isEmpty)
        #expect(f.recorder.postedPoints == [expectedPoint])
    }

    @Test @MainActor func threeMonitorTopLeftToBottom() {
        let f = makeThreeMonitorStackedFixture()
        defer { f.handler.cleanup() }

        let margin = CGFloat(f.controller.settings.mouseWarpMargin)
        let inset = margin + 1
        // Cursor at bottom edge of topLeft at x=1280
        let location = CGPoint(
            x: 1280,
            y: f.topLeft.frame.minY + margin - 1
        )

        f.handler.resetDebugStateForTests()
        f.handler.receiveTapMouseWarpMoved(at: location)
        f.handler.flushPendingWarpEventsForTests()

        // Overlap X range (topLeft.bottom ↔ bottom.top): 840...2560
        // ratio = (1280 - 840) / (2560 - 840) = 440/1720
        // mapped = 840 + (440/1720)*1720 = 1280
        // Landing: x=1280, y=bottom.maxY - inset = 1440 - 3 = 1437
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: 1280,
            y: f.bottom.frame.maxY - inset
        ))

        #expect(f.handler.state.lastMonitorId == f.bottom.id)
        #expect(f.recorder.warpedPoints.isEmpty)
        #expect(f.recorder.postedPoints == [expectedPoint])
    }

    @Test @MainActor func threeMonitorBottomToTopLeft() {
        let f = makeThreeMonitorStackedFixture()
        defer { f.handler.cleanup() }

        let margin = CGFloat(f.controller.settings.mouseWarpMargin)
        let inset = margin + 1
        // Cursor at top edge of bottom at x=1200 (within topLeft's X range 0..2560)
        let location = CGPoint(
            x: 1200,
            y: f.bottom.frame.maxY - margin + 1
        )

        f.handler.resetDebugStateForTests()
        f.handler.receiveTapMouseWarpMoved(at: location)
        f.handler.flushPendingWarpEventsForTests()

        // Overlap X range (bottom.top ↔ topLeft.bottom): 840...2560
        // ratio = (1200 - 840) / (2560 - 840) = 360/1720
        // mapped = 840 + (360/1720)*1720 = 1200
        // Landing: x=1200, y=topLeft.minY + inset = 1440 + 3 = 1443
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: 1200,
            y: f.topLeft.frame.minY + inset
        ))

        #expect(f.handler.state.lastMonitorId == f.topLeft.id)
        #expect(f.recorder.warpedPoints.isEmpty)
        #expect(f.recorder.postedPoints == [expectedPoint])
    }

    @Test @MainActor func threeMonitorBottomToTopRight() {
        let f = makeThreeMonitorStackedFixture()
        defer { f.handler.cleanup() }

        let margin = CGFloat(f.controller.settings.mouseWarpMargin)
        let inset = margin + 1
        // Cursor at top edge of bottom at x=3500 (within topRight's X range 2560..5120)
        let location = CGPoint(
            x: 3500,
            y: f.bottom.frame.maxY - margin + 1
        )

        f.handler.resetDebugStateForTests()
        f.handler.receiveTapMouseWarpMoved(at: location)
        f.handler.flushPendingWarpEventsForTests()

        // Overlap X range (bottom.top ↔ topRight.bottom): 2560...4280
        // ratio = (3500 - 2560) / (4280 - 2560) = 940/1720
        // mapped = 2560 + (940/1720)*1720 = 3500
        // Landing: x=3500, y=topRight.minY + inset = 1443
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: 3500,
            y: f.topRight.frame.minY + inset
        ))

        #expect(f.handler.state.lastMonitorId == f.topRight.id)
        #expect(f.recorder.warpedPoints.isEmpty)
        #expect(f.recorder.postedPoints == [expectedPoint])
    }

    @Test @MainActor func threeMonitorBottomCenterSeam() {
        let f = makeThreeMonitorStackedFixture()
        defer { f.handler.cleanup() }

        let margin = CGFloat(f.controller.settings.mouseWarpMargin)
        let inset = margin + 1
        // Center seam at x=2560 — exactly where topLeft and topRight meet.
        // adjacentMonitor returns topLeft (first match in entries array).
        let location = CGPoint(
            x: 2560,
            y: f.bottom.frame.maxY - margin + 1
        )

        f.handler.resetDebugStateForTests()
        f.handler.receiveTapMouseWarpMoved(at: location)
        f.handler.flushPendingWarpEventsForTests()

        // Overlap X range (bottom.top ↔ topLeft.bottom): 840...2560
        // ratio = (2560 - 840) / (2560 - 840) = 1.0
        // mapped = 840 + 1.0*1720 = 2560
        // Landing: x=2560 clamped to topLeft.maxX - inset = 2560 - 3 = 2557
        //          y=topLeft.minY + inset = 1443
        let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
            x: f.topLeft.frame.maxX - inset,
            y: f.topLeft.frame.minY + inset
        ))

        #expect(f.handler.state.lastMonitorId == f.topLeft.id)
        #expect(f.recorder.warpedPoints.isEmpty)
        #expect(f.recorder.postedPoints == [expectedPoint])
    }

    // MARK: - Edge-case and precision tests

    @Test @MainActor func proportionalLandingMapsCorrectlyThroughOverlapRange() {
        // Two monitors with partial vertical overlap:
        // Left: y 200..1000, Right: y 0..800 → overlap Y = 200...800
        let leftEntry = makeTestEntry(
            name: "Left", displayId: 1, x: 0, y: 200, width: 1920, height: 800)
        let rightEntry = makeTestEntry(
            name: "Right", displayId: 2, x: 1920, y: 0, width: 1920, height: 800)
        let leftMonitor = makeTestMonitor(
            displayId: 1, name: "Left", x: 0, y: 200, width: 1920, height: 800)
        let rightMonitor = makeTestMonitor(
            displayId: 2, name: "Right", x: 1920, y: 0, width: 1920, height: 800)

        let margin = 2
        let inset = CGFloat(margin + 1)
        // Overlap Y range: 200...800, length = 600
        let overlapLo: CGFloat = 200
        let overlapLength: CGFloat = 600

        for (label, fraction) in [("25%", 0.25), ("50%", 0.5), ("75%", 0.75)] {
            let fixture = makeSpatialWarpTestFixture(
                entries: [leftEntry, rightEntry],
                monitors: [leftMonitor, rightMonitor],
                margin: margin
            )
            defer { fixture.handler.cleanup() }

            let cursorY = overlapLo + (fraction * overlapLength)
            let location = CGPoint(
                x: leftMonitor.frame.maxX - CGFloat(margin) + 1,
                y: cursorY
            )

            fixture.handler.resetDebugStateForTests()
            fixture.handler.receiveTapMouseWarpMoved(at: location)
            fixture.handler.flushPendingWarpEventsForTests()

            // Target overlap range (right→left .left edge) is also 200...800
            let expectedY = overlapLo + (fraction * overlapLength)
            let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
                x: rightMonitor.frame.minX + inset,
                y: expectedY
            ))

            #expect(
                fixture.recorder.postedPoints == [expectedPoint],
                "Proportional landing at \(label) failed"
            )
            #expect(fixture.recorder.warpedPoints.isEmpty)
        }
    }

    @Test @MainActor func clampAtNonAdjacentEdgeWarpsBack() {
        // 3-monitor stacked: cursor at left edge of topLeft (no neighbor to the left)
        let f = makeThreeMonitorStackedFixture()
        defer { f.handler.cleanup() }

        let margin = CGFloat(f.controller.settings.mouseWarpMargin)
        let location = CGPoint(
            x: f.topLeft.frame.minX + margin - 1,
            y: f.topLeft.frame.midY
        )

        f.handler.resetDebugStateForTests()
        f.handler.receiveTapMouseWarpMoved(at: location)
        f.handler.flushPendingWarpEventsForTests()

        // No adjacent monitor to the left → no warp, no clamp
        #expect(f.handler.state.lastMonitorId == f.topLeft.id)
        #expect(f.recorder.postedPoints.isEmpty)
        #expect(f.recorder.warpedPoints.isEmpty)
    }

    @Test @MainActor func differentMarginValuesAffectTriggerAndLanding() {
        let leftEntry = makeTestEntry(name: "Left", displayId: 1, x: 0)
        let rightEntry = makeTestEntry(name: "Right", displayId: 2, x: 1920)
        let leftMonitor = makeTestMonitor(displayId: 1, name: "Left", x: 0)
        let rightMonitor = makeTestMonitor(displayId: 2, name: "Right", x: 1920)

        for marginValue in [1, 5] {
            let margin = CGFloat(marginValue)
            let inset = margin + 1

            // --- Trigger: cursor at exactly frame.maxX - margin → should warp ---
            do {
                let fixture = makeSpatialWarpTestFixture(
                    entries: [leftEntry, rightEntry],
                    monitors: [leftMonitor, rightMonitor],
                    margin: marginValue
                )
                defer { fixture.handler.cleanup() }

                let triggerLocation = CGPoint(
                    x: leftMonitor.frame.maxX - margin,
                    y: leftMonitor.frame.midY
                )

                fixture.handler.resetDebugStateForTests()
                fixture.handler.receiveTapMouseWarpMoved(at: triggerLocation)
                fixture.handler.flushPendingWarpEventsForTests()

                let expectedPoint = ScreenCoordinateSpace.toWindowServer(point: CGPoint(
                    x: rightMonitor.frame.minX + inset,
                    y: leftMonitor.frame.midY
                ))

                #expect(
                    fixture.recorder.postedPoints == [expectedPoint],
                    "margin=\(marginValue): warp should fire at trigger threshold"
                )
            }

            // --- No trigger: cursor at frame.maxX - margin - 1 → should NOT warp ---
            do {
                let fixture = makeSpatialWarpTestFixture(
                    entries: [leftEntry, rightEntry],
                    monitors: [leftMonitor, rightMonitor],
                    margin: marginValue
                )
                defer { fixture.handler.cleanup() }

                let noTriggerLocation = CGPoint(
                    x: leftMonitor.frame.maxX - margin - 1,
                    y: leftMonitor.frame.midY
                )

                fixture.handler.resetDebugStateForTests()
                fixture.handler.receiveTapMouseWarpMoved(at: noTriggerLocation)
                fixture.handler.flushPendingWarpEventsForTests()

                #expect(
                    fixture.recorder.postedPoints.isEmpty,
                    "margin=\(marginValue): warp should NOT fire outside trigger threshold"
                )
                #expect(fixture.recorder.warpedPoints.isEmpty)
            }
        }

        // Verify landing positions differ between margin=1 and margin=5
        let fixture1 = makeSpatialWarpTestFixture(
            entries: [leftEntry, rightEntry],
            monitors: [leftMonitor, rightMonitor],
            margin: 1
        )
        defer { fixture1.handler.cleanup() }

        fixture1.handler.resetDebugStateForTests()
        fixture1.handler.receiveTapMouseWarpMoved(at: CGPoint(
            x: leftMonitor.frame.maxX - 1, y: leftMonitor.frame.midY
        ))
        fixture1.handler.flushPendingWarpEventsForTests()

        let fixture5 = makeSpatialWarpTestFixture(
            entries: [leftEntry, rightEntry],
            monitors: [leftMonitor, rightMonitor],
            margin: 5
        )
        defer { fixture5.handler.cleanup() }

        fixture5.handler.resetDebugStateForTests()
        fixture5.handler.receiveTapMouseWarpMoved(at: CGPoint(
            x: leftMonitor.frame.maxX - 5, y: leftMonitor.frame.midY
        ))
        fixture5.handler.flushPendingWarpEventsForTests()

        // margin=1 → inset=2, landing x=1922; margin=5 → inset=6, landing x=1926
        #expect(fixture1.recorder.postedPoints.first != fixture5.recorder.postedPoints.first,
                "Different margins should produce different landing positions")
    }

    @Test @MainActor func warpFromBottomLeftCornerOfUltrawide() {
        // 3-monitor stacked: cursor at bottom-left corner of bottom monitor
        let f = makeThreeMonitorStackedFixture()
        defer { f.handler.cleanup() }

        let margin = CGFloat(f.controller.settings.mouseWarpMargin)
        // Bottom frame: (840, 0, 3440, 1440). Bottom-left corner = (840, 0)
        // Cursor at (840 + margin, 0 + margin) → left edge triggers first in if-else chain
        let location = CGPoint(
            x: f.bottom.frame.minX + margin,
            y: f.bottom.frame.minY + margin
        )

        f.handler.resetDebugStateForTests()
        f.handler.receiveTapMouseWarpMoved(at: location)
        f.handler.flushPendingWarpEventsForTests()

        // Left edge check fires: x (842) <= minX + margin (842) → true
        // No neighbor to bottom's left (no monitor with maxX ≈ 840) → no warp
        // Bottom edge never checked due to if-else chain
        #expect(f.handler.state.lastMonitorId == f.bottom.id)
        #expect(f.recorder.postedPoints.isEmpty)
        #expect(f.recorder.warpedPoints.isEmpty)
    }
}
