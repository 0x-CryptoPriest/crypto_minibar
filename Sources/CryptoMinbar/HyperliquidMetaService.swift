import Foundation

protocol CoinCatalogProviding: Sendable {
    /// Tradeable Hyperliquid perp names, most relevant first.
    func coins() async throws -> [String]
}

/// Fetches the Hyperliquid perp universe with per-asset context and returns the
/// most-active markets. Hyperliquid has no market cap, so 24h notional volume is
/// used as the relevance proxy; delisted assets are excluded.
struct HyperliquidMetaService: CoinCatalogProviding {
    private let session: URLSession
    private static let limit = 50

    init(session: URLSession = .shared) {
        self.session = session
    }

    func coins() async throws -> [String] {
        var request = URLRequest(url: URL(string: "https://api.hyperliquid.xyz/info")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["type": "metaAndAssetCtxs"])

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(MetaAndContexts.self, from: data)

        return zip(response.meta.universe, response.contexts)
            .filter { !($0.0.isDelisted ?? false) }
            .compactMap { asset, context -> (name: String, volume: Double)? in
                guard let volume = Double(context.dayNtlVlm) else { return nil }
                return (asset.name, volume)
            }
            .sorted { $0.volume > $1.volume }
            .prefix(Self.limit)
            .map(\.name)
    }

    /// `metaAndAssetCtxs` returns a heterogeneous JSON array: [meta, [contexts]].
    private struct MetaAndContexts: Decodable {
        let meta: Meta
        let contexts: [Context]

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            meta = try container.decode(Meta.self)
            contexts = try container.decode([Context].self)
        }
    }

    private struct Meta: Decodable {
        let universe: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let isDelisted: Bool?
    }

    private struct Context: Decodable {
        let dayNtlVlm: String
    }
}
