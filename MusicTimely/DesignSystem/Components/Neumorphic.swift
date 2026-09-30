import SwiftUI

/// 돌출 그림자 (raised.light / raised.dark).
struct RaisedModifier: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        if palette.isDark {
            content
                .shadow(color: .white.opacity(0.05), radius: 8, x: -7, y: -7)
                .shadow(color: .black.opacity(0.5), radius: 11, x: 9, y: 11)
        } else {
            content
                .shadow(color: .white.opacity(0.95), radius: 10, x: -9, y: -9)
                .shadow(color: Color(hex: 0x92949B, opacity: 0.38), radius: 13, x: 10, y: 12)
        }
    }
}

extension View {
    func raised() -> some View { modifier(RaisedModifier()) }

    /// 오목한 면 (inset.light / inset.dark).
    func insetSurface(cornerRadius: CGFloat) -> some View { modifier(InsetModifier(cornerRadius: cornerRadius)) }
}

struct InsetModifier: ViewModifier {
    @Environment(\.palette) private var palette
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let dark = palette.isDark ? Color.black.opacity(0.5) : Color(hex: 0x92949B, opacity: 0.35)
        let light = palette.isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.95)
        content
            .background(shape.fill(palette.surface))
            .overlay(
                shape.stroke(dark, lineWidth: 6).blur(radius: 5).offset(x: 3, y: 3).mask(
                    shape.fill(
                        LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
            )
            .overlay(
                shape.stroke(light, lineWidth: 6).blur(radius: 5).offset(x: -3, y: -3).mask(
                    shape.fill(
                        LinearGradient(colors: [.clear, .black], startPoint: .topLeading, endPoint: .bottomTrailing)))
            )
            .clipShape(shape)
    }
}
