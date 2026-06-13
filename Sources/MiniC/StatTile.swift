import SwiftUI

struct StatTile: View {
    enum Tone {
        case neutral
        case positive
        case negative

        /// Maps a signed change to a tone; a missing value is neutral.
        init(for value: Decimal?) {
            guard let value else {
                self = .neutral
                return
            }
            self = value < 0 ? .negative : .positive
        }
    }

    let title: String
    let value: String
    let tone: Tone

    private var color: Color {
        switch tone {
        case .neutral:
            .secondary
        case .positive:
            CryptoMinbarDesign.positive
        case .negative:
            CryptoMinbarDesign.negative
        }
    }

    private var icon: String? {
        switch tone {
        case .neutral:
            nil
        case .positive:
            "arrow.up.right"
        case .negative:
            "arrow.down.right"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                }
                Text(value)
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(color)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: CryptoMinbarDesign.compactCornerRadius)
    }
}
