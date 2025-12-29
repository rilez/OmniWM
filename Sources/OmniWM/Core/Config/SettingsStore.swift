import Foundation

@MainActor @Observable
final class SettingsStore {
    private let defaults: UserDefaults

    var hotkeysEnabled: Bool {
        didSet { defaults.set(hotkeysEnabled, forKey: Keys.hotkeysEnabled) }
    }

    var focusFollowsMouse: Bool {
        didSet { defaults.set(focusFollowsMouse, forKey: Keys.focusFollowsMouse) }
    }

    var moveMouseToFocusedWindow: Bool {
        didSet { defaults.set(moveMouseToFocusedWindow, forKey: Keys.moveMouseToFocusedWindow) }
    }

    var gapSize: Double {
        didSet { defaults.set(gapSize, forKey: Keys.gapSize) }
    }

    var fullscreenIgnoresGaps: Bool {
        didSet { defaults.set(fullscreenIgnoresGaps, forKey: Keys.fullscreenIgnoresGaps) }
    }

    var outerGapLeft: Double {
        didSet { defaults.set(outerGapLeft, forKey: Keys.outerGapLeft) }
    }

    var outerGapRight: Double {
        didSet { defaults.set(outerGapRight, forKey: Keys.outerGapRight) }
    }

    var outerGapTop: Double {
        didSet { defaults.set(outerGapTop, forKey: Keys.outerGapTop) }
    }

    var outerGapBottom: Double {
        didSet { defaults.set(outerGapBottom, forKey: Keys.outerGapBottom) }
    }

    var niriMaxWindowsPerColumn: Int {
        didSet { defaults.set(niriMaxWindowsPerColumn, forKey: Keys.niriMaxWindowsPerColumn) }
    }

    var niriMaxVisibleColumns: Int {
        didSet { defaults.set(niriMaxVisibleColumns, forKey: Keys.niriMaxVisibleColumns) }
    }

    var niriInfiniteLoop: Bool {
        didSet { defaults.set(niriInfiniteLoop, forKey: Keys.niriInfiniteLoop) }
    }

    var niriCenterFocusedColumn: CenterFocusedColumn {
        didSet { defaults.set(niriCenterFocusedColumn.rawValue, forKey: Keys.niriCenterFocusedColumn) }
    }

    var niriAlwaysCenterSingleColumn: Bool {
        didSet { defaults.set(niriAlwaysCenterSingleColumn, forKey: Keys.niriAlwaysCenterSingleColumn) }
    }

    var niriSingleWindowAspectRatio: SingleWindowAspectRatio {
        didSet { defaults.set(niriSingleWindowAspectRatio.rawValue, forKey: Keys.niriSingleWindowAspectRatio) }
    }

    var persistentWorkspacesRaw: String {
        didSet { defaults.set(persistentWorkspacesRaw, forKey: Keys.persistentWorkspaces) }
    }

    var workspaceAssignmentsRaw: String {
        didSet { defaults.set(workspaceAssignmentsRaw, forKey: Keys.workspaceAssignments) }
    }

    var workspaceConfigurations: [WorkspaceConfiguration] {
        didSet { saveWorkspaceConfigurations() }
    }

    var defaultLayoutType: LayoutType {
        didSet { defaults.set(defaultLayoutType.rawValue, forKey: Keys.defaultLayoutType) }
    }

    var bordersEnabled: Bool {
        didSet { defaults.set(bordersEnabled, forKey: Keys.bordersEnabled) }
    }

    var borderWidth: Double {
        didSet { defaults.set(borderWidth, forKey: Keys.borderWidth) }
    }

    var borderColorRed: Double {
        didSet { defaults.set(borderColorRed, forKey: Keys.borderColorRed) }
    }

    var borderColorGreen: Double {
        didSet { defaults.set(borderColorGreen, forKey: Keys.borderColorGreen) }
    }

    var borderColorBlue: Double {
        didSet { defaults.set(borderColorBlue, forKey: Keys.borderColorBlue) }
    }

    var borderColorAlpha: Double {
        didSet { defaults.set(borderColorAlpha, forKey: Keys.borderColorAlpha) }
    }

    var hotkeyBindings: [HotkeyBinding] {
        didSet { saveBindings() }
    }

    var workspaceBarEnabled: Bool {
        didSet { defaults.set(workspaceBarEnabled, forKey: Keys.workspaceBarEnabled) }
    }

    var workspaceBarShowLabels: Bool {
        didSet { defaults.set(workspaceBarShowLabels, forKey: Keys.workspaceBarShowLabels) }
    }

    var workspaceBarWindowLevel: String {
        didSet { defaults.set(workspaceBarWindowLevel, forKey: Keys.workspaceBarWindowLevel) }
    }

    var workspaceBarPosition: String {
        didSet { defaults.set(workspaceBarPosition, forKey: Keys.workspaceBarPosition) }
    }

    var workspaceBarNotchAware: Bool {
        didSet { defaults.set(workspaceBarNotchAware, forKey: Keys.workspaceBarNotchAware) }
    }

    var workspaceBarDeduplicateAppIcons: Bool {
        didSet { defaults.set(workspaceBarDeduplicateAppIcons, forKey: Keys.workspaceBarDeduplicateAppIcons) }
    }

    var workspaceBarHideEmptyWorkspaces: Bool {
        didSet { defaults.set(workspaceBarHideEmptyWorkspaces, forKey: Keys.workspaceBarHideEmptyWorkspaces) }
    }

    var workspaceBarHeight: Double {
        didSet { defaults.set(workspaceBarHeight, forKey: Keys.workspaceBarHeight) }
    }

    var workspaceBarBackgroundOpacity: Double {
        didSet { defaults.set(workspaceBarBackgroundOpacity, forKey: Keys.workspaceBarBackgroundOpacity) }
    }

    var workspaceBarXOffset: Double {
        didSet { defaults.set(workspaceBarXOffset, forKey: Keys.workspaceBarXOffset) }
    }

    var workspaceBarYOffset: Double {
        didSet { defaults.set(workspaceBarYOffset, forKey: Keys.workspaceBarYOffset) }
    }

    var monitorBarSettings: [MonitorBarSettings] {
        didSet { saveMonitorBarSettings() }
    }

    var appRules: [AppRule] {
        didSet { saveAppRules() }
    }

    var preventSleepEnabled: Bool {
        didSet { defaults.set(preventSleepEnabled, forKey: Keys.preventSleepEnabled) }
    }

    var scrollGestureEnabled: Bool {
        didSet { defaults.set(scrollGestureEnabled, forKey: Keys.scrollGestureEnabled) }
    }

    var scrollSensitivity: Double {
        didSet { defaults.set(scrollSensitivity, forKey: Keys.scrollSensitivity) }
    }

    var scrollModifierKey: ScrollModifierKey {
        didSet { defaults.set(scrollModifierKey.rawValue, forKey: Keys.scrollModifierKey) }
    }

    var gestureFingerCount: GestureFingerCount {
        didSet { defaults.set(gestureFingerCount.rawValue, forKey: Keys.gestureFingerCount) }
    }

    var gestureInvertDirection: Bool {
        didSet { defaults.set(gestureInvertDirection, forKey: Keys.gestureInvertDirection) }
    }

    var animationsEnabled: Bool {
        didSet { defaults.set(animationsEnabled, forKey: Keys.animationsEnabled) }
    }

    var focusChangeSpringPreset: AnimationSpringPreset {
        didSet { defaults.set(focusChangeSpringPreset.rawValue, forKey: Keys.focusChangeSpringPreset) }
    }

    var focusChangeUseCustom: Bool {
        didSet { defaults.set(focusChangeUseCustom, forKey: Keys.focusChangeUseCustom) }
    }

    var focusChangeCustomDuration: Double {
        didSet { defaults.set(focusChangeCustomDuration, forKey: Keys.focusChangeCustomDuration) }
    }

    var focusChangeCustomBounce: Double {
        didSet { defaults.set(focusChangeCustomBounce, forKey: Keys.focusChangeCustomBounce) }
    }

    var gestureSpringPreset: AnimationSpringPreset {
        didSet { defaults.set(gestureSpringPreset.rawValue, forKey: Keys.gestureSpringPreset) }
    }

    var gestureUseCustom: Bool {
        didSet { defaults.set(gestureUseCustom, forKey: Keys.gestureUseCustom) }
    }

    var gestureCustomDuration: Double {
        didSet { defaults.set(gestureCustomDuration, forKey: Keys.gestureCustomDuration) }
    }

    var gestureCustomBounce: Double {
        didSet { defaults.set(gestureCustomBounce, forKey: Keys.gestureCustomBounce) }
    }

    var columnRevealSpringPreset: AnimationSpringPreset {
        didSet { defaults.set(columnRevealSpringPreset.rawValue, forKey: Keys.columnRevealSpringPreset) }
    }

    var columnRevealUseCustom: Bool {
        didSet { defaults.set(columnRevealUseCustom, forKey: Keys.columnRevealUseCustom) }
    }

    var columnRevealCustomDuration: Double {
        didSet { defaults.set(columnRevealCustomDuration, forKey: Keys.columnRevealCustomDuration) }
    }

    var columnRevealCustomBounce: Double {
        didSet { defaults.set(columnRevealCustomBounce, forKey: Keys.columnRevealCustomBounce) }
    }

    var focusChangeAnimationType: AnimationType {
        didSet { defaults.set(focusChangeAnimationType.rawValue, forKey: Keys.focusChangeAnimationType) }
    }

    var focusChangeEasingCurve: EasingCurve {
        didSet { saveEasingCurve(focusChangeEasingCurve, typeKey: Keys.focusChangeEasingCurve, prefix: "focusChange") }
    }

    var focusChangeEasingDuration: Double {
        didSet { defaults.set(focusChangeEasingDuration, forKey: Keys.focusChangeEasingDuration) }
    }

    var focusChangeBezierX1: Double {
        didSet { defaults.set(focusChangeBezierX1, forKey: Keys.focusChangeBezierX1) }
    }

    var focusChangeBezierY1: Double {
        didSet { defaults.set(focusChangeBezierY1, forKey: Keys.focusChangeBezierY1) }
    }

    var focusChangeBezierX2: Double {
        didSet { defaults.set(focusChangeBezierX2, forKey: Keys.focusChangeBezierX2) }
    }

    var focusChangeBezierY2: Double {
        didSet { defaults.set(focusChangeBezierY2, forKey: Keys.focusChangeBezierY2) }
    }

    var gestureAnimationType: AnimationType {
        didSet { defaults.set(gestureAnimationType.rawValue, forKey: Keys.gestureAnimationType) }
    }

    var gestureEasingCurve: EasingCurve {
        didSet { saveEasingCurve(gestureEasingCurve, typeKey: Keys.gestureEasingCurve, prefix: "gesture") }
    }

    var gestureEasingDuration: Double {
        didSet { defaults.set(gestureEasingDuration, forKey: Keys.gestureEasingDuration) }
    }

    var gestureBezierX1: Double {
        didSet { defaults.set(gestureBezierX1, forKey: Keys.gestureBezierX1) }
    }

    var gestureBezierY1: Double {
        didSet { defaults.set(gestureBezierY1, forKey: Keys.gestureBezierY1) }
    }

    var gestureBezierX2: Double {
        didSet { defaults.set(gestureBezierX2, forKey: Keys.gestureBezierX2) }
    }

    var gestureBezierY2: Double {
        didSet { defaults.set(gestureBezierY2, forKey: Keys.gestureBezierY2) }
    }

    var columnRevealAnimationType: AnimationType {
        didSet { defaults.set(columnRevealAnimationType.rawValue, forKey: Keys.columnRevealAnimationType) }
    }

    var columnRevealEasingCurve: EasingCurve {
        didSet { saveEasingCurve(columnRevealEasingCurve, typeKey: Keys.columnRevealEasingCurve, prefix: "columnReveal") }
    }

    var columnRevealEasingDuration: Double {
        didSet { defaults.set(columnRevealEasingDuration, forKey: Keys.columnRevealEasingDuration) }
    }

    var columnRevealBezierX1: Double {
        didSet { defaults.set(columnRevealBezierX1, forKey: Keys.columnRevealBezierX1) }
    }

    var columnRevealBezierY1: Double {
        didSet { defaults.set(columnRevealBezierY1, forKey: Keys.columnRevealBezierY1) }
    }

    var columnRevealBezierX2: Double {
        didSet { defaults.set(columnRevealBezierX2, forKey: Keys.columnRevealBezierX2) }
    }

    var columnRevealBezierY2: Double {
        didSet { defaults.set(columnRevealBezierY2, forKey: Keys.columnRevealBezierY2) }
    }

    var decelerationRate: Double {
        didSet { defaults.set(decelerationRate, forKey: Keys.decelerationRate) }
    }

    var animationClockRate: Double {
        didSet { defaults.set(animationClockRate, forKey: Keys.animationClockRate) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hotkeysEnabled = defaults.object(forKey: Keys.hotkeysEnabled) as? Bool ?? true
        focusFollowsMouse = defaults.object(forKey: Keys.focusFollowsMouse) as? Bool ?? false
        moveMouseToFocusedWindow = defaults.object(forKey: Keys.moveMouseToFocusedWindow) as? Bool ?? false
        gapSize = defaults.object(forKey: Keys.gapSize) as? Double ?? 8
        fullscreenIgnoresGaps = defaults.object(forKey: Keys.fullscreenIgnoresGaps) as? Bool ?? true

        outerGapLeft = defaults.object(forKey: Keys.outerGapLeft) as? Double ?? 0
        outerGapRight = defaults.object(forKey: Keys.outerGapRight) as? Double ?? 0
        outerGapTop = defaults.object(forKey: Keys.outerGapTop) as? Double ?? 0
        outerGapBottom = defaults.object(forKey: Keys.outerGapBottom) as? Double ?? 0

        niriMaxWindowsPerColumn = defaults.object(forKey: Keys.niriMaxWindowsPerColumn) as? Int ?? 3
        niriMaxVisibleColumns = defaults.object(forKey: Keys.niriMaxVisibleColumns) as? Int ?? 2
        niriInfiniteLoop = defaults.object(forKey: Keys.niriInfiniteLoop) as? Bool ?? false
        niriCenterFocusedColumn = CenterFocusedColumn(rawValue: defaults
            .string(forKey: Keys.niriCenterFocusedColumn) ?? "") ?? .never
        niriAlwaysCenterSingleColumn = defaults.object(forKey: Keys.niriAlwaysCenterSingleColumn) as? Bool ?? true
        niriSingleWindowAspectRatio = SingleWindowAspectRatio(rawValue: defaults
            .string(forKey: Keys.niriSingleWindowAspectRatio) ?? "") ?? .ratio4x3

        persistentWorkspacesRaw = defaults.string(forKey: Keys.persistentWorkspaces) ?? ""
        workspaceAssignmentsRaw = defaults.string(forKey: Keys.workspaceAssignments) ?? ""

        workspaceConfigurations = Self.loadWorkspaceConfigurations(from: defaults)
        defaultLayoutType = LayoutType(rawValue: defaults.string(forKey: Keys.defaultLayoutType) ?? "") ?? .niri

        bordersEnabled = defaults.object(forKey: Keys.bordersEnabled) as? Bool ?? false
        borderWidth = defaults.object(forKey: Keys.borderWidth) as? Double ?? 4.0
        borderColorRed = defaults.object(forKey: Keys.borderColorRed) as? Double ?? 0.0
        borderColorGreen = defaults.object(forKey: Keys.borderColorGreen) as? Double ?? 0.5
        borderColorBlue = defaults.object(forKey: Keys.borderColorBlue) as? Double ?? 1.0
        borderColorAlpha = defaults.object(forKey: Keys.borderColorAlpha) as? Double ?? 1.0

        hotkeyBindings = Self.loadBindings(from: defaults)

        workspaceBarEnabled = defaults.object(forKey: Keys.workspaceBarEnabled) as? Bool ?? false
        workspaceBarShowLabels = defaults.object(forKey: Keys.workspaceBarShowLabels) as? Bool ?? true
        workspaceBarWindowLevel = defaults.string(forKey: Keys.workspaceBarWindowLevel) ?? "popup"
        workspaceBarPosition = defaults.string(forKey: Keys.workspaceBarPosition) ?? "overlappingMenuBar"
        workspaceBarNotchAware = defaults.object(forKey: Keys.workspaceBarNotchAware) as? Bool ?? false
        workspaceBarDeduplicateAppIcons = defaults
            .object(forKey: Keys.workspaceBarDeduplicateAppIcons) as? Bool ?? false
        workspaceBarHideEmptyWorkspaces = defaults
            .object(forKey: Keys.workspaceBarHideEmptyWorkspaces) as? Bool ?? false
        workspaceBarHeight = defaults.object(forKey: Keys.workspaceBarHeight) as? Double ?? 24.0
        workspaceBarBackgroundOpacity = defaults.object(forKey: Keys.workspaceBarBackgroundOpacity) as? Double ?? 0.1
        workspaceBarXOffset = defaults.object(forKey: Keys.workspaceBarXOffset) as? Double ?? 0.0
        workspaceBarYOffset = defaults.object(forKey: Keys.workspaceBarYOffset) as? Double ?? 0.0
        monitorBarSettings = Self.loadMonitorBarSettings(from: defaults)
        appRules = Self.loadAppRules(from: defaults)
        preventSleepEnabled = defaults.object(forKey: Keys.preventSleepEnabled) as? Bool ?? false
        scrollGestureEnabled = defaults.object(forKey: Keys.scrollGestureEnabled) as? Bool ?? true
        scrollSensitivity = defaults.object(forKey: Keys.scrollSensitivity) as? Double ?? 1.0
        scrollModifierKey = ScrollModifierKey(rawValue: defaults.string(forKey: Keys.scrollModifierKey) ?? "") ??
            .optionShift
        gestureFingerCount = GestureFingerCount(rawValue: defaults.integer(forKey: Keys.gestureFingerCount)) ?? .three
        gestureInvertDirection = defaults.object(forKey: Keys.gestureInvertDirection) as? Bool ?? true

        animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? true

        focusChangeSpringPreset = AnimationSpringPreset(
            rawValue: defaults.string(forKey: Keys.focusChangeSpringPreset) ?? ""
        ) ?? .appleNavigation
        focusChangeUseCustom = defaults.object(forKey: Keys.focusChangeUseCustom) as? Bool ?? false
        focusChangeCustomDuration = defaults.object(forKey: Keys.focusChangeCustomDuration) as? Double
            ?? Self.migrateToDuration(stiffness: defaults.object(forKey: Keys.focusChangeCustomStiffness) as? Double ?? 800)
        focusChangeCustomBounce = defaults.object(forKey: Keys.focusChangeCustomBounce) as? Double
            ?? Self.migrateToBounce(dampingRatio: defaults.object(forKey: Keys.focusChangeCustomDamping) as? Double ?? 1.0)

        gestureSpringPreset = AnimationSpringPreset(
            rawValue: defaults.string(forKey: Keys.gestureSpringPreset) ?? ""
        ) ?? .appleNavigation
        gestureUseCustom = defaults.object(forKey: Keys.gestureUseCustom) as? Bool ?? false
        gestureCustomDuration = defaults.object(forKey: Keys.gestureCustomDuration) as? Double
            ?? Self.migrateToDuration(stiffness: defaults.object(forKey: Keys.gestureCustomStiffness) as? Double ?? 800)
        gestureCustomBounce = defaults.object(forKey: Keys.gestureCustomBounce) as? Double
            ?? Self.migrateToBounce(dampingRatio: defaults.object(forKey: Keys.gestureCustomDamping) as? Double ?? 1.0)

        columnRevealSpringPreset = AnimationSpringPreset(
            rawValue: defaults.string(forKey: Keys.columnRevealSpringPreset) ?? ""
        ) ?? .appleNavigation
        columnRevealUseCustom = defaults.object(forKey: Keys.columnRevealUseCustom) as? Bool ?? false
        columnRevealCustomDuration = defaults.object(forKey: Keys.columnRevealCustomDuration) as? Double
            ?? Self.migrateToDuration(stiffness: defaults.object(forKey: Keys.columnRevealCustomStiffness) as? Double ?? 800)
        columnRevealCustomBounce = defaults.object(forKey: Keys.columnRevealCustomBounce) as? Double
            ?? Self.migrateToBounce(dampingRatio: defaults.object(forKey: Keys.columnRevealCustomDamping) as? Double ?? 1.0)

        focusChangeAnimationType = AnimationType(
            rawValue: defaults.string(forKey: Keys.focusChangeAnimationType) ?? ""
        ) ?? .spring
        let fcBezierX1 = defaults.object(forKey: Keys.focusChangeBezierX1) as? Double ?? 0.25
        let fcBezierY1 = defaults.object(forKey: Keys.focusChangeBezierY1) as? Double ?? 0.1
        let fcBezierX2 = defaults.object(forKey: Keys.focusChangeBezierX2) as? Double ?? 0.25
        let fcBezierY2 = defaults.object(forKey: Keys.focusChangeBezierY2) as? Double ?? 1.0
        focusChangeBezierX1 = fcBezierX1
        focusChangeBezierY1 = fcBezierY1
        focusChangeBezierX2 = fcBezierX2
        focusChangeBezierY2 = fcBezierY2
        focusChangeEasingCurve = Self.loadEasingCurve(
            from: defaults,
            typeKey: Keys.focusChangeEasingCurve,
            x1: fcBezierX1,
            y1: fcBezierY1,
            x2: fcBezierX2,
            y2: fcBezierY2
        )
        focusChangeEasingDuration = defaults.object(forKey: Keys.focusChangeEasingDuration) as? Double ?? 0.3

        gestureAnimationType = AnimationType(
            rawValue: defaults.string(forKey: Keys.gestureAnimationType) ?? ""
        ) ?? .spring
        let gBezierX1 = defaults.object(forKey: Keys.gestureBezierX1) as? Double ?? 0.25
        let gBezierY1 = defaults.object(forKey: Keys.gestureBezierY1) as? Double ?? 0.1
        let gBezierX2 = defaults.object(forKey: Keys.gestureBezierX2) as? Double ?? 0.25
        let gBezierY2 = defaults.object(forKey: Keys.gestureBezierY2) as? Double ?? 1.0
        gestureBezierX1 = gBezierX1
        gestureBezierY1 = gBezierY1
        gestureBezierX2 = gBezierX2
        gestureBezierY2 = gBezierY2
        gestureEasingCurve = Self.loadEasingCurve(
            from: defaults,
            typeKey: Keys.gestureEasingCurve,
            x1: gBezierX1,
            y1: gBezierY1,
            x2: gBezierX2,
            y2: gBezierY2
        )
        gestureEasingDuration = defaults.object(forKey: Keys.gestureEasingDuration) as? Double ?? 0.3

        columnRevealAnimationType = AnimationType(
            rawValue: defaults.string(forKey: Keys.columnRevealAnimationType) ?? ""
        ) ?? .spring
        let crBezierX1 = defaults.object(forKey: Keys.columnRevealBezierX1) as? Double ?? 0.25
        let crBezierY1 = defaults.object(forKey: Keys.columnRevealBezierY1) as? Double ?? 0.1
        let crBezierX2 = defaults.object(forKey: Keys.columnRevealBezierX2) as? Double ?? 0.25
        let crBezierY2 = defaults.object(forKey: Keys.columnRevealBezierY2) as? Double ?? 1.0
        columnRevealBezierX1 = crBezierX1
        columnRevealBezierY1 = crBezierY1
        columnRevealBezierX2 = crBezierX2
        columnRevealBezierY2 = crBezierY2
        columnRevealEasingCurve = Self.loadEasingCurve(
            from: defaults,
            typeKey: Keys.columnRevealEasingCurve,
            x1: crBezierX1,
            y1: crBezierY1,
            x2: crBezierX2,
            y2: crBezierY2
        )
        columnRevealEasingDuration = defaults.object(forKey: Keys.columnRevealEasingDuration) as? Double ?? 0.3

        decelerationRate = defaults.object(forKey: Keys.decelerationRate) as? Double ?? 0.997
        animationClockRate = defaults.object(forKey: Keys.animationClockRate) as? Double ?? 1.0
    }

    private static func loadEasingCurve(
        from defaults: UserDefaults,
        typeKey: String,
        x1: Double,
        y1: Double,
        x2: Double,
        y2: Double
    ) -> EasingCurve {
        guard let typeString = defaults.string(forKey: typeKey) else {
            return .easeOutCubic
        }

        switch typeString {
        case "linear": return .linear
        case "easeOutQuad": return .easeOutQuad
        case "easeOutCubic": return .easeOutCubic
        case "easeOutExpo": return .easeOutExpo
        case "cubicBezier": return .cubicBezier(x1: x1, y1: y1, x2: x2, y2: y2)
        case "easeInCubic", "easeInOutCubic", "easeInExpo", "easeInOutExpo":
            return .easeOutCubic
        default: return .easeOutCubic
        }
    }

    private func saveEasingCurve(_ curve: EasingCurve, typeKey: String, prefix: String) {
        switch curve {
        case .linear:
            defaults.set("linear", forKey: typeKey)
        case .easeOutQuad:
            defaults.set("easeOutQuad", forKey: typeKey)
        case .easeOutCubic:
            defaults.set("easeOutCubic", forKey: typeKey)
        case .easeOutExpo:
            defaults.set("easeOutExpo", forKey: typeKey)
        case .cubicBezier(let x1, let y1, let x2, let y2):
            defaults.set("cubicBezier", forKey: typeKey)
            defaults.set(x1, forKey: "settings.\(prefix)BezierX1")
            defaults.set(y1, forKey: "settings.\(prefix)BezierY1")
            defaults.set(x2, forKey: "settings.\(prefix)BezierX2")
            defaults.set(y2, forKey: "settings.\(prefix)BezierY2")
        }
    }

    private static func migrateToDuration(stiffness: Double) -> Double {
        let omega = sqrt(stiffness)
        let period = 2.0 * .pi / omega
        return min(max(period, 0.15), 1.0)
    }

    private static func migrateToBounce(dampingRatio: Double) -> Double {
        if dampingRatio >= 1.0 {
            return -(dampingRatio - 1.0).clamped(to: 0 ... 0.5)
        } else {
            return (1.0 - dampingRatio).clamped(to: 0 ... 0.5)
        }
    }

    private static func loadBindings(from defaults: UserDefaults) -> [HotkeyBinding] {
        guard let data = defaults.data(forKey: Keys.hotkeyBindings),
              let bindings = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
        else {
            return DefaultHotkeyBindings.all()
        }

        return mergeWithDefaults(stored: bindings)
    }

    private static func mergeWithDefaults(stored: [HotkeyBinding]) -> [HotkeyBinding] {
        let storedIds = Set(stored.map(\.id))
        let defaults = DefaultHotkeyBindings.all()
        var result = stored

        for defaultBinding in defaults where !storedIds.contains(defaultBinding.id) {
            result.append(defaultBinding)
        }
        return result
    }

    private func saveBindings() {
        guard let data = try? JSONEncoder().encode(hotkeyBindings) else { return }
        defaults.set(data, forKey: Keys.hotkeyBindings)
    }

    func resetHotkeysToDefaults() {
        hotkeyBindings = DefaultHotkeyBindings.all()
    }

    func updateBinding(for commandId: String, newBinding: KeyBinding) {
        guard let index = hotkeyBindings.firstIndex(where: { $0.id == commandId }) else { return }
        hotkeyBindings[index] = HotkeyBinding(
            id: hotkeyBindings[index].id,
            command: hotkeyBindings[index].command,
            binding: newBinding
        )
    }

    func findConflicts(for binding: KeyBinding, excluding commandId: String) -> [HotkeyBinding] {
        hotkeyBindings.filter { $0.id != commandId && $0.binding.conflicts(with: binding) }
    }

    func persistentWorkspaceNames() -> [String] {
        if !workspaceConfigurations.isEmpty {
            return workspaceConfigurations
                .filter(\.isPersistent)
                .map(\.name)
        }

        let parts = persistentWorkspacesRaw.split { $0 == "," || $0 == "\n" || $0 == "\r" }
        var result: [String] = []
        var seen: Set<String> = []
        for part in parts {
            let trimmed = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard case let .success(name) = WorkspaceName.parse(trimmed) else { continue }
            guard !seen.contains(name.raw) else { continue }
            seen.insert(name.raw)
            result.append(name.raw)
        }
        return result
    }

    func workspaceToMonitorAssignments() -> [String: [MonitorDescription]] {
        if !workspaceConfigurations.isEmpty {
            var result: [String: [MonitorDescription]] = [:]
            for config in workspaceConfigurations {
                if let desc = config.monitorAssignment.toMonitorDescription() {
                    result[config.name] = [desc]
                }
            }
            return result
        }

        var result: [String: [MonitorDescription]] = [:]
        let lines = workspaceAssignmentsRaw.split(whereSeparator: \.isNewline)
        for line in lines {
            let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            let parts: [Substring] = if trimmedLine.contains(":") {
                trimmedLine.split(separator: ":", maxSplits: 1)
            } else {
                trimmedLine.split(separator: "=", maxSplits: 1)
            }
            guard parts.count == 2 else { continue }
            let namePart = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let monitorsPart = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard case let .success(name) = WorkspaceName.parse(namePart) else { continue }

            let monitorTokens = monitorsPart.split(separator: ",")
            let monitors: [MonitorDescription] = monitorTokens.compactMap { token in
                let raw = token.trimmingCharacters(in: .whitespacesAndNewlines)
                guard case let .success(desc) = parseMonitorDescription(raw) else { return nil }
                return desc
            }
            guard !monitors.isEmpty else { continue }
            result[name.raw, default: []].append(contentsOf: monitors)
        }
        return result
    }

    func layoutType(for workspaceName: String) -> LayoutType {
        if let config = workspaceConfigurations.first(where: { $0.name == workspaceName }) {
            if config.layoutType == .defaultLayout {
                return defaultLayoutType
            }
            return config.layoutType
        }
        return defaultLayoutType
    }

    func displayName(for workspaceName: String) -> String {
        workspaceConfigurations.first(where: { $0.name == workspaceName })?.effectiveDisplayName ?? workspaceName
    }

    private static func loadWorkspaceConfigurations(from defaults: UserDefaults) -> [WorkspaceConfiguration] {
        if let data = defaults.data(forKey: Keys.workspaceConfigurations),
           let configs = try? JSONDecoder().decode([WorkspaceConfiguration].self, from: data)
        {
            return configs
        }

        let migrated = defaults.bool(forKey: Keys.workspaceSettingsMigrated)
        if !migrated {
            let configs = migrateFromLegacySettings(defaults: defaults)
            if !configs.isEmpty {
                if let data = try? JSONEncoder().encode(configs) {
                    defaults.set(data, forKey: Keys.workspaceConfigurations)
                }
                defaults.set(true, forKey: Keys.workspaceSettingsMigrated)
                return configs
            }
        }

        return []
    }

    private static func migrateFromLegacySettings(defaults: UserDefaults) -> [WorkspaceConfiguration] {
        var result: [WorkspaceConfiguration] = []
        var seen: Set<String> = []

        let persistentRaw = defaults.string(forKey: Keys.persistentWorkspaces) ?? ""
        let persistentNames = persistentRaw
            .split { $0 == "," || $0 == "\n" || $0 == "\r" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let assignmentsRaw = defaults.string(forKey: Keys.workspaceAssignments) ?? ""
        var assignments: [String: MonitorAssignment] = [:]
        for line in assignmentsRaw.split(whereSeparator: \.isNewline) {
            let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.contains(":")
                ? trimmed.split(separator: ":", maxSplits: 1)
                : trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let monitorStr = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)

            let firstMonitor = monitorStr.split(separator: ",").first
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? monitorStr
            assignments[name] = MonitorAssignment.fromString(firstMonitor)
        }

        for name in persistentNames {
            guard !seen.contains(name) else { continue }
            guard case .success = WorkspaceName.parse(name) else { continue }
            seen.insert(name)
            result.append(WorkspaceConfiguration(
                name: name,
                monitorAssignment: assignments[name] ?? .any,
                layoutType: .defaultLayout,
                isPersistent: true
            ))
        }

        for (name, assignment) in assignments where !seen.contains(name) {
            guard case .success = WorkspaceName.parse(name) else { continue }
            seen.insert(name)
            result.append(WorkspaceConfiguration(
                name: name,
                monitorAssignment: assignment,
                layoutType: .defaultLayout,
                isPersistent: false
            ))
        }

        return result
    }

    private func saveWorkspaceConfigurations() {
        guard let data = try? JSONEncoder().encode(workspaceConfigurations) else { return }
        defaults.set(data, forKey: Keys.workspaceConfigurations)
        defaults.set(true, forKey: Keys.workspaceSettingsMigrated)
    }

    private static func loadMonitorBarSettings(from defaults: UserDefaults) -> [MonitorBarSettings] {
        guard let data = defaults.data(forKey: Keys.monitorBarSettings),
              let settings = try? JSONDecoder().decode([MonitorBarSettings].self, from: data)
        else {
            return []
        }
        return settings
    }

    private func saveMonitorBarSettings() {
        guard let data = try? JSONEncoder().encode(monitorBarSettings) else { return }
        defaults.set(data, forKey: Keys.monitorBarSettings)
    }

    func barSettings(for monitorName: String) -> MonitorBarSettings? {
        monitorBarSettings.first { $0.monitorName == monitorName }
    }

    func getOrCreateBarSettings(for monitorName: String) -> MonitorBarSettings {
        if let existing = barSettings(for: monitorName) {
            return existing
        }
        let newSettings = MonitorBarSettings(monitorName: monitorName)
        monitorBarSettings.append(newSettings)
        return newSettings
    }

    func updateBarSettings(_ settings: MonitorBarSettings) {
        if let index = monitorBarSettings.firstIndex(where: { $0.monitorName == settings.monitorName }) {
            monitorBarSettings[index] = settings
        } else {
            monitorBarSettings.append(settings)
        }
    }

    func removeBarSettings(for monitorName: String) {
        monitorBarSettings.removeAll { $0.monitorName == monitorName }
    }

    func resolvedBarSettings(for monitorName: String) -> ResolvedBarSettings {
        let override = barSettings(for: monitorName)

        return ResolvedBarSettings(
            enabled: override?.enabled ?? workspaceBarEnabled,
            showLabels: override?.showLabels ?? workspaceBarShowLabels,
            deduplicateAppIcons: override?.deduplicateAppIcons ?? workspaceBarDeduplicateAppIcons,
            hideEmptyWorkspaces: override?.hideEmptyWorkspaces ?? workspaceBarHideEmptyWorkspaces,
            notchAware: override?.notchAware ?? workspaceBarNotchAware,
            position: WorkspaceBarPosition(rawValue: override?.position ?? workspaceBarPosition) ?? .overlappingMenuBar,
            windowLevel: WorkspaceBarWindowLevel(rawValue: override?.windowLevel ?? workspaceBarWindowLevel) ?? .popup,
            height: override?.height ?? workspaceBarHeight,
            backgroundOpacity: override?.backgroundOpacity ?? workspaceBarBackgroundOpacity,
            xOffset: override?.xOffset ?? workspaceBarXOffset,
            yOffset: override?.yOffset ?? workspaceBarYOffset
        )
    }

    private static func loadAppRules(from defaults: UserDefaults) -> [AppRule] {
        guard let data = defaults.data(forKey: Keys.appRules),
              let rules = try? JSONDecoder().decode([AppRule].self, from: data)
        else {
            return []
        }
        return rules
    }

    private func saveAppRules() {
        guard let data = try? JSONEncoder().encode(appRules) else { return }
        defaults.set(data, forKey: Keys.appRules)
    }

    func appRule(for bundleId: String) -> AppRule? {
        appRules.first { $0.bundleId == bundleId }
    }
}

private enum Keys {
    static let hotkeysEnabled = "settings.hotkeysEnabled"
    static let focusFollowsMouse = "settings.focusFollowsMouse"
    static let moveMouseToFocusedWindow = "settings.moveMouseToFocusedWindow"
    static let gapSize = "settings.gapSize"
    static let fullscreenIgnoresGaps = "settings.fullscreenIgnoresGaps"

    static let outerGapLeft = "settings.outerGapLeft"
    static let outerGapRight = "settings.outerGapRight"
    static let outerGapTop = "settings.outerGapTop"
    static let outerGapBottom = "settings.outerGapBottom"

    static let niriMaxWindowsPerColumn = "settings.niriMaxWindowsPerColumn"
    static let niriMaxVisibleColumns = "settings.niriMaxVisibleColumns"
    static let niriInfiniteLoop = "settings.niriInfiniteLoop"
    static let niriCenterFocusedColumn = "settings.niriCenterFocusedColumn"
    static let niriAlwaysCenterSingleColumn = "settings.niriAlwaysCenterSingleColumn"
    static let niriSingleWindowAspectRatio = "settings.niriSingleWindowAspectRatio"

    static let persistentWorkspaces = "settings.persistentWorkspaces"
    static let workspaceAssignments = "settings.workspaceAssignments"
    static let workspaceConfigurations = "settings.workspaceConfigurations"
    static let defaultLayoutType = "settings.defaultLayoutType"
    static let workspaceSettingsMigrated = "settings.workspaceSettingsMigrated"

    static let bordersEnabled = "settings.bordersEnabled"
    static let borderWidth = "settings.borderWidth"
    static let borderColorRed = "settings.borderColorRed"
    static let borderColorGreen = "settings.borderColorGreen"
    static let borderColorBlue = "settings.borderColorBlue"
    static let borderColorAlpha = "settings.borderColorAlpha"

    static let hotkeyBindings = "settings.hotkeyBindings"

    static let workspaceBarEnabled = "settings.workspaceBar.enabled"
    static let workspaceBarShowLabels = "settings.workspaceBar.showLabels"
    static let workspaceBarWindowLevel = "settings.workspaceBar.windowLevel"
    static let workspaceBarPosition = "settings.workspaceBar.position"
    static let workspaceBarNotchAware = "settings.workspaceBar.notchAware"
    static let workspaceBarDeduplicateAppIcons = "settings.workspaceBar.deduplicateAppIcons"
    static let workspaceBarHideEmptyWorkspaces = "settings.workspaceBar.hideEmptyWorkspaces"
    static let workspaceBarHeight = "settings.workspaceBar.height"
    static let workspaceBarBackgroundOpacity = "settings.workspaceBar.backgroundOpacity"
    static let workspaceBarXOffset = "settings.workspaceBar.xOffset"
    static let workspaceBarYOffset = "settings.workspaceBar.yOffset"
    static let monitorBarSettings = "settings.workspaceBar.monitorSettings"

    static let appRules = "settings.appRules"
    static let preventSleepEnabled = "settings.preventSleepEnabled"
    static let scrollGestureEnabled = "settings.scrollGestureEnabled"
    static let scrollSensitivity = "settings.scrollSensitivity"
    static let scrollModifierKey = "settings.scrollModifierKey"
    static let gestureFingerCount = "settings.gestureFingerCount"
    static let gestureInvertDirection = "settings.gestureInvertDirection"

    static let animationsEnabled = "settings.animationsEnabled"
    static let focusChangeSpringPreset = "settings.focusChangeSpringPreset"
    static let focusChangeUseCustom = "settings.focusChangeUseCustom"
    static let focusChangeCustomDuration = "settings.focusChangeCustomDuration"
    static let focusChangeCustomBounce = "settings.focusChangeCustomBounce"
    static let focusChangeCustomStiffness = "settings.focusChangeCustomStiffness"
    static let focusChangeCustomDamping = "settings.focusChangeCustomDamping"
    static let gestureSpringPreset = "settings.gestureSpringPreset"
    static let gestureUseCustom = "settings.gestureUseCustom"
    static let gestureCustomDuration = "settings.gestureCustomDuration"
    static let gestureCustomBounce = "settings.gestureCustomBounce"
    static let gestureCustomStiffness = "settings.gestureCustomStiffness"
    static let gestureCustomDamping = "settings.gestureCustomDamping"
    static let columnRevealSpringPreset = "settings.columnRevealSpringPreset"
    static let columnRevealUseCustom = "settings.columnRevealUseCustom"
    static let columnRevealCustomDuration = "settings.columnRevealCustomDuration"
    static let columnRevealCustomBounce = "settings.columnRevealCustomBounce"
    static let columnRevealCustomStiffness = "settings.columnRevealCustomStiffness"
    static let columnRevealCustomDamping = "settings.columnRevealCustomDamping"

    static let focusChangeAnimationType = "settings.focusChangeAnimationType"
    static let focusChangeEasingCurve = "settings.focusChangeEasingCurve"
    static let focusChangeEasingDuration = "settings.focusChangeEasingDuration"
    static let focusChangeBezierX1 = "settings.focusChangeBezierX1"
    static let focusChangeBezierY1 = "settings.focusChangeBezierY1"
    static let focusChangeBezierX2 = "settings.focusChangeBezierX2"
    static let focusChangeBezierY2 = "settings.focusChangeBezierY2"
    static let gestureAnimationType = "settings.gestureAnimationType"
    static let gestureEasingCurve = "settings.gestureEasingCurve"
    static let gestureEasingDuration = "settings.gestureEasingDuration"
    static let gestureBezierX1 = "settings.gestureBezierX1"
    static let gestureBezierY1 = "settings.gestureBezierY1"
    static let gestureBezierX2 = "settings.gestureBezierX2"
    static let gestureBezierY2 = "settings.gestureBezierY2"
    static let columnRevealAnimationType = "settings.columnRevealAnimationType"
    static let columnRevealEasingCurve = "settings.columnRevealEasingCurve"
    static let columnRevealEasingDuration = "settings.columnRevealEasingDuration"
    static let columnRevealBezierX1 = "settings.columnRevealBezierX1"
    static let columnRevealBezierY1 = "settings.columnRevealBezierY1"
    static let columnRevealBezierX2 = "settings.columnRevealBezierX2"
    static let columnRevealBezierY2 = "settings.columnRevealBezierY2"
    static let decelerationRate = "settings.decelerationRate"
    static let animationClockRate = "settings.animationClockRate"
}

enum ScrollModifierKey: String, CaseIterable, Codable {
    case optionShift
    case controlShift

    var displayName: String {
        switch self {
        case .optionShift: "Option+Shift (⌥⇧)"
        case .controlShift: "Control+Shift (⌃⇧)"
        }
    }
}

enum GestureFingerCount: Int, CaseIterable, Codable {
    case two = 2
    case three = 3
    case four = 4

    var displayName: String {
        switch self {
        case .two: "2 Fingers"
        case .three: "3 Fingers"
        case .four: "4 Fingers"
        }
    }
}

enum AnimationSpringPreset: String, CaseIterable, Codable {
    case appleNavigation
    case snappy
    case smooth
    case bouncy
    case responsive

    var displayName: String {
        switch self {
        case .appleNavigation: "Apple Navigation"
        case .snappy: "Snappy"
        case .smooth: "Smooth"
        case .bouncy: "Bouncy"
        case .responsive: "Responsive"
        }
    }

    var config: SpringConfig {
        switch self {
        case .appleNavigation: .appleNavigation
        case .snappy: .snappy
        case .smooth: .smooth
        case .bouncy: .bouncy
        case .responsive: .responsive
        }
    }
}

enum AnimationType: String, CaseIterable, Codable {
    case spring
    case easing

    var displayName: String {
        switch self {
        case .spring: "Spring"
        case .easing: "Easing"
        }
    }
}
