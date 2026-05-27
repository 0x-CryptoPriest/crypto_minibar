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
            Picker("Standard source", selection: Binding(
                get: { viewModel.standardFeedProvider },
                set: { viewModel.selectStandardFeedProvider($0) }
            )) {
                ForEach(StandardFeedProvider.allCases) { provider in
                    Text(provider.label).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Standard source")

            header(
                title: viewModel.standardFeedProvider.sourceLabel,
                isSaved: !viewModel.standardFeedProvider.requiresToken || viewModel.hasSavedStandardAPIKey,
                icon: standardProviderIcon,
                statusText: standardProviderStatusText
            )

            if viewModel.standardFeedProvider.requiresToken {
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
            } else {
                Label("Public websocket source. No API key required.", systemImage: "bolt.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Reconnect", systemImage: "arrow.clockwise") {
                        Task { await viewModel.refreshNow() }
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }
        }
    }

    private var premiumSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(
                title: "Premium · User Token",
                isSaved: viewModel.hasSavedPremiumUserToken,
                icon: viewModel.hasSavedPremiumUserToken ? "checkmark.shield.fill" : "shield.fill",
                statusText: viewModel.hasSavedPremiumUserToken ? "Saved" : nil
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

    private func header(title: String, isSaved: Bool, icon: String, statusText: String?) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(isSaved ? CryptoMinbarDesign.positive : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if let statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var standardProviderIcon: String {
        if viewModel.standardFeedProvider.requiresToken {
            return viewModel.hasSavedStandardAPIKey ? "checkmark.seal.fill" : "key.fill"
        }
        return "bolt.horizontal.circle.fill"
    }

    private var standardProviderStatusText: String? {
        if viewModel.standardFeedProvider.requiresToken {
            return viewModel.hasSavedStandardAPIKey ? "Saved" : nil
        }
        return "Public"
    }
}
