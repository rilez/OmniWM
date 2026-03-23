import AppKit
import SwiftUI

struct MonitorSettingsTab: View {
    @Bindable var settings: SettingsStore
    @Bindable var controller: WMController

    @State private var selectedMonitor: Monitor.ID?
    @State private var connectedMonitors: [Monitor] = Monitor.current()

    private var displayLabels: [Monitor.ID: MonitorDisplayLabel] {
        MonitorSettingsTabModel.displayLabels(for: connectedMonitors)
    }

    private var selectedConnectedMonitor: Monitor? {
        guard let monitorID = selectedMonitor else { return nil }
        return connectedMonitors.first(where: { $0.id == monitorID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Monitor Arrangement")

            VStack(alignment: .leading, spacing: 12) {
                MonitorArrangementCanvas(
                    entries: $settings.spatialMonitorLayout,
                    connectedMonitors: connectedMonitors,
                    selectedMonitorId: $selectedMonitor
                )
                .frame(maxWidth: .infinity)
                .frame(height: 220)

                Text("Drag monitors to arrange them. Edges snap to neighboring monitors when close.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            SectionHeader("Selected Monitor")

            if let monitor = selectedConnectedMonitor,
               let displayLabel = displayLabels[monitor.id]
            {
                SelectedMonitorDetails(
                    settings: settings,
                    controller: controller,
                    monitor: monitor,
                    displayLabel: displayLabel
                )
            } else if connectedMonitors.isEmpty {
                Text("No monitors detected.")
                    .foregroundColor(.secondary)
            } else {
                Text("Select a monitor from the arrangement above to configure its orientation.")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            refreshConnectedMonitors()
            seedLayoutIfEmpty()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshConnectedMonitors()
        }
    }

    private func refreshConnectedMonitors() {
        let monitors = Monitor.current()
        connectedMonitors = monitors

        // Normalize selection: keep if still present, otherwise pick first.
        if let current = selectedMonitor,
           monitors.contains(where: { $0.id == current })
        {
            // Selection is still valid — keep it.
        } else {
            selectedMonitor = monitors.first?.id
        }
    }

    private func seedLayoutIfEmpty() {
        guard settings.spatialMonitorLayout.isEmpty else { return }
        let seeded = SpatialMonitorLayout.seedFromCurrentDisplays()
        settings.spatialMonitorLayout = seeded.entries
    }
}

// MARK: - MonitorBadge

private struct MonitorBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }
}

// MARK: - SelectedMonitorDetails

private struct SelectedMonitorDetails: View {
    @Bindable var settings: SettingsStore
    @Bindable var controller: WMController
    let monitor: Monitor
    let displayLabel: MonitorDisplayLabel

    private var orientationOverride: Monitor.Orientation? {
        settings.orientationSettings(for: monitor)?.orientation
    }

    private var effectiveOrientation: Monitor.Orientation {
        settings.effectiveOrientation(for: monitor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(displayLabel.name)
                    .font(.title3.weight(.semibold))

                if let duplicateBadge = displayLabel.badgeText {
                    MonitorBadge(text: duplicateBadge)
                }

                if monitor.isMain {
                    MonitorBadge(text: "Main")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Auto-detected") {
                    Text(monitor.autoOrientation.displayName)
                        .foregroundColor(.secondary)
                }

                LabeledContent("Current") {
                    Text(effectiveOrientation.displayName)
                        .fontWeight(.medium)
                }
            }

            Picker("Orientation Override", selection: Binding(
                get: { orientationOverride },
                set: { newValue in
                    updateOrientation(newValue)
                }
            )) {
                Text("Auto").tag(nil as Monitor.Orientation?)
                Text("Horizontal").tag(Monitor.Orientation.horizontal as Monitor.Orientation?)
                Text("Vertical").tag(Monitor.Orientation.vertical as Monitor.Orientation?)
            }
            .pickerStyle(.segmented)

            if orientationOverride != nil {
                Button("Reset to Auto") {
                    updateOrientation(nil)
                }
                .buttonStyle(.borderless)
            }

            Text("Override the auto-detected orientation for this monitor. Vertical monitors scroll windows top-to-bottom instead of left-to-right.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func updateOrientation(_ orientation: Monitor.Orientation?) {
        let newSettings = MonitorOrientationSettings(
            monitorName: monitor.name,
            monitorDisplayId: monitor.displayId,
            orientation: orientation
        )

        if orientation == nil {
            settings.removeOrientationSettings(for: monitor)
        } else {
            settings.updateOrientationSettings(newSettings)
        }

        controller.updateMonitorOrientations()
    }
}

// MARK: - MonitorDisplayLabel

struct MonitorDisplayLabel: Equatable {
    let name: String
    let duplicateIndex: Int?

    var badgeText: String? {
        duplicateIndex.map { "#\($0)" }
    }
}

// MARK: - MonitorSettingsTabModel

enum MonitorSettingsTabModel {
    /// Builds display labels with deterministic duplicate-name disambiguation.
    /// Sort order: left-to-right by `frame.minX`, tie-break top-to-bottom
    /// by descending `frame.minY` (AppKit y-up), final tie-break by `displayId`.
    static func displayLabels(for monitors: [Monitor]) -> [Monitor.ID: MonitorDisplayLabel] {
        let sorted = monitors.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX {
                return lhs.frame.minX < rhs.frame.minX
            }
            if lhs.frame.minY != rhs.frame.minY {
                return lhs.frame.minY > rhs.frame.minY  // top-to-bottom in AppKit (higher y = higher on screen)
            }
            return lhs.displayId < rhs.displayId
        }

        let totals = sorted.reduce(into: [String: Int]()) { counts, monitor in
            counts[monitor.name, default: 0] += 1
        }
        var nextIndexByName: [String: Int] = [:]
        var labels: [Monitor.ID: MonitorDisplayLabel] = [:]

        for monitor in sorted {
            nextIndexByName[monitor.name, default: 0] += 1
            let total = totals[monitor.name, default: 0]
            let duplicateIndex = total > 1 ? nextIndexByName[monitor.name] : nil
            labels[monitor.id] = MonitorDisplayLabel(name: monitor.name, duplicateIndex: duplicateIndex)
        }

        return labels
    }
}

// MARK: - Monitor.Orientation Display

extension Monitor.Orientation {
    var displayName: String {
        switch self {
        case .horizontal: "Horizontal"
        case .vertical: "Vertical"
        }
    }
}
