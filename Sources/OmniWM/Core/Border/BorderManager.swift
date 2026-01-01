import AppKit
import Foundation

@MainActor
final class BorderManager {
    private var borderWindow: BorderWindow?
    private var config: BorderConfig
    private var currentWindowId: Int?
    private var lastAppliedFrame: CGRect?
    private var lastAppliedWindowId: Int?

    init(config: BorderConfig = BorderConfig()) {
        self.config = config
    }

    func setEnabled(_ enabled: Bool) {
        config.enabled = enabled
        if !enabled {
            hideBorder()
        }
    }

    func updateConfig(_ newConfig: BorderConfig) {
        let wasEnabled = config.enabled
        config = newConfig

        if !config.enabled, wasEnabled {
            hideBorder()
        } else if config.enabled {
            borderWindow?.updateConfig(config)
        }
    }

    func updateFocusedWindow(frame: CGRect, windowId: Int?) {
        guard config.enabled else { return }
        guard frame.width > 0, frame.height > 0 else {
            hideBorder()
            return
        }

        if let last = lastAppliedFrame,
           let lastWid = lastAppliedWindowId,
           lastWid == windowId,
           abs(frame.origin.x - last.origin.x) < 0.5,
           abs(frame.origin.y - last.origin.y) < 0.5,
           abs(frame.width - last.width) < 0.5,
           abs(frame.height - last.height) < 0.5 {
            return
        }

        if borderWindow == nil {
            borderWindow = BorderWindow(config: config)
        }

        guard let windowId else {
            borderWindow?.orderOut(nil)
            lastAppliedFrame = nil
            lastAppliedWindowId = nil
            return
        }

        let cornerRadius = cornerRadius(for: windowId)
        let targetWid = UInt32(windowId)

        borderWindow?.update(frame: frame, windowCornerRadius: cornerRadius, targetWid: targetWid)
        borderWindow?.orderFront(nil)
        currentWindowId = windowId
        lastAppliedFrame = frame
        lastAppliedWindowId = windowId
    }

    func hideBorder() {
        borderWindow?.orderOut(nil)
        lastAppliedFrame = nil
        lastAppliedWindowId = nil
    }

    func cleanup() {
        hideBorder()
        borderWindow?.close()
        borderWindow = nil
    }

    private func cornerRadius(for windowId: Int) -> CornerRadius {
        SkyLight.shared.cornerRadii(forWindowId: windowId) ?? CornerRadius(uniform: 9)
    }
}
