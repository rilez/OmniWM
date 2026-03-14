import Foundation
import Testing

@testable import OmniWM

private func makeBootstrapTestDefaults() -> UserDefaults {
    let suiteName = "com.omniwm.bootstrap.test.\(UUID().uuidString)"
    return UserDefaults(suiteName: suiteName)!
}

@Suite struct AppBootstrapPlannerTests {
    @Test func bootstrapBlocksWhenDisplaysHaveSeparateSpacesIsEnabled() {
        let appDefaults = makeBootstrapTestDefaults()
        let spacesDefaults = makeBootstrapTestDefaults()
        spacesDefaults.set(false, forKey: DisplaysHaveSeparateSpacesRequirement.spansDisplaysKey)

        let decision = AppBootstrapPlanner.decision(
            appDefaults: appDefaults,
            spacesRequirement: DisplaysHaveSeparateSpacesRequirement {
                spacesDefaults
            }
        )

        #expect(decision == .requireDisplaysHaveSeparateSpacesDisabled)
    }

    @Test func bootstrapBlocksWhenSpacesPreferenceIsMissing() {
        let appDefaults = makeBootstrapTestDefaults()
        let spacesDefaults = makeBootstrapTestDefaults()

        let decision = AppBootstrapPlanner.decision(
            appDefaults: appDefaults,
            spacesRequirement: DisplaysHaveSeparateSpacesRequirement {
                spacesDefaults
            }
        )

        #expect(decision == .requireDisplaysHaveSeparateSpacesDisabled)
    }

    @Test func bootstrapContinuesWhenDisplaysSpanAllScreens() {
        let appDefaults = makeBootstrapTestDefaults()
        let spacesDefaults = makeBootstrapTestDefaults()
        spacesDefaults.set(true, forKey: DisplaysHaveSeparateSpacesRequirement.spansDisplaysKey)

        let decision = AppBootstrapPlanner.decision(
            appDefaults: appDefaults,
            spacesRequirement: DisplaysHaveSeparateSpacesRequirement {
                spacesDefaults
            }
        )

        #expect(decision == .boot)
    }

    @Test func bootstrapStillRunsSettingsResetGateWhenSpacesRequirementPasses() {
        let appDefaults = makeBootstrapTestDefaults()
        let spacesDefaults = makeBootstrapTestDefaults()
        spacesDefaults.set(true, forKey: DisplaysHaveSeparateSpacesRequirement.spansDisplaysKey)
        appDefaults.set(true, forKey: "settings.workspaceBarEnabled")

        let decision = AppBootstrapPlanner.decision(
            appDefaults: appDefaults,
            spacesRequirement: DisplaysHaveSeparateSpacesRequirement {
                spacesDefaults
            }
        )

        #expect(decision == .requireSettingsReset(storedEpoch: nil))
    }
}
