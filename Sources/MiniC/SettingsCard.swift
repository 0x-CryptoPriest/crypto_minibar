import SwiftUI

struct SettingsCard: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.subheadline.weight(.semibold))

            settingToggle("Show change in menu bar", isOn: $viewModel.showChangeInBar)
            settingToggle("Launch at login", isOn: $viewModel.launchAtLogin)

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "bell.badge")
                Text(viewModel.notificationStatusText)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Enable / Test", systemImage: "bell.fill", action: viewModel.requestNotificationPermission)
                Button("System Settings", systemImage: "gearshape", action: viewModel.openNotificationSettings)
                Spacer()
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CryptoMinbarDesign.contentPadding)
        .cardSurface()
    }

    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.callout)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
