import AppKit

enum BorderEffectType: String, CaseIterable, Codable {
    case none
    case pulse
    case snake

    var displayName: String {
        switch self {
        case .none: "Solid"
        case .pulse: "Pulse"
        case .snake: "Snake"
        }
    }
}

struct BorderConfig: Equatable {
    var enabled: Bool
    var width: CGFloat
    var color: NSColor
    var effectType: BorderEffectType
    var pulseSpeed: CGFloat
    var snakeSpeed: CGFloat
    var snakeSecondaryColor: NSColor

    init(
        enabled: Bool = false,
        width: CGFloat = 4.0,
        color: NSColor = .systemBlue,
        effectType: BorderEffectType = .none,
        pulseSpeed: CGFloat = 1.0,
        snakeSpeed: CGFloat = 1.0,
        snakeSecondaryColor: NSColor = .systemOrange
    ) {
        self.enabled = enabled
        self.width = width
        self.color = color
        self.effectType = effectType
        self.pulseSpeed = pulseSpeed
        self.snakeSpeed = snakeSpeed
        self.snakeSecondaryColor = snakeSecondaryColor
    }

    @MainActor static func from(settings: SettingsStore) -> BorderConfig {
        let color = NSColor(
            red: CGFloat(settings.borderColorRed),
            green: CGFloat(settings.borderColorGreen),
            blue: CGFloat(settings.borderColorBlue),
            alpha: CGFloat(settings.borderColorAlpha)
        )
        let secondaryColor = NSColor(
            red: CGFloat(settings.borderSecondaryColorRed),
            green: CGFloat(settings.borderSecondaryColorGreen),
            blue: CGFloat(settings.borderSecondaryColorBlue),
            alpha: CGFloat(settings.borderSecondaryColorAlpha)
        )
        return BorderConfig(
            enabled: settings.bordersEnabled,
            width: CGFloat(settings.borderWidth),
            color: color,
            effectType: BorderEffectType(rawValue: settings.borderEffectType) ?? .none,
            pulseSpeed: CGFloat(settings.borderPulseSpeed),
            snakeSpeed: CGFloat(settings.borderSnakeSpeed),
            snakeSecondaryColor: secondaryColor
        )
    }
}
