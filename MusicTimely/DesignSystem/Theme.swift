import SwiftUI

/// 디자인 토큰 (docs/design/README.md). 화면은 색·폰트·간격을 여기서만 가져온다.
nonisolated enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        /// 카드 좌우 여백
        static let card: CGFloat = 20
        /// 텍스트·버튼 좌우 여백
        static let text: CGFloat = 24
    }

    enum CornerRadius {
        static let panel: CGFloat = 26
        static let card: CGFloat = 30
    }

    enum Motion {
        static let armEngage = 0.65
        static let armPark = 0.55
        static let recordRevolution = 12.0
    }
}

/// 테마별 색 (Light / Navy / Dark).
struct Palette: Equatable, Sendable {
    var background: Color
    var surface: Color
    var field: Color
    var ink: Color
    var muted: Color
    /// 분→곡 카드 배경. Navy 테마에서만 남색.
    var featureCard: Color
    var featureInk: Color
    var featureMuted: Color
    var charcoal: Color
    var navy: Color
    var isDark: Bool

    static let accentStart = Color(hex: 0xFF9C3F)
    static let accentMid = Color(hex: 0xFF7544)
    static let accentEnd = Color(hex: 0xFF3B4D)
    static let accentOutline = Color(hex: 0xF5474F)
    static let vinyl = Color(hex: 0x0B0B0D)

    static let sunset = LinearGradient(
        stops: [
            .init(color: accentStart, location: 0), .init(color: accentMid, location: 0.48),
            .init(color: accentEnd, location: 1),
        ],
        startPoint: .leading, endPoint: .trailing)

    static let light = Palette(
        background: Color(hex: 0xECECEC), surface: Color(hex: 0xEEEEEE), field: .white,
        ink: Color(hex: 0x26262C), muted: Color(hex: 0x64656E),
        featureCard: Color(hex: 0xEEEEEE), featureInk: Color(hex: 0x26262C), featureMuted: Color(hex: 0x64656E),
        charcoal: Color(hex: 0x232429), navy: Color(hex: 0x1B1B33), isDark: false)

    static let navyTheme: Palette = {
        var p = light
        p.featureCard = Color(hex: 0x1B1B33)
        p.featureInk = .white
        p.featureMuted = Color(hex: 0xB4B5BE)
        return p
    }()

    static let dark = Palette(
        background: Color(hex: 0x26272C), surface: Color(hex: 0x26272C), field: Color(hex: 0x303138),
        ink: Color(hex: 0xF3F3F5), muted: Color(hex: 0xB4B5BE),
        featureCard: Color(hex: 0x26272C), featureInk: Color(hex: 0xF3F3F5), featureMuted: Color(hex: 0xB4B5BE),
        charcoal: Color(hex: 0x1E1F23), navy: Color(hex: 0x1B1B33), isDark: true)

    static func resolve(_ choice: ThemeChoice, scheme: ColorScheme) -> Palette {
        switch choice {
        case .light: .light
        case .navy: .navyTheme
        case .dark: .dark
        case .system: scheme == .dark ? .dark : .light
        }
    }
}

extension EnvironmentValues {
    @Entry var palette: Palette = .light
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// 한글은 IBM Plex Sans KR, 숫자·영문 강조는 Montserrat (docs/design/README.md "폰트").
enum AppFont {
    enum Weight {
        case regular, medium, bold
        var name: String {
            switch self {
            case .regular: "IBMPlexSansKR-Regular"
            case .medium: "IBMPlexSansKR-Medium"
            case .bold: "IBMPlexSansKR-Bold"
            }
        }
    }

    static func text(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.name, size: size, relativeTo: style)
    }

    static func number(_ size: CGFloat, _ weight: Font.Weight = .light, relativeTo style: Font.TextStyle = .body)
        -> Font
    {
        .custom("Montserrat", size: size, relativeTo: style).weight(weight).monospacedDigit()
    }
}
