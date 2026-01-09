import Foundation
import CoreGraphics

struct MonitorDwindleSettings: Codable, Identifiable, Equatable {
    let id: UUID
    var monitorName: String

    var smartSplit: Bool?
    var defaultSplitRatio: Double?
    var splitWidthMultiplier: Double?
    var singleWindowAspectRatio: String?
    var useGlobalGaps: Bool?
    var innerGap: Double?
    var outerGapTop: Double?
    var outerGapBottom: Double?
    var outerGapLeft: Double?
    var outerGapRight: Double?

    init(
        id: UUID = UUID(),
        monitorName: String,
        smartSplit: Bool? = nil,
        defaultSplitRatio: Double? = nil,
        splitWidthMultiplier: Double? = nil,
        singleWindowAspectRatio: String? = nil,
        useGlobalGaps: Bool? = nil,
        innerGap: Double? = nil,
        outerGapTop: Double? = nil,
        outerGapBottom: Double? = nil,
        outerGapLeft: Double? = nil,
        outerGapRight: Double? = nil
    ) {
        self.id = id
        self.monitorName = monitorName
        self.smartSplit = smartSplit
        self.defaultSplitRatio = defaultSplitRatio
        self.splitWidthMultiplier = splitWidthMultiplier
        self.singleWindowAspectRatio = singleWindowAspectRatio
        self.useGlobalGaps = useGlobalGaps
        self.innerGap = innerGap
        self.outerGapTop = outerGapTop
        self.outerGapBottom = outerGapBottom
        self.outerGapLeft = outerGapLeft
        self.outerGapRight = outerGapRight
    }

    var isUsingAllGlobalDefaults: Bool {
        smartSplit == nil &&
            defaultSplitRatio == nil &&
            splitWidthMultiplier == nil &&
            singleWindowAspectRatio == nil &&
            useGlobalGaps == nil &&
            innerGap == nil &&
            outerGapTop == nil &&
            outerGapBottom == nil &&
            outerGapLeft == nil &&
            outerGapRight == nil
    }

    mutating func resetToGlobalDefaults() {
        smartSplit = nil
        defaultSplitRatio = nil
        splitWidthMultiplier = nil
        singleWindowAspectRatio = nil
        useGlobalGaps = nil
        innerGap = nil
        outerGapTop = nil
        outerGapBottom = nil
        outerGapLeft = nil
        outerGapRight = nil
    }
}

struct ResolvedDwindleSettings: Equatable {
    let smartSplit: Bool
    let defaultSplitRatio: CGFloat
    let splitWidthMultiplier: CGFloat
    let singleWindowAspectRatio: DwindleSingleWindowAspectRatio
    let useGlobalGaps: Bool
    let innerGap: CGFloat
    let outerGapTop: CGFloat
    let outerGapBottom: CGFloat
    let outerGapLeft: CGFloat
    let outerGapRight: CGFloat
}
