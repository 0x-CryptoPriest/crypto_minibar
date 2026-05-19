import SwiftUI

struct RefreshBadge: View {
    let isRefreshing: Bool

    var body: some View {
        Label(isRefreshing ? "Refreshing" : "Live", systemImage: isRefreshing ? "arrow.triangle.2.circlepath" : "dot.radiowaves.left.and.right")
            .font(.caption)
            .foregroundStyle(isRefreshing ? CryptoMinbarDesign.accent : CryptoMinbarDesign.positive)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel(isRefreshing ? "Refreshing price" : "Live price")
    }
}
