import SwiftUI

struct AlertsCard: View {
    @ObservedObject var viewModel: TickerViewModel
    @State private var isExpanded = true
    @State private var thresholdInput = ""
    @State private var direction: PriceAlert.Direction = .above

    private var selectedCoinAlerts: [PriceAlert] {
        viewModel.alerts.filter { $0.symbol == viewModel.selectedCoin.id }
    }

    private var parsedThreshold: Decimal? {
        Decimal(string: thresholdInput.trimmingCharacters(in: .whitespacesAndNewlines), locale: Locale(identifier: "en_US_POSIX"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Label("Price Alerts", systemImage: "bell.badge")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(selectedCoinAlerts.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if selectedCoinAlerts.isEmpty {
                        Text("No alerts for \(viewModel.selectedCoin.symbol)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(selectedCoinAlerts) { alert in
                            alertRow(alert)
                        }
                    }

                    Divider()

                    addAlertRow
                }
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: CryptoMinbarDesign.compactCornerRadius))
    }

    private var addAlertRow: some View {
        HStack(spacing: 8) {
            Picker("Direction", selection: $direction) {
                ForEach(PriceAlert.Direction.allCases, id: \.self) { direction in
                    Text(direction.label).tag(direction)
                }
            }
            .labelsHidden()
            .frame(width: 84)

            TextField("Price", text: $thresholdInput)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()

            Button(action: addAlert) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(parsedThreshold == nil)
            .help("Add alert")
        }
    }

    private func alertRow(_ alert: PriceAlert) -> some View {
        HStack(spacing: 8) {
            Image(systemName: alert.isTriggered ? "checkmark.circle.fill" : "bell.fill")
                .foregroundStyle(alert.isTriggered ? CryptoMinbarDesign.positive : CryptoMinbarDesign.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.displaySymbol(for: alert.symbol)) \(alert.direction.label.lowercased()) \(viewModel.formatPrice(alert.threshold))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(alert.isTriggered ? .secondary : .primary)

                if alert.isTriggered {
                    Text("Triggered")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if alert.isTriggered {
                Button(action: { viewModel.resetAlert(alert) }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .help("Reset alert")
            }

            Button(action: { viewModel.deleteAlert(alert) }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .help("Delete alert")
        }
        .opacity(alert.isTriggered ? 0.72 : 1)
    }

    private func addAlert() {
        guard let threshold = parsedThreshold else {
            return
        }
        viewModel.addAlert(threshold: threshold, direction: direction)
        thresholdInput = ""
    }
}
