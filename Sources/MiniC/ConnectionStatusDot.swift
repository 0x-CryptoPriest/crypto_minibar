import SwiftUI

/// Fixed-size connection indicator: green = live, pulsing yellow = connecting /
/// reconnecting, red = offline. Fixed size so switching symbols never shifts
/// the surrounding layout.
struct ConnectionStatusDot: View {
    let state: ConnectionState

    private var color: Color {
        switch state {
        case .live: CryptoMinbarDesign.positive
        case .connecting, .reconnecting: .yellow
        case .offline: CryptoMinbarDesign.negative
        }
    }

    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 8))
            .foregroundStyle(color)
            .symbolEffect(.pulse, options: .repeating, isActive: state.isPulsing)
            .frame(width: 12, height: 12)
            .help(state.label)
            .accessibilityLabel("Connection: \(state.label)")
    }
}
