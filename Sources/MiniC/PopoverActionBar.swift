import SwiftUI

struct PopoverActionBar: View {
    let isShowingSettings: Bool
    let refresh: () -> Void
    let toggleSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                .buttonStyle(.borderedProminent)

            Spacer()

            Toggle(isOn: Binding(get: { isShowingSettings }, set: { _ in toggleSettings() })) {
                Image(systemName: "gearshape")
            }
            .toggleStyle(.button)
            .help(isShowingSettings ? "Hide settings" : "Settings")
            .accessibilityLabel("Settings")

            Button(action: quit) {
                Image(systemName: "power")
            }
            .buttonStyle(.bordered)
            .help("Quit MiniC")
            .accessibilityLabel("Quit")
        }
    }
}
