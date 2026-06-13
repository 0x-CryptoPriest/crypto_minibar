import SwiftUI

struct MarketStatsCard: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: CryptoMinbarDesign.sectionSpacing) {
                windowTile(
                    window: viewModel.primaryWindow,
                    change: viewModel.primaryChange,
                    select: viewModel.selectPrimaryWindow
                )
                windowTile(
                    window: viewModel.secondaryWindow,
                    change: viewModel.secondaryChange,
                    select: viewModel.selectSecondaryWindow
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                Text("Change from Hyperliquid history")
                Spacer()
                Text("Updated \(updatedText)")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func windowTile(
        window: ChangeWindow,
        change: Decimal?,
        select: @escaping (ChangeWindow) -> Void
    ) -> some View {
        Menu {
            ForEach(ChangeWindow.allCases) { option in
                Button {
                    select(option)
                } label: {
                    if option == window {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            StatTile(title: window.label, value: percentText(change), tone: StatTile.Tone(for: change))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .frame(maxWidth: .infinity)
        .help("Choose the look-back window")
    }

    private var updatedText: String {
        guard let lastUpdated = viewModel.lastUpdated else {
            return "—"
        }
        return lastUpdated.formatted(date: .omitted, time: .standard)
    }

    private func percentText(_ value: Decimal?) -> String {
        guard let value else {
            return "—"
        }
        return "\(DisplayFormatters.percentString(value))%"
    }
}
