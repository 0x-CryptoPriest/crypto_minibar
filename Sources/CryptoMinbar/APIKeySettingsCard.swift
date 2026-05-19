import SwiftUI

struct APIKeySettingsCard: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AllTick API Key", systemImage: viewModel.hasSavedAPIKey ? "checkmark.seal.fill" : "key.fill")
                    .font(.caption)
                    .foregroundStyle(viewModel.hasSavedAPIKey ? CryptoMinbarDesign.positive : .secondary)

                Spacer()

                if viewModel.hasSavedAPIKey {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SecureField("Paste API key", text: $viewModel.apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("AllTick API key")

            HStack(spacing: 10) {
                Button("Save & Connect", systemImage: "bolt.horizontal.fill", action: viewModel.saveAPIKey)
                    .buttonStyle(.borderedProminent)

                if viewModel.hasSavedAPIKey {
                    Button("Clear", systemImage: "trash", action: viewModel.clearAPIKey)
                        .buttonStyle(.bordered)
                }

                Spacer()
            }

            Divider()

            Toggle(isOn: $viewModel.showChangeInBar) {
                Label("Show 5min % in menu bar", systemImage: "percent")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            Toggle(isOn: $viewModel.launchAtLogin) {
                Label("Launch at login", systemImage: "poweron")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            Divider()

            HStack {
                Label(viewModel.notificationStatusText, systemImage: "bell.badge")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            HStack(spacing: 10) {
                Button("Enable/Test", systemImage: "bell.fill", action: viewModel.requestNotificationPermission)
                    .buttonStyle(.bordered)

                Button("Settings", systemImage: "gearshape.fill", action: viewModel.openNotificationSettings)
                    .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: CryptoMinbarDesign.compactCornerRadius))
    }
}
