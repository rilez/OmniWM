import Foundation

enum RefreshSessionEvent {
    case axWindowCreated
    case axWindowRemoved
    case axWindowFocused
    case axWindowChanged
    case appHidden
    case appUnhidden
    case workspaceChanged
    case displayConfigChanged
    case timerRefresh
    case startup

    var requiresFullEnumeration: Bool {
        switch self {
        case .displayConfigChanged, .startup, .timerRefresh:
            true
        default:
            false
        }
    }

    var debounceInterval: UInt64 {
        switch self {
        case .axWindowChanged:
            8_000_000
        case .axWindowCreated, .axWindowFocused:
            4_000_000
        default:
            0
        }
    }
}
