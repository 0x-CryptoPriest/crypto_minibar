import Foundation

struct BTCTicker: Equatable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let nameid: String
    let rank: Int
    let date: Date
    let price: Decimal
    let volume24: Decimal?
}
