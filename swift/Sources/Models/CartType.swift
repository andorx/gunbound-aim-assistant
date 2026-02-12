import Foundation

/// Cart type affects how the prediction trajectory is displayed
enum CartType: String, CaseIterable {
    case `default`
    case malite

    /// Display name for UI (e.g. dropdown labels)
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .malite: return "Malite"
        }
    }
}
