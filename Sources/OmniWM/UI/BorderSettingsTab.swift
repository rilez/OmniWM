import AppKit
import SwiftUI

struct BorderSettingsTab: View {
    @Bindable var settings: SettingsStore
    @Bindable var controller: WMController

    var body: some View {
        Form {
            Section("Window Borders") {
                Toggle("Enable Borders", isOn: $settings.bordersEnabled)
                    .onChange(of: settings.bordersEnabled) { _, newValue in
                        controller.setBordersEnabled(newValue)
                    }

                if settings.bordersEnabled {
                    HStack {
                        Text("Border Width")
                        Slider(value: $settings.borderWidth, in: 1 ... 12, step: 0.5)
                        Text("\(settings.borderWidth, specifier: "%.1f") px")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .onChange(of: settings.borderWidth) { _, _ in
                        syncBorderConfig()
                    }

                    Picker("Effect", selection: effectTypeBinding) {
                        ForEach(BorderEffectType.allCases, id: \.rawValue) { effect in
                            Text(effect.displayName).tag(effect)
                        }
                    }
                    .onChange(of: settings.borderEffectType) { _, _ in
                        syncBorderConfig()
                    }

                    if settings.borderEffectType == BorderEffectType.pulse.rawValue {
                        HStack {
                            Text("Pulse Speed")
                            Slider(value: $settings.borderPulseSpeed, in: 0.5 ... 3.0, step: 0.1)
                            Text("\(settings.borderPulseSpeed, specifier: "%.1f")x")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .frame(width: 40, alignment: .trailing)
                        }
                        .onChange(of: settings.borderPulseSpeed) { _, _ in syncBorderConfig() }
                    }

                    if settings.borderEffectType == BorderEffectType.snake.rawValue {
                        HStack {
                            Text("Rotation Speed")
                            Slider(value: $settings.borderSnakeSpeed, in: 0.1 ... 3.0, step: 0.1)
                            Text("\(settings.borderSnakeSpeed, specifier: "%.1f")x")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .frame(width: 40, alignment: .trailing)
                        }
                        .onChange(of: settings.borderSnakeSpeed) { _, _ in syncBorderConfig() }
                    }

                    Divider()

                    Text("Border Color").font(.subheadline).foregroundColor(.secondary)

                    ColorPicker("Primary Color", selection: colorBinding, supportsOpacity: true)
                        .onChange(of: settings.borderColorRed) { _, _ in syncBorderConfig() }
                        .onChange(of: settings.borderColorGreen) { _, _ in syncBorderConfig() }
                        .onChange(of: settings.borderColorBlue) { _, _ in syncBorderConfig() }
                        .onChange(of: settings.borderColorAlpha) { _, _ in syncBorderConfig() }

                    if settings.borderEffectType == BorderEffectType.snake.rawValue {
                        ColorPicker("Secondary Color", selection: secondaryColorBinding, supportsOpacity: true)
                            .onChange(of: settings.borderSecondaryColorRed) { _, _ in syncBorderConfig() }
                            .onChange(of: settings.borderSecondaryColorGreen) { _, _ in syncBorderConfig() }
                            .onChange(of: settings.borderSecondaryColorBlue) { _, _ in syncBorderConfig() }
                            .onChange(of: settings.borderSecondaryColorAlpha) { _, _ in syncBorderConfig() }
                    }
                }
            }

            Section("About") {
                Text("Borders are displayed around the currently focused window.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                Color(
                    red: settings.borderColorRed,
                    green: settings.borderColorGreen,
                    blue: settings.borderColorBlue,
                    opacity: settings.borderColorAlpha
                )
            },
            set: { newColor in
                if let cgColor = NSColor(newColor).usingColorSpace(.deviceRGB)?.cgColor,
                   let components = cgColor.components, components.count >= 3
                {
                    settings.borderColorRed = Double(components[0])
                    settings.borderColorGreen = Double(components[1])
                    settings.borderColorBlue = Double(components[2])
                    if components.count >= 4 {
                        settings.borderColorAlpha = Double(components[3])
                    }
                }
            }
        )
    }

    private var secondaryColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(
                    red: settings.borderSecondaryColorRed,
                    green: settings.borderSecondaryColorGreen,
                    blue: settings.borderSecondaryColorBlue,
                    opacity: settings.borderSecondaryColorAlpha
                )
            },
            set: { newColor in
                if let cgColor = NSColor(newColor).usingColorSpace(.deviceRGB)?.cgColor,
                   let components = cgColor.components, components.count >= 3
                {
                    settings.borderSecondaryColorRed = Double(components[0])
                    settings.borderSecondaryColorGreen = Double(components[1])
                    settings.borderSecondaryColorBlue = Double(components[2])
                    if components.count >= 4 {
                        settings.borderSecondaryColorAlpha = Double(components[3])
                    }
                }
            }
        )
    }

    private var effectTypeBinding: Binding<BorderEffectType> {
        Binding(
            get: {
                BorderEffectType(rawValue: settings.borderEffectType) ?? .none
            },
            set: { newValue in
                settings.borderEffectType = newValue.rawValue
            }
        )
    }

    private func syncBorderConfig() {
        controller.updateBorderConfig(BorderConfig.from(settings: settings))
    }
}
