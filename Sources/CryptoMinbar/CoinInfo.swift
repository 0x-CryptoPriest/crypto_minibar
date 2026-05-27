import Foundation

struct CoinInfo: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let nameid: String
    let rank: Int
    let market: Market
    let quoteEndpoint: QuoteEndpoint

    var symbolName: String {
        switch market {
        case .forex:
            return "yensign.arrow.circlepath"
        case .metal:
            return "circle.hexagongrid.circle"
        case .energy:
            return "fuelpump.fill"
        case .crypto:
            return "bitcoinsign.circle.fill"
        case .index:
            return "chart.line.uptrend.xyaxis"
        case .stock:
            return "building.2.crop.circle"
        }
    }
}

extension CoinInfo {
    enum Market: String, Codable, Sendable {
        case forex = "Forex"
        case metal = "Precious Metal"
        case energy = "Energy"
        case crypto = "Crypto"
        case index = "Index"
        case stock = "Stock"
    }

    enum QuoteEndpoint: String, Codable, Sendable {
        case forexCryptoCommodity
        case stock

        var url: URL {
            switch self {
            case .forexCryptoCommodity:
                URL(string: "wss://quote.alltick.co/quote-b-ws-api")!
            case .stock:
                URL(string: "wss://quote.alltick.co/quote-stock-b-ws-api")!
            }
        }
    }

    static let bitcoin = CoinInfo(
        id: "BTCUSDT",
        symbol: "BTC/USDT",
        name: "Bitcoin/Tether",
        nameid: "bitcoin-tether",
        rank: 5,
        market: .crypto,
        quoteEndpoint: .forexCryptoCommodity
    )

    static let ethereum = CoinInfo(
        id: "ETHUSDT",
        symbol: "ETH/USDT",
        name: "Ethereum/Tether",
        nameid: "ethereum-tether",
        rank: 11,
        market: .crypto,
        quoteEndpoint: .forexCryptoCommodity
    )

    static let solana = CoinInfo(
        id: "SOLUSDT",
        symbol: "SOL/USDT",
        name: "Solana/Tether",
        nameid: "solana-tether",
        rank: 12,
        market: .crypto,
        quoteEndpoint: .forexCryptoCommodity
    )

    static let allTickSymbols: [CoinInfo] = [
        CoinInfo(
            id: "USDJPY",
            symbol: "USD/JPY",
            name: "US Dollar / Japanese Yen",
            nameid: "usd-jpy",
            rank: 1,
            market: .forex,
            quoteEndpoint: .forexCryptoCommodity
        ),
        CoinInfo(
            id: "GOLD",
            symbol: "Gold",
            name: "Gold",
            nameid: "gold",
            rank: 2,
            market: .metal,
            quoteEndpoint: .forexCryptoCommodity
        ),
        CoinInfo(
            id: "USOIL",
            symbol: "USOil",
            name: "US Oil",
            nameid: "us-oil",
            rank: 3,
            market: .energy,
            quoteEndpoint: .forexCryptoCommodity
        ),
        CoinInfo(
            id: "HSI.HK",
            symbol: "HSI",
            name: "Hang Seng Index",
            nameid: "hang-seng-index",
            rank: 4,
            market: .index,
            quoteEndpoint: .stock
        ),
        .bitcoin,
        CoinInfo(
            id: ".DJI.US",
            symbol: "DJIA",
            name: "Dow Jones Industrial Average",
            nameid: "dow-jones-industrial-average",
            rank: 6,
            market: .index,
            quoteEndpoint: .stock
        ),
        CoinInfo(
            id: "TSLA.US",
            symbol: "TSLA",
            name: "Tesla",
            nameid: "tesla",
            rank: 7,
            market: .stock,
            quoteEndpoint: .stock
        ),
        CoinInfo(
            id: "700.HK",
            symbol: "Tencent",
            name: "Tencent Holdings",
            nameid: "tencent-holdings",
            rank: 8,
            market: .stock,
            quoteEndpoint: .stock
        ),
        CoinInfo(
            id: "000001.SH",
            symbol: "SSE",
            name: "SSE Composite Index",
            nameid: "sse-composite-index",
            rank: 9,
            market: .index,
            quoteEndpoint: .stock
        ),
        CoinInfo(
            id: "399001.SZ",
            symbol: "SZSE",
            name: "SZSE Component Index",
            nameid: "szse-component-index",
            rank: 10,
            market: .index,
            quoteEndpoint: .stock
        )
    ]

    static let premiumSymbols: [CoinInfo] = [
        .bitcoin
    ]

    static let exchangeSymbols: [CoinInfo] = [
        .bitcoin,
        .ethereum,
        .solana
    ]
}
