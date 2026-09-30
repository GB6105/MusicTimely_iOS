import SwiftUI

/// 디자인 토큰. 색상은 Assets.xcassets(AccentColor 등)에서, 간격·모서리 값은 여기서 관리한다.
nonisolated enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
    }
}
