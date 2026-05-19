import Foundation

@MainActor
final class TickerViewModel: ObservableObject {
    @Published private(set) var ticker: BTCTicker?
    @Published private(set) var coins: [CoinInfo] = [.bitcoin]
    @Published private(set) var selectedCoin: CoinInfo = .bitcoin
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false

    private let provider: MarketDataProvider
    private let refreshInterval: Duration
    private var refreshTask: Task<Void, Never>?
    private var activeRefreshTask: Task<Void, Never>?

    init(provider: MarketDataProvider = YahooFinanceProvider(), refreshInterval: Duration = .seconds(5)) {
        self.provider = provider
        self.refreshInterval = refreshInterval
    }

    deinit {
        refreshTask?.cancel()
        activeRefreshTask?.cancel()
    }

    var statusTitle: String {
        guard let ticker else {
            return "\(selectedCoin.symbol) --"
        }
        return "\(ticker.symbol) \(Self.priceFormatter.string(for: ticker.priceUSD) ?? "--")"
    }

    func start() {
        guard refreshTask == nil else {
            return
        }
        refreshTask = Task { [weak self] in
            await self?.loadAssets()
            while !Task.isCancelled {
                await self?.refreshNow()
                try? await Task.sleep(for: self?.refreshInterval ?? .seconds(5))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
    }

    func selectCoin(id: String) {
        guard let coin = coins.first(where: { $0.id == id }) else {
            return
        }
        selectCoin(coin)
    }

    func selectCoin(_ coin: CoinInfo) {
        guard coin.id != selectedCoin.id else {
            return
        }
        selectedCoin = coin
        ticker = nil
        errorMessage = nil
        activeRefreshTask?.cancel()
        activeRefreshTask = Task { [weak self] in
            await self?.refreshNow()
        }
    }

    func refreshNow() async {
        let coin = selectedCoin
        isRefreshing = true
        do {
            let fetchedTicker = try await provider.fetchTicker(id: coin.id)
            guard selectedCoin.id == coin.id else {
                isRefreshing = false
                return
            }
            ticker = fetchedTicker
            lastUpdated = Date()
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            guard selectedCoin.id == coin.id else {
                isRefreshing = false
                return
            }
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    private func loadAssets() async {
        do {
            let fetchedCoins = try await provider.fetchAssets()
            coins = fetchedCoins.isEmpty ? [.bitcoin] : fetchedCoins
            if let matchingCoin = coins.first(where: { $0.id == selectedCoin.id }) {
                selectedCoin = matchingCoin
            }
        } catch {
            coins = [.bitcoin]
            errorMessage = error.localizedDescription
        }
    }

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        return formatter
    }()
}
