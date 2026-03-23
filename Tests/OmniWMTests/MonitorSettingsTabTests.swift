import CoreGraphics
import Testing

@testable import OmniWM

private func makeMonitorTabTestMonitor(
    displayId: CGDirectDisplayID,
    name: String,
    x: CGFloat,
    y: CGFloat,
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

@Suite struct MonitorSettingsTabTests {
    @Test func displayLabelsDisambiguateDuplicateMonitorNamesByPhysicalOrder() {
        let first = makeMonitorTabTestMonitor(displayId: 1, name: "Studio Display", x: 0, y: 0)
        let second = makeMonitorTabTestMonitor(displayId: 2, name: "Studio Display", x: 1920, y: 0)
        let labels = MonitorSettingsTabModel.displayLabels(for: [second, first])

        #expect(labels[first.id] == MonitorDisplayLabel(name: "Studio Display", duplicateIndex: 1))
        #expect(labels[second.id] == MonitorDisplayLabel(name: "Studio Display", duplicateIndex: 2))
    }

    @Test func displayLabelsAssignNoDuplicateIndexForUniqueNames() {
        let left = makeMonitorTabTestMonitor(displayId: 1, name: "Left", x: 0, y: 0)
        let right = makeMonitorTabTestMonitor(displayId: 2, name: "Right", x: 1920, y: 0)
        let labels = MonitorSettingsTabModel.displayLabels(for: [right, left])

        #expect(labels[left.id] == MonitorDisplayLabel(name: "Left", duplicateIndex: nil))
        #expect(labels[right.id] == MonitorDisplayLabel(name: "Right", duplicateIndex: nil))
    }

    @Test func displayLabelsSpatialSortBreaksTiesByVerticalPositionThenDisplayId() {
        // Two monitors at the same X but different Y. In AppKit coordinates,
        // higher Y means higher on screen. Spatial sort is top-to-bottom
        // (higher AppKit Y first), so displayId=2 gets index 1.
        let bottom = makeMonitorTabTestMonitor(displayId: 1, name: "Studio Display", x: 0, y: 0)
        let top = makeMonitorTabTestMonitor(displayId: 2, name: "Studio Display", x: 0, y: 1080)
        let labels = MonitorSettingsTabModel.displayLabels(for: [bottom, top])

        #expect(labels[top.id] == MonitorDisplayLabel(name: "Studio Display", duplicateIndex: 1))
        #expect(labels[bottom.id] == MonitorDisplayLabel(name: "Studio Display", duplicateIndex: 2))
    }
}
