import Foundation

enum FeedMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case standard
    case premium

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard:
            "Standard"
        case .premium:
            "Premium"
        }
    }

    var sourceLabel: String {
        switch self {
        case .standard:
            "Public feed"
        case .premium:
            "Private feed"
        }
    }

    var symbolName: String {
        switch self {
        case .standard:
            "bolt.horizontal.circle.fill"
        case .premium:
            "shield.lefthalf.filled"
        }
    }
}
