import SwiftUI

struct AnimationsSettingsTab: View {
    @Bindable var settings: SettingsStore
    @Bindable var controller: WMController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Section {
                    Toggle("Enable Animations", isOn: $settings.animationsEnabled)
                        .onChange(of: settings.animationsEnabled) { _, newValue in
                            controller.updateNiriConfig(animationsEnabled: newValue)
                        }

                    if !settings.animationsEnabled {
                        Text("All animations are disabled. Windows will snap instantly.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    SectionHeader(title: "General")
                }

                if settings.animationsEnabled {
                    AnimationContextSection(
                        title: "Focus Change",
                        description: "When keyboard navigation moves focus between columns",
                        animationType: $settings.focusChangeAnimationType,
                        springPreset: $settings.focusChangeSpringPreset,
                        springUseCustom: $settings.focusChangeUseCustom,
                        springDuration: $settings.focusChangeCustomDuration,
                        springBounce: $settings.focusChangeCustomBounce,
                        easingCurve: $settings.focusChangeEasingCurve,
                        easingDuration: $settings.focusChangeEasingDuration,
                        bezierX1: $settings.focusChangeBezierX1,
                        bezierY1: $settings.focusChangeBezierY1,
                        bezierX2: $settings.focusChangeBezierX2,
                        bezierY2: $settings.focusChangeBezierY2,
                        onUpdate: { updateFocusChangeConfig() }
                    )

                    AnimationContextSection(
                        title: "Gesture Completion",
                        description: "When trackpad or scroll wheel gesture ends",
                        animationType: $settings.gestureAnimationType,
                        springPreset: $settings.gestureSpringPreset,
                        springUseCustom: $settings.gestureUseCustom,
                        springDuration: $settings.gestureCustomDuration,
                        springBounce: $settings.gestureCustomBounce,
                        easingCurve: $settings.gestureEasingCurve,
                        easingDuration: $settings.gestureEasingDuration,
                        bezierX1: $settings.gestureBezierX1,
                        bezierY1: $settings.gestureBezierY1,
                        bezierX2: $settings.gestureBezierX2,
                        bezierY2: $settings.gestureBezierY2,
                        onUpdate: { updateGestureConfig() }
                    )

                    AnimationContextSection(
                        title: "Column Reveal",
                        description: "When scrolling to bring a column into view",
                        animationType: $settings.columnRevealAnimationType,
                        springPreset: $settings.columnRevealSpringPreset,
                        springUseCustom: $settings.columnRevealUseCustom,
                        springDuration: $settings.columnRevealCustomDuration,
                        springBounce: $settings.columnRevealCustomBounce,
                        easingCurve: $settings.columnRevealEasingCurve,
                        easingDuration: $settings.columnRevealEasingDuration,
                        bezierX1: $settings.columnRevealBezierX1,
                        bezierY1: $settings.columnRevealBezierY1,
                        bezierX2: $settings.columnRevealBezierX2,
                        bezierY2: $settings.columnRevealBezierY2,
                        onUpdate: { updateColumnRevealConfig() }
                    )

                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Animation Speed")
                                Slider(value: $settings.animationClockRate, in: 0.25 ... 2.0, step: 0.25)
                                Text(String(format: "%.2fx", settings.animationClockRate))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .frame(width: 50, alignment: .trailing)
                            }
                            .onChange(of: settings.animationClockRate) { _, newValue in
                                controller.updateAnimationClockRate(newValue)
                            }

                            Text("Slow down or speed up all animations. 1.0x is normal speed.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text("Scroll Deceleration")
                                Slider(value: $settings.decelerationRate, in: 0.990 ... 0.999, step: 0.001)
                                Text(String(format: "%.3f", settings.decelerationRate))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .frame(width: 50, alignment: .trailing)
                            }
                            .onChange(of: settings.decelerationRate) { _, newValue in
                                controller.updateDecelerationRate(newValue)
                            }

                            Text("Higher values = longer scroll momentum. Default: 0.997")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        SectionHeader(title: "Advanced")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spring: Physics-based animations with natural, velocity-aware motion. Duration controls speed. Bounce controls overshoot (0 = none, positive = bouncy).")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text("Easing: Time-based animations with predictable duration. Choose curve shape to control acceleration.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    SectionHeader(title: "About")
                }
            }
            .padding()
        }
    }

    private func updateFocusChangeConfig() {
        let springConfig = settings.focusChangeUseCustom
            ? SpringConfig(duration: settings.focusChangeCustomDuration, bounce: settings.focusChangeCustomBounce)
            : settings.focusChangeSpringPreset.config
        controller.updateNiriConfig(
            focusChangeSpringConfig: springConfig,
            focusChangeAnimationType: settings.focusChangeAnimationType,
            focusChangeEasingCurve: settings.focusChangeEasingCurve,
            focusChangeEasingDuration: settings.focusChangeEasingDuration
        )
    }

    private func updateGestureConfig() {
        let springConfig = settings.gestureUseCustom
            ? SpringConfig(duration: settings.gestureCustomDuration, bounce: settings.gestureCustomBounce)
            : settings.gestureSpringPreset.config
        controller.updateNiriConfig(
            gestureSpringConfig: springConfig,
            gestureAnimationType: settings.gestureAnimationType,
            gestureEasingCurve: settings.gestureEasingCurve,
            gestureEasingDuration: settings.gestureEasingDuration
        )
    }

    private func updateColumnRevealConfig() {
        let springConfig = settings.columnRevealUseCustom
            ? SpringConfig(duration: settings.columnRevealCustomDuration, bounce: settings.columnRevealCustomBounce)
            : settings.columnRevealSpringPreset.config
        controller.updateNiriConfig(
            columnRevealSpringConfig: springConfig,
            columnRevealAnimationType: settings.columnRevealAnimationType,
            columnRevealEasingCurve: settings.columnRevealEasingCurve,
            columnRevealEasingDuration: settings.columnRevealEasingDuration
        )
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

private struct AnimationContextSection: View {
    let title: String
    let description: String
    @Binding var animationType: AnimationType
    @Binding var springPreset: AnimationSpringPreset
    @Binding var springUseCustom: Bool
    @Binding var springDuration: Double
    @Binding var springBounce: Double
    @Binding var easingCurve: EasingCurve
    @Binding var easingDuration: Double
    @Binding var bezierX1: Double
    @Binding var bezierY1: Double
    @Binding var bezierX2: Double
    @Binding var bezierY2: Double
    let onUpdate: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Animation Type", selection: $animationType) {
                    ForEach(AnimationType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: animationType) { _, _ in onUpdate() }

                switch animationType {
                case .spring:
                    SpringOptionsView(
                        preset: $springPreset,
                        useCustom: $springUseCustom,
                        duration: $springDuration,
                        bounce: $springBounce,
                        onUpdate: onUpdate
                    )
                case .easing:
                    EasingOptionsView(
                        curve: $easingCurve,
                        duration: $easingDuration,
                        bezierX1: $bezierX1,
                        bezierY1: $bezierY1,
                        bezierX2: $bezierX2,
                        bezierY2: $bezierY2,
                        onUpdate: onUpdate
                    )
                }
            }
        } header: {
            SectionHeader(title: title)
        }
    }
}

private struct SpringOptionsView: View {
    @Binding var preset: AnimationSpringPreset
    @Binding var useCustom: Bool
    @Binding var duration: Double
    @Binding var bounce: Double
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Use Custom Values", isOn: $useCustom)
                .onChange(of: useCustom) { _, _ in onUpdate() }

            if useCustom {
                VStack(spacing: 8) {
                    HStack {
                        Text("Duration")
                        Slider(value: $duration, in: 0.15 ... 1.0, step: 0.05)
                        Text(String(format: "%.2fs", duration))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .onChange(of: duration) { _, _ in onUpdate() }

                    HStack {
                        Text("Bounce")
                        Slider(value: $bounce, in: -0.5 ... 0.5, step: 0.05)
                        Text(String(format: "%.2f", bounce))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .onChange(of: bounce) { _, _ in onUpdate() }

                    bounceDescription(for: bounce)
                }
            } else {
                Picker("Preset", selection: $preset) {
                    ForEach(AnimationSpringPreset.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: preset) { _, _ in onUpdate() }

                springPresetDescription(for: preset)
            }
        }
    }

    @ViewBuilder
    private func bounceDescription(for bounce: Double) -> some View {
        let desc: String = if bounce > 0.15 {
            "Very bouncy - visible overshoot"
        } else if bounce > 0 {
            "Slight bounce - subtle overshoot"
        } else if bounce == 0 {
            "Critically damped - no overshoot"
        } else if bounce > -0.25 {
            "Slightly overdamped - gentle approach"
        } else {
            "Very overdamped - slow, flat approach"
        }

        Text(desc)
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func springPresetDescription(for preset: AnimationSpringPreset) -> some View {
        let (desc, details): (String, String) = switch preset {
        case .snappy: ("Fast and precise, no overshoot", "Duration: 0.30s · Bounce: 0.0")
        case .smooth: ("Relaxed motion, no overshoot", "Duration: 0.50s · Bounce: 0.0")
        case .bouncy: ("Energetic with slight overshoot", "Duration: 0.45s · Bounce: 0.25")
        case .responsive: ("Ultra-fast, slightly flat", "Duration: 0.25s · Bounce: -0.1")
        }

        VStack(alignment: .leading, spacing: 2) {
            Text(desc)
                .font(.caption)
                .foregroundColor(.primary)
            Text(details)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

private struct EasingOptionsView: View {
    @Binding var curve: EasingCurve
    @Binding var duration: Double
    @Binding var bezierX1: Double
    @Binding var bezierY1: Double
    @Binding var bezierX2: Double
    @Binding var bezierY2: Double
    let onUpdate: () -> Void

    @State private var useCubicBezier: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Use Custom Bezier Curve", isOn: $useCubicBezier)
                .onChange(of: useCubicBezier) { _, newValue in
                    if newValue {
                        curve = .cubicBezier(x1: bezierX1, y1: bezierY1, x2: bezierX2, y2: bezierY2)
                    } else {
                        curve = .easeOutCubic
                    }
                    onUpdate()
                }

            if useCubicBezier {
                VStack(spacing: 8) {
                    HStack {
                        Text("X1")
                            .frame(width: 24, alignment: .leading)
                        Slider(value: $bezierX1, in: 0 ... 1, step: 0.01)
                        Text(String(format: "%.2f", bezierX1))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .onChange(of: bezierX1) { _, _ in
                        curve = .cubicBezier(x1: bezierX1, y1: bezierY1, x2: bezierX2, y2: bezierY2)
                        onUpdate()
                    }

                    HStack {
                        Text("Y1")
                            .frame(width: 24, alignment: .leading)
                        Slider(value: $bezierY1, in: 0 ... 1, step: 0.01)
                        Text(String(format: "%.2f", bezierY1))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .onChange(of: bezierY1) { _, _ in
                        curve = .cubicBezier(x1: bezierX1, y1: bezierY1, x2: bezierX2, y2: bezierY2)
                        onUpdate()
                    }

                    HStack {
                        Text("X2")
                            .frame(width: 24, alignment: .leading)
                        Slider(value: $bezierX2, in: 0 ... 1, step: 0.01)
                        Text(String(format: "%.2f", bezierX2))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .onChange(of: bezierX2) { _, _ in
                        curve = .cubicBezier(x1: bezierX1, y1: bezierY1, x2: bezierX2, y2: bezierY2)
                        onUpdate()
                    }

                    HStack {
                        Text("Y2")
                            .frame(width: 24, alignment: .leading)
                        Slider(value: $bezierY2, in: 0 ... 1, step: 0.01)
                        Text(String(format: "%.2f", bezierY2))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .onChange(of: bezierY2) { _, _ in
                        curve = .cubicBezier(x1: bezierX1, y1: bezierY1, x2: bezierX2, y2: bezierY2)
                        onUpdate()
                    }

                    Text("Control points for cubic-bezier(x1, y1, x2, y2)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Picker("Curve", selection: Binding(
                    get: { curve.isSimpleCase ? curve : .easeOutCubic },
                    set: { curve = $0; onUpdate() }
                )) {
                    ForEach(EasingCurve.allSimpleCases, id: \.displayName) { c in
                        Text(c.displayName).tag(c)
                    }
                }

                easingCurveDescription(for: curve)
            }

            HStack {
                Text("Duration")
                Slider(value: $duration, in: 0.1 ... 1.0, step: 0.05)
                Text(String(format: "%.2fs", duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(width: 50, alignment: .trailing)
            }
            .onChange(of: duration) { _, _ in onUpdate() }
        }
        .onAppear {
            if case .cubicBezier = curve {
                useCubicBezier = true
            }
        }
    }

    @ViewBuilder
    private func easingCurveDescription(for curve: EasingCurve) -> some View {
        let desc: String = switch curve {
        case .linear: "Constant speed throughout"
        case .easeOutQuad: "Gentle quadratic deceleration"
        case .easeOutCubic: "Smooth cubic deceleration"
        case .easeOutExpo: "Very fast start, gentle stop"
        case .cubicBezier: "Custom curve with control points"
        }

        Text(desc)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
