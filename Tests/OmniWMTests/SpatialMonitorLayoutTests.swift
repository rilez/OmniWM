import CoreGraphics
import Foundation
import Testing

@testable import OmniWM

// MARK: - Test helpers

private func makeSpatialTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: "com.omniwm.spatial.test.\(UUID().uuidString)")!
}

private func makeEntry(
    name: String = "Monitor",
    displayId: CGDirectDisplayID = 1,
    x: CGFloat = 0,
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

// MARK: - Tests

@Suite struct SpatialMonitorLayoutTests {

    // MARK: Codable round-trip

    @Test func codableRoundTrip() throws {
        let layout = SpatialMonitorLayout(entries: [
            makeEntry(name: "Left", displayId: 1, x: 0, y: 0),
            makeEntry(name: "Right", displayId: 2, x: 1920, y: 0),
        ])

        let data = try JSONEncoder().encode(layout)
        let decoded = try JSONDecoder().decode(SpatialMonitorLayout.self, from: data)
        #expect(decoded == layout)
    }

    // MARK: Horizontal 2-monitor adjacency

    @Test func horizontalAdjacencyLeftRight() {
        let left = makeEntry(name: "Left", displayId: 1, x: 0, y: 0)
        let right = makeEntry(name: "Right", displayId: 2, x: 1920, y: 0)
        let layout = SpatialMonitorLayout(entries: [left, right])

        // Left's right edge at mid-height → right monitor
        #expect(layout.adjacentMonitor(from: left, edge: .right, atPosition: 540) == right)
        // Right's left edge at mid-height → left monitor
        #expect(layout.adjacentMonitor(from: right, edge: .left, atPosition: 540) == left)

        // Non-adjacent edges return nil
        #expect(layout.adjacentMonitor(from: left, edge: .left, atPosition: 540) == nil)
        #expect(layout.adjacentMonitor(from: left, edge: .top, atPosition: 960) == nil)
        #expect(layout.adjacentMonitor(from: left, edge: .bottom, atPosition: 960) == nil)
        #expect(layout.adjacentMonitor(from: right, edge: .right, atPosition: 540) == nil)
        #expect(layout.adjacentMonitor(from: right, edge: .top, atPosition: 2880) == nil)
        #expect(layout.adjacentMonitor(from: right, edge: .bottom, atPosition: 2880) == nil)
    }

    // MARK: Vertical 2-monitor adjacency

    @Test func verticalAdjacencyTopBottom() {
        let bottom = makeEntry(name: "Bottom", displayId: 1, x: 0, y: 0)
        let top = makeEntry(name: "Top", displayId: 2, x: 0, y: 1080)
        let layout = SpatialMonitorLayout(entries: [bottom, top])

        // Bottom's top edge at mid-width → top monitor
        #expect(layout.adjacentMonitor(from: bottom, edge: .top, atPosition: 960) == top)
        // Top's bottom edge at mid-width → bottom monitor
        #expect(layout.adjacentMonitor(from: top, edge: .bottom, atPosition: 960) == bottom)

        // Non-adjacent edges return nil
        #expect(layout.adjacentMonitor(from: bottom, edge: .bottom, atPosition: 960) == nil)
        #expect(layout.adjacentMonitor(from: top, edge: .top, atPosition: 960) == nil)
    }

    // MARK: 3-monitor stacked layout (primary R015 test case)

    @Test func threeMonitorStackedAdjacency() {
        // Two 2560×1440 monitors side-by-side on top, centered over a
        // 3440×1440 ultrawide on bottom.
        // Top pair spans x = 0..5120.
        // Bottom centered: x = (5120 - 3440) / 2 = 840.
        let topLeft = makeEntry(name: "TopLeft", displayId: 1, x: 0, y: 1440, width: 2560, height: 1440)
        let topRight = makeEntry(name: "TopRight", displayId: 2, x: 2560, y: 1440, width: 2560, height: 1440)
        let bottom = makeEntry(name: "Bottom", displayId: 3, x: 840, y: 0, width: 3440, height: 1440)
        let layout = SpatialMonitorLayout(entries: [topLeft, topRight, bottom])

        // Top left ↔ top right horizontal adjacency
        #expect(layout.adjacentMonitor(from: topLeft, edge: .right, atPosition: 2000) == topRight)
        #expect(layout.adjacentMonitor(from: topRight, edge: .left, atPosition: 2000) == topLeft)

        // Top left → bottom (topLeft bottom edge at x=1280; bottom spans 840..4280)
        #expect(layout.adjacentMonitor(from: topLeft, edge: .bottom, atPosition: 1280) == bottom)
        // Top right → bottom (x=3000 is within bottom 840..4280)
        #expect(layout.adjacentMonitor(from: topRight, edge: .bottom, atPosition: 3000) == bottom)

        // Bottom → top left (x=900 is within bottom 840..4280 and topLeft 0..2560)
        #expect(layout.adjacentMonitor(from: bottom, edge: .top, atPosition: 900) == topLeft)
        // Bottom → top right (x=3000 is within topRight 2560..5120)
        #expect(layout.adjacentMonitor(from: bottom, edge: .top, atPosition: 3000) == topRight)

        // Center seam: x=2560 is the exact right edge of topLeft and left edge of topRight.
        // adjacentMonitor returns the first match (topLeft, since it appears first in entries
        // and 2560 == topLeft.maxX which satisfies atPosition <= dst.maxX).
        let centerResult = layout.adjacentMonitor(from: bottom, edge: .top, atPosition: 2560)
        #expect(centerResult == topLeft || centerResult == topRight)
    }

    // MARK: Partial overlap

    @Test func partialOverlapReturnsNeighborOnlyAtOverlap() {
        let a = makeEntry(name: "A", displayId: 1, x: 0, y: 0)
        let b = makeEntry(name: "B", displayId: 2, x: 1920, y: 500, width: 1920, height: 600)
        let layout = SpatialMonitorLayout(entries: [a, b])

        // y=800 is within B's vertical range 500..1100 → returns B
        #expect(layout.adjacentMonitor(from: a, edge: .right, atPosition: 800) == b)
        // y=100 is below B's vertical range → nil
        #expect(layout.adjacentMonitor(from: a, edge: .right, atPosition: 100) == nil)
    }

    // MARK: No adjacency with gap

    @Test func noAdjacencyWithGap() {
        let a = makeEntry(name: "A", displayId: 1, x: 0, y: 0)
        let b = makeEntry(name: "B", displayId: 2, x: 2000, y: 0)
        let layout = SpatialMonitorLayout(entries: [a, b])

        // 80pt gap between A (ends at 1920) and B (starts at 2000) → no adjacency
        #expect(layout.adjacentMonitor(from: a, edge: .right, atPosition: 540) == nil)
        #expect(layout.adjacentMonitor(from: b, edge: .left, atPosition: 540) == nil)
    }

    // MARK: overlapRange

    @Test func overlapRangeSameSize() {
        let left = makeEntry(name: "Left", displayId: 1, x: 0, y: 0)
        let right = makeEntry(name: "Right", displayId: 2, x: 1920, y: 0)
        let layout = SpatialMonitorLayout(entries: [left, right])

        let range = layout.overlapRange(from: left, to: right, edge: .right)
        #expect(range == 0...1080)
    }

    @Test func overlapRangeDifferentSize() {
        let a = makeEntry(name: "A", displayId: 1, x: 0, y: 0)
        let b = makeEntry(name: "B", displayId: 2, x: 1920, y: 200, width: 1920, height: 600)
        let layout = SpatialMonitorLayout(entries: [a, b])

        let range = layout.overlapRange(from: a, to: b, edge: .right)
        #expect(range == 200...800)
    }

    @Test func overlapRangeNoOverlap() {
        let a = makeEntry(name: "A", displayId: 1, x: 0, y: 0)
        let b = makeEntry(name: "B", displayId: 2, x: 2000, y: 0)
        let layout = SpatialMonitorLayout(entries: [a, b])

        // 80pt gap → edges don't align → nil
        #expect(layout.overlapRange(from: a, to: b, edge: .right) == nil)
    }

    // MARK: SettingsStore persistence round-trip

    @MainActor @Test func settingsStorePersistenceRoundTrip() {
        let defaults = makeSpatialTestDefaults()
        let entries: [SpatialMonitorEntry] = [
            makeEntry(name: "Left", displayId: 1, x: 0, y: 0),
            makeEntry(name: "Right", displayId: 2, x: 1920, y: 0),
        ]

        let store1 = SettingsStore(defaults: defaults)
        store1.spatialMonitorLayout = entries

        // Create a fresh store from the same defaults to prove persistence
        let store2 = SettingsStore(defaults: defaults)
        #expect(store2.spatialMonitorLayout == entries)
    }

    // MARK: Persistence failure-path: empty/missing defaults

    @MainActor @Test func loadFromEmptyDefaultsReturnsEmptyArray() {
        let defaults = makeSpatialTestDefaults()
        let store = SettingsStore(defaults: defaults)
        #expect(store.spatialMonitorLayout.isEmpty)
    }

    @MainActor @Test func loadFromCorruptDataReturnsEmptyArray() {
        let defaults = makeSpatialTestDefaults()
        defaults.set(Data("not json".utf8), forKey: "settings.spatialMonitorLayout")
        let store = SettingsStore(defaults: defaults)
        #expect(store.spatialMonitorLayout.isEmpty)
    }
}
