import SwiftUI

struct PopoverActionBar: View {
    let errorMessage: String?
    let isShowingSettings: Bool
    let refresh: () -> Void
    let toggleSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                    .buttonStyle(.borderedProminent)

                Button(isShowingSettings ? "Hide Settings" : "Settings", systemImage: "gearshape", action: toggleSettings)
                    .buttonStyle(.bordered)

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
        .frame(minHeight: 54, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
