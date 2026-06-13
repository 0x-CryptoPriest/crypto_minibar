import Foundation

protocol CoinCatalogProviding: Sendable {
    /// Tradeable Hyperliquid perp names, delisted assets excluded.
    func coins() async throws -> [String]
}

/// Fetches the Hyperliquid perp universe from the public REST `info` endpoint.
struct HyperliquidMetaService: CoinCatalogProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func coins() async throws -> [String] {
        var request = URLRequest(url: URL(string: "https://api.hyperliquid.xyz/info")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["type": "meta"])

        let (data, _) = try await session.data(for: request)
        let meta = try JSONDecoder().decode(Meta.self, from: data)
        return meta.universe
            .filter { !($0.isDelisted ?? false) }
            .map(\.name)
    }

    private struct Meta: Decodable {
        let universe: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let isDelisted: Bool?
    }
}
