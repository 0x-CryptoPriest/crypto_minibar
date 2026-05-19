import CoreGraphics

struct PopoverLayoutState: Equatable {
    var isShowingAPISettings: Bool
    var selectedCoinAlertCount: Int
    var hasErrorMessage: Bool
}

enum PopoverLayout {
    private static let verticalPadding = CryptoMinbarDesign.contentPadding * 2
    private static let gap = CryptoMinbarDesign.panelSpacing

    private enum ModuleHeight {
        static let priceHero: CGFloat = 148
        static let apiSettings: CGFloat = 216
        static let coinSelector: CGFloat = 70
        static let marketStats: CGFloat = 68
        static let alertsHeaderOnly: CGFloat = 48
        static let alertsEmptyExpanded: CGFloat = 132
        static let alertRow: CGFloat = 34
        static let alertAddControls: CGFloat = 42
        static let actionBar: CGFloat = 54
        static let actionBarWithError: CGFloat = 88
    }

    static func height(for state: PopoverLayoutState) -> CGFloat {
        var moduleHeights: [CGFloat] = [
            ModuleHeight.priceHero,
            ModuleHeight.coinSelector,
            ModuleHeight.marketStats,
            alertsHeight(for: state.selectedCoinAlertCount),
            state.hasErrorMessage ? ModuleHeight.actionBarWithError : ModuleHeight.actionBar
        ]

        if state.isShowingAPISettings {
            moduleHeights.insert(ModuleHeight.apiSettings, at: 1)
        }

        let gaps = CGFloat(max(moduleHeights.count - 1, 0)) * gap
        return verticalPadding + moduleHeights.reduce(0, +) + gaps
    }

    private static func alertsHeight(for alertCount: Int) -> CGFloat {
        guard alertCount > 0 else {
            return ModuleHeight.alertsEmptyExpanded
        }
        return ModuleHeight.alertsHeaderOnly
            + CGFloat(alertCount) * ModuleHeight.alertRow
            + ModuleHeight.alertAddControls
    }
}
