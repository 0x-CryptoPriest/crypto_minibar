import Foundation

struct PriceHistory: Equatable, Sendable {
    struct Point: Equatable, Sendable {
        let date: Date
        let price: Decimal
    }

    private static let retentionDuration: TimeInterval = 20 * 60

    private(set) var points: [Point] = []

    func appending(price: Decimal, at date: Date) -> PriceHistory {
        var copy = self
        copy.points.append(Point(date: date, price: price))
        let cutoff = date.addingTimeInterval(-Self.retentionDuration)
        copy.points = copy.points.filter { $0.date >= cutoff }
        return copy
    }

    func percentChange(minutes: Double, currentPrice: Decimal, at date: Date) -> Decimal? {
        let targetDate = date.addingTimeInterval(-minutes * 60)
        let referencePoint = points.last { $0.date <= targetDate } ?? points.first
        guard let referencePoint, referencePoint.price != 0 else {
            return nil
        }
        return ((currentPrice - referencePoint.price) / referencePoint.price) * 100
    }
}
