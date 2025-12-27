import AppKit
import Foundation

@MainActor
final class AppInfoCache {
    struct AppInfo {
        let name: String
        let bundleId: String?
        let icon: NSImage?
        let activationPolicy: NSApplication.ActivationPolicy?
    }

    private var cache: [pid_t: AppInfo] = [:]

    func info(for pid: pid_t) -> AppInfo {
        if let cached = cache[pid] {
            return cached
        }
        let app = NSRunningApplication(processIdentifier: pid)
        let info = AppInfo(
            name: app?.localizedName ?? "Unknown",
            bundleId: app?.bundleIdentifier,
            icon: app?.icon,
            activationPolicy: app?.activationPolicy
        )
        cache[pid] = info
        return info
    }

    func name(for pid: pid_t) -> String {
        info(for: pid).name
    }

    func bundleId(for pid: pid_t) -> String? {
        info(for: pid).bundleId
    }

    func icon(for pid: pid_t) -> NSImage? {
        info(for: pid).icon
    }

    func activationPolicy(for pid: pid_t) -> NSApplication.ActivationPolicy? {
        info(for: pid).activationPolicy
    }

    func invalidate(pid: pid_t) {
        cache.removeValue(forKey: pid)
    }

    func invalidateAll() {
        cache.removeAll()
    }
}
