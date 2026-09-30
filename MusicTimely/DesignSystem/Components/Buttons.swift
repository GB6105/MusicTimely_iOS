import SwiftUI

/// 주 버튼: sunset 그라데이션 + 흰 글자 (342 × 58).
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.text(17, .medium, relativeTo: .headline))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Capsule().fill(Palette.sunset))
            .shadow(color: Color(hex: 0xFF5046, opacity: isEnabled ? 0.27 : 0), radius: 6, y: 12)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .contentShape(Capsule())
    }
}

/// 3차 버튼: surface + raised (350 × 58).
struct TertiaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    var height: CGFloat = 58

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.text(17, .medium, relativeTo: .headline))
            .foregroundStyle(palette.ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Capsule().fill(palette.surface))
            .raised()
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(Capsule())
    }
}

/// 보조 버튼: 남색 배경 + 흰 글자 (342 × 46).
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.text(17, .medium, relativeTo: .headline))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Capsule().fill(palette.navy))
            .raised()
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Capsule())
    }
}

/// 원형 컨트롤 (44 / 60 / 84). 아이콘은 코랄 선.
struct CircleControl: View {
    @Environment(\.palette) private var palette
    var icon: String
    var size: CGFloat = 44
    var iconSize: CGFloat = 24
    /// nil이면 테마 잉크색 (back, more, close, gear)
    var tint: Color? = nil
    var label: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(tint ?? palette.ink)
                .frame(width: size, height: size)
                .background(Circle().fill(palette.surface))
                .raised()
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(Text(label))
    }
}

/// 시간 칩 (70pt 원). 선택되면 sunset.
struct DurationChip: View {
    @Environment(\.palette) private var palette
    var value: String
    var unit: String
    var isSelected: Bool
    var accessibilityText: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(value)
                    .font(AppFont.number(24, .light, relativeTo: .title2))
                    .foregroundStyle(isSelected ? .white : palette.ink)
                Text(unit)
                    .font(AppFont.number(9, .semibold, relativeTo: .caption2))
                    .foregroundStyle(isSelected ? .white : palette.muted)
            }
            .frame(width: 70, height: 70)
            .background {
                if isSelected {
                    Circle().fill(Palette.sunset).shadow(color: Color(hex: 0xFF5046, opacity: 0.3), radius: 5, y: 10)
                } else {
                    Circle().fill(palette.surface).raised()
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 화면 하단 토스트.
struct ToastView: View {
    @Environment(\.palette) private var palette
    var message: String

    var body: some View {
        Text(message)
            .font(AppFont.text(14, .medium, relativeTo: .subheadline))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(palette.charcoal.opacity(0.95)))
            .padding(.horizontal, Theme.Spacing.text)
    }
}
