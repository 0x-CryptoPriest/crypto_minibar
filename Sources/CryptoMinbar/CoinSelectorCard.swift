import SwiftUI

struct CoinSelectorCard: View {
    @ObservedObject var viewModel: TickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Symbol")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Symbol", selection: Binding(
                get: { viewModel.selectedCoin.id },
                set: { viewModel.selectCoin(id: $0) }
            )) {
                ForEach(viewModel.coins) { coin in
                    Label("\(coin.symbol) · \(coin.name)", systemImage: coin.symbolName)
                        .tag(coin.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityLabel("Selected symbol")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: CryptoMinbarDesign.compactCornerRadius))
    }
}
