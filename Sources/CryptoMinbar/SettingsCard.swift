import SwiftUI

struct SettingsCard: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Hyperliquid · Public feed", systemImage: "bolt.horizontal.circle.fill")
                    .font(.caption)
                    .foregroundStyle(CryptoMinbarDesign.positive)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                Text("Public")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
