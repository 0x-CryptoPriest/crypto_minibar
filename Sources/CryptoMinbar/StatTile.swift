import SwiftUI

struct StatTile: View {
    enum Tone {
        case neutral
        case positive
        case negative
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

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: CryptoMinbarDesign.compactCornerRadius))
    }
}
