import SwiftUI

struct FeedSettingsCard: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Feed mode", selection: Binding(
                get: { viewModel.feedMode },
                set: { viewModel.selectFeedMode($0) }
            )) {
                ForEach(FeedMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Feed mode")

            if viewModel.feedMode == .standard {
                standardSettings
            } else {
                premiumSettings
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

    private var standardSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(
                title: "Standard · AllTick API Key",
                isSaved: viewModel.hasSavedStandardAPIKey,
                icon: viewModel.hasSavedStandardAPIKey ? "checkmark.seal.fill" : "key.fill"
            )

            SecureField("Paste AllTick API key", text: $viewModel.standardAPIKeyInput)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Standard AllTick API key")

            HStack(spacing: 10) {
                Button("Save & Connect", systemImage: "bolt.horizontal.fill", action: viewModel.saveStandardAPIKey)
                    .buttonStyle(.borderedProminent)

                if viewModel.hasSavedStandardAPIKey {
                    Button("Clear", systemImage: "trash", action: viewModel.clearStandardAPIKey)
                        .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
    }

    private var premiumSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(
                title: "Premium · User Token",
                isSaved: viewModel.hasSavedPremiumUserToken,
                icon: viewModel.hasSavedPremiumUserToken ? "checkmark.shield.fill" : "shield.fill"
            )

            SecureField("Paste user token", text: $viewModel.premiumUserTokenInput)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Premium user token")

            HStack(spacing: 10) {
                Button("Save & Connect", systemImage: "bolt.shield.fill", action: viewModel.savePremiumCredentials)
                    .buttonStyle(.borderedProminent)

                if viewModel.hasSavedPremiumUserToken {
                    Button("Clear", systemImage: "trash", action: viewModel.clearPremiumCredentials)
                        .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
    }

    private func header(title: String, isSaved: Bool, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(isSaved ? CryptoMinbarDesign.positive : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if isSaved {
                Text("Saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
