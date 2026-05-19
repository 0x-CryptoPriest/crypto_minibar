import Foundation

struct BTCTicker: Decodable, Equatable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let nameid: String
    let rank: Int
    let priceUSD: Decimal
    let percentChange1h: Decimal?
    let percentChange24h: Decimal?
    let percentChange4h: Decimal?
    let marketCapUSD: Decimal?
    let volume24: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case nameid
        case rank
        case priceUSD = "price_usd"
        case percentChange1h = "percent_change_1h"
        case percentChange24h = "percent_change_24h"
        case percentChange7d = "percent_change_7d"
        case marketCapUSD = "market_cap_usd"
        case volume24 = "volume24"
    }

    init(
        id: String,
        symbol: String,
        name: String,
        nameid: String,
        rank: Int,
        priceUSD: Decimal,
        percentChange1h: Decimal?,
        percentChange24h: Decimal?,
        percentChange4h: Decimal?,
        marketCapUSD: Decimal?,
        volume24: Decimal?
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.nameid = nameid
        self.rank = rank
        self.priceUSD = priceUSD
        self.percentChange1h = percentChange1h
        self.percentChange24h = percentChange24h
        self.percentChange4h = percentChange4h
        self.marketCapUSD = marketCapUSD
        self.volume24 = volume24
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        nameid = try container.decode(String.self, forKey: .nameid)
        rank = try container.decodeFlexibleInt(forKey: .rank)
        priceUSD = try container.decodeFlexibleDecimal(forKey: .priceUSD)
        percentChange1h = try container.decodeOptionalFlexibleDecimal(forKey: .percentChange1h)
        percentChange24h = try container.decodeOptionalFlexibleDecimal(forKey: .percentChange24h)
        percentChange4h = try container.decodeOptionalFlexibleDecimal(forKey: .percentChange7d)
        marketCapUSD = try container.decodeOptionalFlexibleDecimal(forKey: .marketCapUSD)
        volume24 = try container.decodeOptionalFlexibleDecimal(forKey: .volume24)
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        let string = try decode(String.self, forKey: key)
        guard let value = Int(string) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected integer string")
        }
        return value
    }

    func decodeFlexibleDecimal(forKey key: Key) throws -> Decimal {
        if let decimal = try? decode(Decimal.self, forKey: key) {
            return decimal
        }
        let string = try decode(String.self, forKey: key)
        guard let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected decimal string")
        }
        return value
    }

    func decodeOptionalFlexibleDecimal(forKey key: Key) throws -> Decimal? {
        guard contains(key), try !decodeNil(forKey: key) else {
            return nil
        }
        if let decimal = try? decode(Decimal.self, forKey: key) {
            return decimal
        }
        let string = try decode(String.self, forKey: key)
        guard !string.isEmpty else {
            return nil
        }
        guard let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected decimal string")
        }
        return value
    }
}
