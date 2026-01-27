import Foundation
import GhosttyKit

struct QuakeTerminalTab: Identifiable {
    let id = UUID()
    let surface: ghostty_surface_t
    let surfaceView: GhosttySurfaceView
    var title: String = "Terminal"
}
