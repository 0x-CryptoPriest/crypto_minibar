import Foundation

struct BTCTicker: Equatable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let nameid: String
    let rank: Int
    let date: Date
    let priceUSD: Decimal
    let percentChange5m: Decimal?
    let percentChange15m: Decimal?
    let marketCapUSD: Decimal?
    let volume24: Decimal?
}
