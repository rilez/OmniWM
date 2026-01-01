import AppKit
import ApplicationServices
import Foundation

final class AppAXContext: @unchecked Sendable {
    let pid: pid_t
    let bundleId: String?
    let nsApp: NSRunningApplication

    private let axApp: ThreadGuardedValue<AXUIElement>
    private let windows: ThreadGuardedValue<[Int: AXUIElement]>
    private var thread: Thread?
    private var setFrameJobs: [Int: RunLoopJob] = [:]
    private let axObserver: ThreadGuardedValue<AXObserver?>
    private let subscribedWindowIds: ThreadGuardedValue<Set<Int>>

    var lastNativeFocusedWindowId: Int?

    private var windowsCount: Int = 0

    @MainActor private static var focusJob: RunLoopJob?
    @MainActor static var onWindowDestroyed: ((pid_t, Int) -> Void)?
    @MainActor static var onWindowDestroyedUnknown: (() -> Void)?
    @MainActor static var onFocusedWindowChanged: ((pid_t) -> Void)?

    @MainActor static var contexts: [pid_t: AppAXContext] = [:]
    @MainActor private static var wipPids: Set<pid_t> = []

    private init(
        _ nsApp: NSRunningApplication,
        _ axApp: AXUIElement,
        _ observer: AXObserver?,
        _ thread: Thread
    ) {
        self.nsApp = nsApp
        pid = nsApp.processIdentifier
        bundleId = nsApp.bundleIdentifier
        self.axApp = .init(axApp)
        windows = .init([:])
        axObserver = .init(observer)
        subscribedWindowIds = .init([])
        self.thread = thread
    }

    @MainActor
    static func getOrCreate(_ nsApp: NSRunningApplication) async throws -> AppAXContext? {
        let pid = nsApp.processIdentifier

        if pid == ProcessInfo.processInfo.processIdentifier { return nil }

        if let existing = contexts[pid] { return existing }

        try Task.checkCancellation()
        if !wipPids.insert(pid).inserted {
            try await Task.sleep(nanoseconds: 100_000_000)
            return try await getOrCreate(nsApp)
        }

        let thread = Thread {
            $appThreadToken.withValue(AppThreadToken(pid: pid, bundleId: nsApp.bundleIdentifier)) {
                let axApp = AXUIElementCreateApplication(pid)

                var observer: AXObserver?
                AXObserverCreate(pid, axWindowDestroyedCallback, &observer)

                if let obs = observer {
                    CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
                }

                var focusObserver: AXObserver?
                AXObserverCreate(pid, axFocusedWindowChangedCallback, &focusObserver)

                if let focusObs = focusObserver {
                    AXObserverAddNotification(
                        focusObs,
                        axApp,
                        kAXFocusedWindowChangedNotification as CFString,
                        nil
                    )
                    CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(focusObs), .defaultMode)
                }

                let context = AppAXContext(nsApp, axApp, observer, Thread.current)

                Task { @MainActor in
                    contexts[pid] = context
                    wipPids.remove(pid)
                }

                let port = NSMachPort()
                RunLoop.current.add(port, forMode: .default)

                CFRunLoopRun()
            }
        }
        thread.name = "OmniWM-AX-\(nsApp.bundleIdentifier ?? "pid:\(pid)")"
        thread.start()

        let startTime = Date()
        let maxWait: TimeInterval = 2.0

        while contexts[pid] == nil, wipPids.contains(pid) {
            try Task.checkCancellation()
            if Date().timeIntervalSince(startTime) > maxWait {
                wipPids.remove(pid)
                return nil
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        return contexts[pid]
    }

    func getWindowsAsync() async throws -> [(AXWindowRef, Int)] {
        guard let thread else { return [] }

        let (results, deadWindowIds) = try await thread.runInLoop { [
            axApp,
            windows,
            nsApp,
            axObserver,
            subscribedWindowIds
        ] job -> (
            [(AXWindowRef, Int)],
            [Int]
        ) in
            var results: [(AXWindowRef, Int)] = []

            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                axApp.value,
                kAXWindowsAttribute as CFString,
                &value
            )

            guard result == .success, let windowElements = value as? [AXUIElement] else {
                return (results, [])
            }

            let oldWindowIds = Set(windows.value.keys)
            var newWindows: [Int: AXUIElement] = [:]

            for element in windowElements {
                try job.checkCancellation()

                var windowIdRaw: CGWindowID = 0
                let idResult = _AXUIElementGetWindow(element, &windowIdRaw)
                let windowId = Int(windowIdRaw)
                guard idResult == .success else { continue }

                var roleValue: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(
                    element,
                    kAXRoleAttribute as CFString,
                    &roleValue
                )
                guard roleResult == .success,
                      let role = roleValue as? String,
                      role == kAXWindowRole as String else { continue }

                let axRef = AXWindowRef(id: UUID(), element: element)
                let windowType = AXWindowService.windowType(
                    axRef,
                    appPolicy: nsApp.activationPolicy,
                    bundleId: nsApp.bundleIdentifier
                )
                guard windowType == .tiling else { continue }

                newWindows[windowId] = element
                results.append((axRef, windowId))

                if !subscribedWindowIds.value.contains(windowId), let obs = axObserver.value {
                    let subResult = AXObserverAddNotification(
                        obs,
                        element,
                        kAXUIElementDestroyedNotification as CFString,
                        nil
                    )
                    if subResult == .success {
                        subscribedWindowIds.value.insert(windowId)
                    }
                }
            }

            let newWindowIds = Set(newWindows.keys)
            let deadIds = Array(oldWindowIds.subtracting(newWindowIds))

            for deadId in deadIds {
                subscribedWindowIds.value.remove(deadId)
            }

            windows.value = newWindows
            return (results, deadIds)
        }

        for deadWindowId in deadWindowIds {
            setFrameJobs.removeValue(forKey: deadWindowId)?.cancel()
        }

        windowsCount = results.count
        return results
    }

    func setFrame(windowId: Int, frame: CGRect) {
        setFrameJobs[windowId]?.cancel()
        setFrameJobs[windowId] = thread?.runInLoopAsync { [windows] _ in
            guard let element = windows.value[windowId] else { return }
            let axRef = AXWindowRef(id: UUID(), element: element)
            try? AXWindowService.setFrame(axRef, frame: frame)
        }
    }

    func setFramesBatch(_ frames: [(windowId: Int, frame: CGRect)]) {
        guard let thread else { return }

        for (windowId, _) in frames {
            setFrameJobs[windowId]?.cancel()
        }

        thread.runInLoopAsync { [axApp, windows] job in
            let enhancedUIKey = "AXEnhancedUserInterface" as CFString
            var wasEnabled = false
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp.value, enhancedUIKey, &value) == .success,
               let boolValue = value as? Bool
            {
                wasEnabled = boolValue
            }

            if wasEnabled {
                AXUIElementSetAttributeValue(axApp.value, enhancedUIKey, kCFBooleanFalse)
            }

            defer {
                if wasEnabled {
                    AXUIElementSetAttributeValue(axApp.value, enhancedUIKey, kCFBooleanTrue)
                }
            }

            for (windowId, frame) in frames {
                if job.isCancelled { break }
                guard let element = windows.value[windowId] else { continue }
                let axRef = AXWindowRef(id: UUID(), element: element)
                try? AXWindowService.setFrame(axRef, frame: frame)
            }
        }
    }

    func setFramesBatchSync(_ frames: [(windowId: Int, frame: CGRect)]) {
        guard let thread else { return }

        for (windowId, _) in frames {
            setFrameJobs[windowId]?.cancel()
        }

        thread.runInLoopSync { [axApp, windows] in
            let enhancedUIKey = "AXEnhancedUserInterface" as CFString
            var wasEnabled = false
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp.value, enhancedUIKey, &value) == .success,
               let boolValue = value as? Bool
            {
                wasEnabled = boolValue
            }

            if wasEnabled {
                AXUIElementSetAttributeValue(axApp.value, enhancedUIKey, kCFBooleanFalse)
            }

            defer {
                if wasEnabled {
                    AXUIElementSetAttributeValue(axApp.value, enhancedUIKey, kCFBooleanTrue)
                }
            }

            for (windowId, frame) in frames {
                guard let element = windows.value[windowId] else { continue }
                let axRef = AXWindowRef(id: UUID(), element: element)
                try? AXWindowService.setFrame(axRef, frame: frame)
            }
        }
    }

    @MainActor
    func focus(windowId: Int) {
        AppAXContext.focusJob?.cancel()
        lastNativeFocusedWindowId = windowId
        let wid = UInt32(windowId)
        var psn = ProcessSerialNumber()
        guard GetProcessForPID(pid, &psn) == noErr else { return }
        _ = _SLPSSetFrontProcessWithOptions(&psn, wid, kCPSUserGenerated)
        makeKeyWindow(psn: &psn, windowId: wid)
    }

    func destroy() async {
        _ = await Task { @MainActor [pid] in
            _ = AppAXContext.contexts.removeValue(forKey: pid)
        }.result

        for (_, job) in setFrameJobs {
            job.cancel()
        }
        setFrameJobs = [:]

        thread?.runInLoopAsync { [windows, axApp, axObserver, subscribedWindowIds] _ in
            if let obs = axObserver.valueIfExists.flatMap({ $0 }) {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
            }
            subscribedWindowIds.destroy()
            axObserver.destroy()
            windows.destroy()
            axApp.destroy()
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        thread = nil
    }

    @MainActor
    static func garbageCollect() async {
        for (_, context) in contexts {
            if context.nsApp.isTerminated {
                await context.destroy()
            }
        }
    }
}

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ out: UnsafeMutablePointer<Int>) -> AXError

private func axWindowDestroyedCallback(
    _: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _: UnsafeMutableRawPointer?
) {
    guard (notification as String) == (kAXUIElementDestroyedNotification as String) else { return }

    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return }

    var windowIdRaw: CGWindowID = 0
    _ = _AXUIElementGetWindow(element, &windowIdRaw)
    let windowId = Int(windowIdRaw)

    DispatchQueue.main.async {
        if windowId != 0 {
            AppAXContext.onWindowDestroyed?(pid, windowId)
        } else {
            AppAXContext.onWindowDestroyedUnknown?()
        }
    }
}

private func axFocusedWindowChangedCallback(
    _: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _: UnsafeMutableRawPointer?
) {
    guard (notification as String) == (kAXFocusedWindowChangedNotification as String) else { return }

    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return }

    DispatchQueue.main.async {
        AppAXContext.onFocusedWindowChanged?(pid)
    }
}
