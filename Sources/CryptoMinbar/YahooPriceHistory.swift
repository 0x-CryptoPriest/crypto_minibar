import Foundation

struct YahooPriceHistory: Equatable, Sendable {
    struct Point: Equatable, Sendable {
        let timestamp: Int
        let close: Double
    }

    let points: [Point]

    func percentChange(hours: Double, currentPrice: Double) -> Decimal? {
        guard let latestTimestamp = points.last?.timestamp else {
            return nil
        }
        let targetTimestamp = latestTimestamp - Int(hours * 3_600)
        let referencePoint = points.last { $0.timestamp <= targetTimestamp } ?? points.first
        guard let referencePoint, referencePoint.close != 0 else {
            return nil
        }
        return Decimal(((currentPrice - referencePoint.close) / referencePoint.close) * 100)
    }
}
