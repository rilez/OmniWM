import Foundation
import Testing

@testable import OmniWM

@Suite(.serialized) @MainActor struct SettingsViewTests {
    @Test func exportStatusMessagesMatchConfigWorkflowCopy() {
        #expect(ExportStatus.exported(.full).message == "Editable config exported")
        #expect(ExportStatus.exported(.compact).message == "Compact backup exported")
        #expect(ExportStatus.imported.message == "Settings imported")
        #expect(ExportStatus.created.message == "Settings file created")
        #expect(ExportStatus.revealed.message == "Settings file revealed in Finder")
        #expect(ExportStatus.opened.message == "Settings file opened")
    }

    @Test func createActionWritesCanonicalSettingsFile() throws {
        let controller = makeLayoutPlanTestController()
        let settings = controller.settings
        let exportURL = SettingsStore.exportURL
        defer { try? FileManager.default.removeItem(at: exportURL) }
        try? FileManager.default.removeItem(at: exportURL)

        let status = try ConfigFileWorkflow.perform(.create, settings: settings, controller: controller)

        #expect(status == .created)
        #expect(settings.settingsFileExists == true)
    }

    @Test func revealActionCreatesMissingFileAndReportsRevealed() throws {
        let controller = makeLayoutPlanTestController()
        let settings = controller.settings
        let exportURL = SettingsStore.exportURL
        defer { try? FileManager.default.removeItem(at: exportURL) }
        try? FileManager.default.removeItem(at: exportURL)
        var revealedURLs: [[URL]] = []

        let status = try ConfigFileWorkflow.perform(
            .reveal,
            settings: settings,
            controller: controller,
            revealFile: { revealedURLs.append($0) }
        )

        #expect(status == .revealed)
        #expect(settings.settingsFileExists == true)
        #expect(revealedURLs == [[SettingsStore.exportURL]])
    }

    @Test func openActionUsesInjectedOpenHandler() throws {
        let controller = makeLayoutPlanTestController()
        let settings = controller.settings
        let exportURL = SettingsStore.exportURL
        defer { try? FileManager.default.removeItem(at: exportURL) }
        try? FileManager.default.removeItem(at: exportURL)
        var openedURLs: [URL] = []

        let status = try ConfigFileWorkflow.perform(
            .open,
            settings: settings,
            controller: controller,
            openFile: {
                openedURLs.append($0)
                return true
            }
        )

        #expect(status == .opened)
        #expect(settings.settingsFileExists == true)
        #expect(openedURLs == [SettingsStore.exportURL])
    }

    @Test func importActionMergesSettingsFileIntoControllerSettings() throws {
        let sourceController = makeLayoutPlanTestController()
        sourceController.settings.focusFollowsWindowToMonitor = true
        sourceController.settings.commandPaletteLastMode = .menu
        try sourceController.settings.exportSettings(mode: .full)
        defer { try? FileManager.default.removeItem(at: SettingsStore.exportURL) }

        let targetController = makeLayoutPlanTestController()
        targetController.settings.focusFollowsWindowToMonitor = false
        targetController.settings.commandPaletteLastMode = .windows

        let status = try ConfigFileWorkflow.perform(
            .import,
            settings: targetController.settings,
            controller: targetController
        )

        #expect(status == .imported)
        #expect(targetController.settings.focusFollowsWindowToMonitor == true)
        #expect(targetController.settings.commandPaletteLastMode == .menu)
    }
}
