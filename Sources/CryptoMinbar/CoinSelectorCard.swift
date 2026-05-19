import SwiftUI

struct CoinSelectorCard: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Market")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Coin", selection: Binding(
                get: { viewModel.selectedCoin.id },
                set: { viewModel.selectCoin(id: $0) }
            )) {
                ForEach(viewModel.coins) { coin in
                    Text("\(coin.symbol) · \(coin.name)").tag(coin.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityLabel("Selected coin")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: CryptoMinbarDesign.compactCornerRadius))
    }
}
