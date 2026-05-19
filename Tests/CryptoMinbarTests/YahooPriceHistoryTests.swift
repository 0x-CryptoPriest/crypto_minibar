import Foundation
import Testing
@testable import CryptoMinbar

@Suite("Yahoo price history")
struct YahooPriceHistoryTests {
    @Test("calculates one hour and four hour changes from refreshed chart points")
    func calculatesHourlyChanges() {
        let history = YahooPriceHistory(points: [
            YahooPriceHistory.Point(timestamp: 0, close: 80),
            YahooPriceHistory.Point(timestamp: 3_600, close: 90),
            YahooPriceHistory.Point(timestamp: 14_400, close: 100)
        ])

        #expect(format(history.percentChange(hours: 1, currentPrice: 120)) == "+33.33")
        #expect(format(history.percentChange(hours: 4, currentPrice: 120)) == "+50.00")
    }

    private func format(_ value: Decimal?) -> String {
        guard let value else {
            return "--"
        }
        return DisplayFormatters.percent.string(from: NSDecimalNumber(decimal: value)) ?? "--"
    }
}
