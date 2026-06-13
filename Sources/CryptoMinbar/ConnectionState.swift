import Foundation

/// Live data-feed connection state, surfaced as a colored status dot.
enum ConnectionState: Equatable, Sendable {
    case connecting    // first connect / switching symbol
    case live          // receiving ticks
    case reconnecting  // dropped after being live, retrying
    case offline       // repeated failures — can't reach the feed

    /// Yellow states pulse to signal "in progress".
    var isPulsing: Bool {
        self == .connecting || self == .reconnecting
    }

    var label: String {
        switch self {
        case .connecting: "Connecting…"
        case .live: "Live"
        case .reconnecting: "Reconnecting…"
        case .offline: "No connection"
        }
    }
}
