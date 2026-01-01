import AppKit
import ApplicationServices
import Foundation

private let perAppTimeout: TimeInterval = 0.5

@MainActor
final class AXManager {
    private static let systemUIBundleIds: Set<String> = [
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.Spotlight"
    ]

    private var appTerminationObserver: NSObjectProtocol?
    private var appLaunchObserver: NSObjectProtocol?
    var onAppLaunched: ((NSRunningApplication) -> Void)?
    var onAppTerminated: ((pid_t) -> Void)?
    private let pollIntervalNanos: UInt64 = 250_000_000
    private let pollTimeout: TimeInterval = 30

    init() {
        setupTerminationObserver()
        setupLaunchObserver()
    }

    private func setupTerminationObserver() {
        appTerminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            let pid = app.processIdentifier
            Task { @MainActor in
                self?.onAppTerminated?(pid)
                if let context = AppAXContext.contexts[pid] {
                    await context.destroy()
                }
            }
        }
    }

    private func setupLaunchObserver() {
        appLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            Task { @MainActor in
                self?.onAppLaunched?(app)
            }
        }
    }

    func cleanup() {
        if let observer = appTerminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appTerminationObserver = nil
        }
        if let observer = appLaunchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appLaunchObserver = nil
        }

        Task { @MainActor in
            for (_, context) in AppAXContext.contexts {
                await context.destroy()
            }
        }
    }

    func windowsForApp(_ app: NSRunningApplication) async -> [(AXWindowRef, pid_t, Int)] {
        guard shouldTrack(app) else { return [] }
        do {
            guard let context = try await AppAXContext.getOrCreate(app) else { return [] }
            let appWindows = try await withTimeoutOrNil(seconds: perAppTimeout) {
                try await context.getWindowsAsync()
            }
            if let windows = appWindows {
                return windows.map { ($0.0, app.processIdentifier, $0.1) }
            }
        } catch {}
        return []
    }

    func ensurePermission() async -> Bool {
        if AXIsProcessTrusted() { return true }

        let options: NSDictionary = [axTrustedCheckOptionPrompt as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)

        let deadline = Date().addingTimeInterval(pollTimeout)
        while Date() < deadline {
            if AXIsProcessTrusted() { return true }
            try? await Task.sleep(nanoseconds: pollIntervalNanos)
        }
        return AXIsProcessTrusted()
    }

    func currentWindowsAsync() async -> [(AXWindowRef, pid_t, Int)] {
        await AppAXContext.garbageCollect()

        let apps = NSWorkspace.shared.runningApplications.filter { shouldTrack($0) }

        return await withTaskGroup(of: [(AXWindowRef, pid_t, Int)].self) { group in
            for app in apps {
                group.addTask {
                    do {
                        guard let context = try await AppAXContext.getOrCreate(app) else {
                            return []
                        }

                        let appWindows = try await self.withTimeoutOrNil(seconds: perAppTimeout) {
                            try await context.getWindowsAsync()
                        }

                        if let windows = appWindows {
                            return windows.map { ($0.0, app.processIdentifier, $0.1) }
                        }
                    } catch {
                    }
                    return []
                }
            }

            var results: [(AXWindowRef, pid_t, Int)] = []
            for await appWindows in group {
                results.append(contentsOf: appWindows)
            }
            return results
        }
    }

    func applyFramesParallel(_ frames: [(pid: pid_t, windowId: Int, frame: CGRect)]) {
        var framesByPid: [pid_t: [(windowId: Int, frame: CGRect)]] = [:]

        for (pid, windowId, frame) in frames {
            framesByPid[pid, default: []].append((windowId, frame))
        }

        for (pid, appFrames) in framesByPid {
            guard let context = AppAXContext.contexts[pid] else {
                continue
            }
            context.setFramesBatchSync(appFrames)
        }
    }

    func applyPositionsViaSkyLight(_ positions: [(windowId: Int, origin: CGPoint)]) {
        let batchPositions = positions.map { (windowId: UInt32($0.windowId), origin: $0.origin) }
        SkyLight.shared.batchMoveWindows(batchPositions)
    }

    private func withTimeoutOrNil<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T? {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }

            if let result = try await group.next() {
                group.cancelAll()
                return result
            }
            return nil
        }
    }

    private func shouldTrack(_ app: NSRunningApplication) -> Bool {
        guard !app.isTerminated, app.activationPolicy != .prohibited else { return false }

        if let bundleId = app.bundleIdentifier, Self.systemUIBundleIds.contains(bundleId) {
            return false
        }

        return true
    }
}
