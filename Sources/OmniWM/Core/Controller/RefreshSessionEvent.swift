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
        case .timerRefresh, .startup, .displayConfigChanged:
            return true
        default:
            return false
        }
    }

    var debounceInterval: UInt64 {
        switch self {
        case .axWindowChanged:
            return 8_000_000
        case .axWindowCreated, .axWindowFocused:
            return 4_000_000
        default:
            return 0
        }
    }
}
