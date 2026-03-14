import Foundation

enum AppBootstrapDecision: Equatable {
    case boot
    case requireSettingsReset(storedEpoch: Int?)
    case requireDisplaysHaveSeparateSpacesDisabled
}

struct DisplaysHaveSeparateSpacesRequirement {
    static let domainName = "com.apple.spaces"
    static let spansDisplaysKey = "spans-displays"

    var defaultsProvider: () -> UserDefaults?

    init(defaultsProvider: @escaping () -> UserDefaults? = {
        UserDefaults(suiteName: domainName)
    }) {
        self.defaultsProvider = defaultsProvider
    }

    func isSatisfied() -> Bool {
        guard let defaults = defaultsProvider(),
              defaults.object(forKey: Self.spansDisplaysKey) != nil
        else {
            return false
        }

        return defaults.bool(forKey: Self.spansDisplaysKey)
    }
}

enum AppBootstrapPlanner {
    static func decision(
        appDefaults: UserDefaults = .standard,
        spacesRequirement: DisplaysHaveSeparateSpacesRequirement = .init()
    ) -> AppBootstrapDecision {
        guard spacesRequirement.isSatisfied() else {
            return .requireDisplaysHaveSeparateSpacesDisabled
        }

        switch SettingsMigration.startupDecision(defaults: appDefaults) {
        case .boot:
            return .boot
        case let .requireReset(storedEpoch):
            return .requireSettingsReset(storedEpoch: storedEpoch)
        }
    }
}
