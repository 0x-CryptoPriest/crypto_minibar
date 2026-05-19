import Foundation

protocol MarketDataProvider: Sendable {
    func fetchAssets() async throws -> [CoinInfo]
    func fetchTicker(id: String) async throws -> BTCTicker
}

enum MarketDataError: LocalizedError, Equatable {
    case invalidResponse
    case missingTicker

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Yahoo Finance returned an invalid response."
        case .missingTicker:
            "Yahoo Finance did not return a price for this coin."
        }
    }
}

struct YahooFinanceProvider: MarketDataProvider {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart")!,
        session: URLSession = YahooFinanceProvider.makeSession(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    func fetchAssets() async throws -> [CoinInfo] {
        CoinInfo.yahooCryptoUSD
    }

    func fetchTicker(id: String) async throws -> BTCTicker {
        let coin = CoinInfo.yahooCryptoUSD.first(where: { $0.id == id }) ?? .bitcoin
        let data = try await fetch(symbol: id)
        let response = try decoder.decode(YahooChartResponse.self, from: data)
        guard let result = response.chart.result.first,
              let price = result.meta.regularMarketPrice ?? result.meta.previousClose else {
            throw MarketDataError.missingTicker
        }
        let history = result.priceHistory
        return BTCTicker(
            id: coin.id,
            symbol: coin.symbol,
            name: coin.name,
            nameid: coin.nameid,
            rank: coin.rank,
            priceUSD: Decimal(price),
            percentChange1h: history.percentChange(hours: 1, currentPrice: price),
            percentChange24h: percentChange(price: price, previousClose: result.meta.previousClose),
            percentChange4h: history.percentChange(hours: 4, currentPrice: price),
            marketCapUSD: nil,
            volume24: nil
        )
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    private func fetch(symbol: String) async throws -> Data {
        let url = baseURL.appending(path: symbol)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "interval", value: "1m"),
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970 * 1000)))
        ]
        guard let requestURL = components?.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: requestURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("Mozilla/5.0 CryptoMinbar/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw MarketDataError.invalidResponse
        }
        return data
    }

    private func percentChange(price: Double, previousClose: Double?) -> Decimal? {
        guard let previousClose, previousClose != 0 else {
            return nil
        }
        return Decimal(((price - previousClose) / previousClose) * 100)
    }
}

private struct YahooChartResponse: Decodable {
    let chart: Chart

    struct Chart: Decodable {
        let result: [Result]
    }

    struct Result: Decodable {
        let meta: Meta
        let timestamp: [Int]
        let indicators: Indicators

        var priceHistory: YahooPriceHistory {
            let closes = indicators.quote.first?.close ?? []
            let points = zip(timestamp, closes).compactMap { timestamp, close -> YahooPriceHistory.Point? in
                guard let close else {
                    return nil
                }
                return YahooPriceHistory.Point(timestamp: timestamp, close: close)
            }
            return YahooPriceHistory(points: points)
        }
    }

    struct Indicators: Decodable {
        let quote: [Quote]
    }

    struct Quote: Decodable {
        let close: [Double?]
    }

    struct Meta: Decodable {
        let regularMarketPrice: Double?
        let previousClose: Double?
    }
}
