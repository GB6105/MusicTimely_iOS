import SwiftUI

/// 잠금화면용 작은 레코드와 톤암 (피그마 Lock Screen 썸네일). 앱·위젯 확장이 함께 쓴다.
nonisolated enum MiniColors {
    static let vinyl = Color(red: 11 / 255, green: 11 / 255, blue: 13 / 255)
    static let accentStart = Color(red: 1, green: 156 / 255, blue: 63 / 255)
    static let accentMid = Color(red: 1, green: 117 / 255, blue: 68 / 255)
    static let accentEnd = Color(red: 1, green: 59 / 255, blue: 77 / 255)
    static let sunset = LinearGradient(
        colors: [accentStart, accentMid, accentEnd], startPoint: .leading, endPoint: .trailing)
    static let ink = Color(red: 38 / 255, green: 38 / 255, blue: 44 / 255)
}

struct MiniRecord: View {
    var size: CGFloat
    var showsArm = true
    var armEngaged = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                Circle().fill(MiniColors.vinyl)
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                        .padding(size * (0.08 + CGFloat(i) * 0.05))
                }
                Circle().fill(MiniColors.sunset).frame(width: size * 0.36, height: size * 0.36)
                Circle().fill(MiniColors.vinyl).frame(width: size * 0.07, height: size * 0.07)
            }
            .frame(width: size, height: size)
            if showsArm {
                Capsule()
                    .fill(Color(white: 0.78))
                    .frame(width: max(1.5, size * 0.035), height: size * 0.62)
                    .rotationEffect(.degrees(armEngaged ? 30 : 0), anchor: .top)
                    .offset(x: size * 1.02, y: size * 0.02)
            }
        }
        .frame(width: size * (showsArm ? 1.12 : 1), height: size, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}
