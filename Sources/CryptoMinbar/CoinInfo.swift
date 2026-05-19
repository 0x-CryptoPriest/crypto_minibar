import Foundation

struct CoinInfo: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let nameid: String
    let rank: Int
}

extension CoinInfo {
    static let bitcoin = CoinInfo(id: "BTC-USD", symbol: "BTC", name: "Bitcoin", nameid: "bitcoin", rank: 1)

    static let yahooCryptoUSD: [CoinInfo] = [
        .bitcoin,
        CoinInfo(id: "ETH-USD", symbol: "ETH", name: "Ethereum", nameid: "ethereum", rank: 2),
        CoinInfo(id: "XRP-USD", symbol: "XRP", name: "XRP", nameid: "xrp", rank: 3),
        CoinInfo(id: "BNB-USD", symbol: "BNB", name: "BNB", nameid: "bnb", rank: 4),
        CoinInfo(id: "SOL-USD", symbol: "SOL", name: "Solana", nameid: "solana", rank: 5),
        CoinInfo(id: "DOGE-USD", symbol: "DOGE", name: "Dogecoin", nameid: "dogecoin", rank: 6),
        CoinInfo(id: "ADA-USD", symbol: "ADA", name: "Cardano", nameid: "cardano", rank: 7),
        CoinInfo(id: "TRX-USD", symbol: "TRX", name: "TRON", nameid: "tron", rank: 8),
        CoinInfo(id: "AVAX-USD", symbol: "AVAX", name: "Avalanche", nameid: "avalanche", rank: 9),
        CoinInfo(id: "LINK-USD", symbol: "LINK", name: "Chainlink", nameid: "chainlink", rank: 10)
    ]
}
