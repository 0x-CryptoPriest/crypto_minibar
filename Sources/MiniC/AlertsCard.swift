import SwiftUI

struct AlertsCard: View {
    @ObservedObject var viewModel: TickerViewModel
    @State private var isExpanded = false
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
            Button {
                withAnimation(.snappy(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge")
                    Text("Price Alerts")
                    if !selectedCoinAlerts.isEmpty {
                        Text("\(selectedCoinAlerts.count)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .contentShape(Rectangle())
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
        .cardSurface(cornerRadius: CryptoMinbarDesign.compactCornerRadius)
    }

    private var addAlertRow: some View {
        HStack(spacing: 8) {
            Picker("Direction", selection: $direction) {
                ForEach(PriceAlert.Direction.allCases, id: \.self) { direction in
                    Text(direction.label).tag(direction)
                }
            }
            .labelsHidden()
            .fixedSize()

            TextField("Price", text: $thresholdInput)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .onSubmit(addAlert)

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

            Text("\(alert.direction.label) \(viewModel.formatPrice(alert.threshold))")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(alert.isTriggered ? .secondary : .primary)

            if alert.isTriggered {
                Text("triggered")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if alert.isTriggered {
                Button(action: { viewModel.resetAlert(alert) }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reset alert")
            }

            Button(action: { viewModel.deleteAlert(alert) }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Delete alert")
        }
    }

    private func addAlert() {
        guard let threshold = parsedThreshold else {
            return
        }
        viewModel.addAlert(threshold: threshold, direction: direction)
        thresholdInput = ""
    }
}
