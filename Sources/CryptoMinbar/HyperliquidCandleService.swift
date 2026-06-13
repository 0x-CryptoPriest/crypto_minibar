import Foundation

/// One historical OHLC candle with the time it closed.
struct PriceCandle: Equatable, Sendable {
    let closeTime: Date
    let open: Decimal
    let high: Decimal
    let low: Decimal
    let close: Decimal
}

extension PriceCandle {
    /// Convenience for callers that only care about the close (e.g. baseline change).
    init(closeTime: Date, close: Decimal) {
        self.init(closeTime: closeTime, open: close, high: close, low: close, close: close)
    }
}

extension Array where Element == PriceCandle {
    /// Aggregates fine candles into coarser OHLC buckets (e.g. 5m → 1h) so the
    /// chart shows a readable number of candlesticks. Buckets align to the epoch
    /// grid of `seconds`.
    func bucketed(bySeconds seconds: TimeInterval) -> [PriceCandle] {
        guard seconds > 0, !isEmpty else { return self }
        let ordered = sorted { $0.closeTime < $1.closeTime }
        var result: [PriceCandle] = []
        var key = Double.nan
        var open = Decimal.zero, high = Decimal.zero, low = Decimal.zero, close = Decimal.zero, time = Date()

        for candle in ordered {
            let bucket = (candle.closeTime.timeIntervalSince1970 / seconds).rounded(.down)
            if bucket != key {
                if !key.isNaN {
                    result.append(PriceCandle(closeTime: time, open: open, high: high, low: low, close: close))
                }
                key = bucket
                open = candle.open
                high = candle.high
                low = candle.low
            } else {
                high = Swift.max(high, candle.high)
                low = Swift.min(low, candle.low)
            }
            close = candle.close
            time = candle.closeTime
        }
        if !key.isNaN {
            result.append(PriceCandle(closeTime: time, open: open, high: high, low: low, close: close))
        }
        return result
    }
}

/// Historical close prices used to compute percent change over a window,
/// independent of how long the app has been running.
struct PriceBaseline: Equatable, Sendable {
    /// Candles in ascending close-time order.
    let candles: [PriceCandle]

    init(candles: [PriceCandle] = []) {
        self.candles = candles
    }

    /// Percent change of `currentPrice` versus the close ~`window` ago.
    /// Returns nil when there is no usable reference candle.
    func change(window: ChangeWindow, currentPrice: Decimal, now: Date) -> Decimal? {
        guard !candles.isEmpty else { return nil }
        let target = now.addingTimeInterval(-Double(window.minutes) * 60)
        let reference = candles.last(where: { $0.closeTime <= target }) ?? candles.first
        guard let reference, reference.close != 0 else { return nil }
        return (currentPrice - reference.close) / reference.close * 100
    }
}

protocol CandleProviding: Sendable {
    func candles(coinID: String) async throws -> [PriceCandle]
}

/// Fetches a 24h candle snapshot from Hyperliquid's public REST `info` endpoint,
/// so the change tiles are accurate the moment the app opens.
struct HyperliquidCandleService: CandleProviding {
    private let session: URLSession
    private static let lookback: TimeInterval = 24 * 60 * 60
    private static let interval = "5m"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func candles(coinID: String) async throws -> [PriceCandle] {
        // `coinID` is the Hyperliquid coin name (e.g. "BTC", "kPEPE").
        let endMs = Int(Date().timeIntervalSince1970 * 1000)
        let startMs = endMs - Int(Self.lookback * 1000)
        let payload = CandleRequest(
            type: "candleSnapshot",
            req: .init(coin: coinID, interval: Self.interval, startTime: startMs, endTime: endMs)
        )

        var request = URLRequest(url: URL(string: "https://api.hyperliquid.xyz/info")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, _) = try await session.data(for: request)
        let raw = try JSONDecoder().decode([RawCandle].self, from: data)
        return raw.compactMap { candle in
            guard let open = Decimal(exchangeString: candle.o),
                  let high = Decimal(exchangeString: candle.h),
                  let low = Decimal(exchangeString: candle.l),
                  let close = Decimal(exchangeString: candle.c) else {
                return nil
            }
            return PriceCandle(
                closeTime: Date(exchangeMilliseconds: Double(candle.closeTime)),
                open: open,
                high: high,
                low: low,
                close: close
            )
        }
    }
}

private struct CandleRequest: Encodable {
    let type: String
    let req: Req

    struct Req: Encodable {
        let coin: String
        let interval: String
        let startTime: Int
        let endTime: Int
    }
}

private struct RawCandle: Decodable {
    let closeTime: Int64
    let o: String
    let h: String
    let l: String
    let c: String

    enum CodingKeys: String, CodingKey {
        case closeTime = "T"
        case o
        case h
        case l
        case c
    }
}
