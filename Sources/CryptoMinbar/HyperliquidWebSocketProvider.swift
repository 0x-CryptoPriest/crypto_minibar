import Foundation

struct HyperliquidWebSocketProvider: TickerStreamProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func streamTicker(token: String, symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        AsyncThrowingStream { continuation in
            guard let coin = StandardFeedProvider.hyperliquid.supportedCoins.first(where: { $0.id == symbol }),
                  let streamSymbol = StandardFeedProvider.hyperliquid.streamSymbol(for: coin),
                  let url = URL(string: "wss://api.hyperliquid.xyz/ws") else {
                continuation.finish(throwing: HyperliquidFeedError.unsupportedSymbol(symbol))
                return
            }

            let webSocket = session.webSocketTask(with: url)
            let task = Task {
                var history = PriceHistory()
                webSocket.resume()

                do {
                    defer {
                        webSocket.cancel(with: .goingAway, reason: nil)
                    }

                    try await subscribe(webSocket: webSocket, streamSymbol: streamSymbol)

                    while !Task.isCancelled {
                        let message = try await webSocket.receive()
                        guard let text = message.textValue,
                              let tick = try decodeTrade(from: text, expectedSymbol: streamSymbol) else {
                            continue
                        }
                        history = history.appending(price: tick.price, at: tick.date)
                        continuation.yield(coin.liveTicker(
                            price: tick.price,
                            date: tick.date,
                            history: history,
                            volume24: nil
                        ))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                webSocket.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    private func subscribe(webSocket: URLSessionWebSocketTask, streamSymbol: String) async throws {
        let payload = HyperliquidSubscribeMessage(
            method: "subscribe",
            subscription: .init(type: "trades", coin: streamSymbol)
        )
        let data = try JSONEncoder().encode(payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw HyperliquidFeedError.encodingFailed
        }
        try await webSocket.send(.string(text))
    }

    private func decodeTrade(from text: String, expectedSymbol: String) throws -> HyperliquidTrade? {
        try HyperliquidTradeDecoder.decodeTrade(from: text, expectedSymbol: expectedSymbol)
    }
}

enum HyperliquidTradeDecoder {
    static func decodeTrade(from text: String, expectedSymbol: String) throws -> HyperliquidTrade? {
        let data = Data(text.utf8)
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(HyperliquidEnvelope.self, from: data)
        guard envelope.channel == "trades" else {
            return nil
        }

        let message = try decoder.decode(HyperliquidTradesMessage.self, from: data)
        guard let trade = message.data.first,
              trade.coin == expectedSymbol,
              let price = Decimal(string: trade.price, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }

        let date = Date(timeIntervalSince1970: TimeInterval(trade.time) / 1_000)
        return HyperliquidTrade(price: price, date: date)
    }
}

private struct HyperliquidSubscribeMessage: Encodable {
    let method: String
    let subscription: HyperliquidSubscription
}

private struct HyperliquidSubscription: Encodable {
    let type: String
    let coin: String
}

private struct HyperliquidEnvelope: Decodable {
    let channel: String?
}

private struct HyperliquidTradesMessage: Decodable {
    let channel: String
    let data: [HyperliquidTradeData]
}

private struct HyperliquidTradeData: Decodable {
    let coin: String
    let price: String
    let time: Int64

    enum CodingKeys: String, CodingKey {
        case coin
        case price = "px"
        case time
    }
}

struct HyperliquidTrade: Equatable, Sendable {
    let price: Decimal
    let date: Date
}

enum HyperliquidFeedError: LocalizedError {
    case encodingFailed
    case unsupportedSymbol(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Failed to encode Hyperliquid websocket request."
        case .unsupportedSymbol(let symbol):
            "Hyperliquid public websocket does not expose \(symbol) in this build."
        }
    }
}
