import Charts
import SwiftUI

/// Compact 24h candlestick chart drawn from the candles the app already fetched
/// for the change baseline (aggregated to hourly OHLC; no extra network).
struct PriceChartCard: View {
    let candles: [PriceCandle]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last 24h · 1h candles")
                .font(.caption)
                .foregroundStyle(.secondary)

            if candles.count >= 2, let domain = yDomain {
                Chart {
                    // Plot by index so candles are evenly spaced regardless of
                    // the (possibly partial) last bucket's time gap — a
                    // time-proportional axis overlaps the final candles.
                    ForEach(Array(candles.enumerated()), id: \.element.closeTime) { index, candle in
                        // High–low wick.
                        RuleMark(
                            x: .value("Candle", index),
                            yStart: .value("Low", price(candle.low)),
                            yEnd: .value("High", price(candle.high))
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .foregroundStyle(color(for: candle))

                        // Open–close body (thicker rule reads as the candle body).
                        RuleMark(
                            x: .value("Candle", index),
                            yStart: .value("Open", price(candle.open)),
                            yEnd: .value("Close", price(candle.close))
                        )
                        .lineStyle(StrokeStyle(lineWidth: 5, lineCap: .round))
                        .foregroundStyle(color(for: candle))
                    }
                }
                .chartXScale(domain: -0.7...(Double(candles.count - 1) + 0.7))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: domain)
                .frame(height: 68)
                .accessibilityLabel("24 hour candlestick chart")
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(height: 68)
                    .overlay(
                        Text("Loading 24h history…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .padding(CryptoMinbarDesign.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func color(for candle: PriceCandle) -> Color {
        candle.close < candle.open ? CryptoMinbarDesign.negative : CryptoMinbarDesign.positive
    }

    private func price(_ value: Decimal) -> Double {
        (value as NSDecimalNumber).doubleValue
    }

    /// Fit the scale to the actual high/low range (with a little padding) so the
    /// movement fills the chart instead of looking like a flat line.
    private var yDomain: ClosedRange<Double>? {
        let lows = candles.map { price($0.low) }
        let highs = candles.map { price($0.high) }
        guard let low = lows.min(), let high = highs.max(), low < high else {
            return nil
        }
        let padding = (high - low) * 0.08
        return (low - padding)...(high + padding)
    }
}
