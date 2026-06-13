import Foundation

/// A selectable look-back window for the percent-change tiles.
enum ChangeWindow: String, CaseIterable, Codable, Identifiable, Sendable {
    case m15
    case h1
    case h24

    var id: String { rawValue }

    /// Window length in minutes, used to locate the historical reference price.
    var minutes: Int {
        switch self {
        case .m15: 15
        case .h1: 60
        case .h24: 1440
        }
    }

    var label: String {
        switch self {
        case .m15: "15m"
        case .h1: "1h"
        case .h24: "24h"
        }
    }
}
