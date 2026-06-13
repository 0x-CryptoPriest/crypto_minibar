import Foundation

struct PriceAlert: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let symbol: String
    let threshold: Decimal
    let direction: Direction
    var isTriggered: Bool

    init(
        id: UUID = UUID(),
        symbol: String,
        threshold: Decimal,
        direction: Direction,
        isTriggered: Bool = false
    ) {
        self.id = id
        self.symbol = symbol
        self.threshold = threshold
        self.direction = direction
        self.isTriggered = isTriggered
    }

    enum Direction: String, CaseIterable, Codable, Sendable {
        case above
        case below

        var label: String {
            switch self {
            case .above:
                "Above"
            case .below:
                "Below"
            }
        }
    }
}
