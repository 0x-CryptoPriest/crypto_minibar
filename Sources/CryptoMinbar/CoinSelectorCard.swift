import SwiftUI

struct CoinSelectorCard: View {
    @ObservedObject var viewModel: TickerViewModel
    @State private var isExpanded = false
    @State private var query = ""

    private var filteredCoins: [CoinInfo] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return viewModel.coins }
        return viewModel.coins.filter { $0.symbol.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.selectedCoin.symbolName)
                        .foregroundStyle(CryptoMinbarDesign.accent)
                    Text(viewModel.selectedCoin.symbol)
                        .font(.headline)
                    Text("\(viewModel.coins.count) markets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                TextField("Search symbol", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search symbol")

                if filteredCoins.isEmpty {
                    Text("No match")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredCoins) { coin in
                                coinRow(coin)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .padding(12)
        .cardSurface(cornerRadius: CryptoMinbarDesign.compactCornerRadius)
    }

    private func coinRow(_ coin: CoinInfo) -> some View {
        let isSelected = coin.id == viewModel.selectedCoin.id
        return Button {
            select(coin)
        } label: {
            HStack {
                Text(coin.symbol)
                    .font(.callout)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CryptoMinbarDesign.accent)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .background(
                isSelected ? CryptoMinbarDesign.accent.opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
    }

    private func select(_ coin: CoinInfo) {
        viewModel.selectCoin(coin)
        query = ""
        withAnimation(.snappy(duration: 0.2)) { isExpanded = false }
    }
}
