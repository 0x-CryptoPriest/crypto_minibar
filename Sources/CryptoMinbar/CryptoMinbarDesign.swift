import SwiftUI

enum CryptoMinbarDesign {
    static let panelWidth: CGFloat = 320
    static let sectionSpacing: CGFloat = 10
    static let contentPadding: CGFloat = 14
    static let cardCornerRadius: CGFloat = 12
    static let compactCornerRadius: CGFloat = 10

    static let positive = Color.green
    static let negative = Color.red
    static let accent = Color.accentColor
}

extension View {
    /// The standard card surface used by the popover sections.
    func cardSurface(cornerRadius: CGFloat = CryptoMinbarDesign.cardCornerRadius) -> some View {
        background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
