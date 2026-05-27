import Foundation

struct OKXWebSocketProvider: TickerStreamProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func streamTicker(token: String, symbol: String) -> AsyncThrowingStream<BTCTicker, Error> {
        AsyncThrowingStream { continuation in
            guard let coin = StandardFeedProvider.okx.supportedCoins.first(where: { $0.id == symbol }),
                  let streamSymbol = StandardFeedProvider.okx.streamSymbol(for: coin),
                  let url = URL(string: "wss://ws.okx.com:8443/ws/v5/public") else {
                continuation.finish(throwing: OKXFeedError.unsupportedSymbol(symbol))
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
                              let tick = try decodeTick(from: text, expectedSymbol: streamSymbol) else {
                            continue
                        }
                        history = history.appending(price: tick.price, at: tick.date)
                        continuation.yield(coin.liveTicker(
                            price: tick.price,
                            date: tick.date,
                            history: history,
                            volume24: tick.volume24
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
        let payload = OKXSubscribeMessage(op: "subscribe", args: [.init(channel: "tickers", instId: streamSymbol)])
        let data = try JSONEncoder().encode(payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw OKXFeedError.encodingFailed
        }
        try await webSocket.send(.string(text))
    }

    private func decodeTick(from text: String, expectedSymbol: String) throws -> OKXTick? {
        let message = try JSONDecoder().decode(OKXMessage.self, from: Data(text.utf8))
        guard let first = message.data?.first,
              first.instId == expectedSymbol,
              let price = Decimal(string: first.last, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }

        let volume24 = first.vol24h.flatMap {
            Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX"))
        }
        let timestamp = Double(first.ts) ?? 0
        let date = Date(timeIntervalSince1970: timestamp / 1_000)
        return OKXTick(price: price, volume24: volume24, date: date)
    }
}

private struct OKXSubscribeMessage: Encodable {
    let op: String
    let args: [OKXSubscriptionArgument]
}

private struct OKXSubscriptionArgument: Encodable {
    let channel: String
    let instId: String
}

private struct OKXMessage: Decodable {
    let data: [OKXTickData]?
}

private struct OKXTickData: Decodable {
    let instId: String
    let last: String
    let vol24h: String?
    let ts: String
}

private struct OKXTick: Sendable {
    let price: Decimal
    let volume24: Decimal?
    let date: Date
}

enum OKXFeedError: LocalizedError {
    case encodingFailed
    case unsupportedSymbol(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Failed to encode OKX websocket request."
        case .unsupportedSymbol(let symbol):
            "OKX public websocket does not expose \(symbol) in this build."
        }
    }
}
