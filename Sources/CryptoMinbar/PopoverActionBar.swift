import SwiftUI

struct PopoverActionBar: View {
    let errorMessage: String?
    let refresh: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button("Refresh Now", systemImage: "arrow.clockwise", action: refresh)
                    .buttonStyle(.borderedProminent)

                Button("Quit", systemImage: "power", action: quit)
                    .buttonStyle(.bordered)

                Spacer()
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
    }
}
