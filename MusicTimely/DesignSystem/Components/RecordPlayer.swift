import SwiftUI

/// 검은 레코드 (286pt 기준). 표시 장치이며 탭 가능한 재생 버튼이 아니다 (§11.1).
struct VinylRecord: View {
    var diameter: CGFloat = 286
    var showsLabelText = true

    var body: some View {
        let scale = diameter / 286
        ZStack {
            Circle().fill(Palette.vinyl)
            // 홈(groove) 동심원 28개, 3pt 간격
            ForEach(0..<28, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(i.isMultiple(of: 3) ? 0.06 : 0.035), lineWidth: 0.6 * scale)
                    .frame(width: (276 - CGFloat(i) * 6) * scale, height: (276 - CGFloat(i) * 6) * scale)
            }
            // 광택
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.clear, .white.opacity(0.12), .clear, .clear, .white.opacity(0.08), .clear],
                        center: .center, angle: .degrees(-30))
                )
                .frame(width: 282 * scale, height: 282 * scale)
            Circle().fill(Palette.sunset).frame(width: 100 * scale, height: 100 * scale)
            if showsLabelText {
                Text("SIDE A")
                    .font(AppFont.number(9 * scale, .semibold))
                    .foregroundStyle(.white)
                    .offset(y: -24 * scale)
            }
            Circle().fill(Palette.vinyl).frame(width: 8 * scale, height: 8 * scale)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .white.opacity(0.24), radius: 9 * scale, x: -7 * scale, y: -7 * scale)
        .shadow(color: .black.opacity(0.3), radius: 19 * scale, y: 24 * scale)
        .accessibilityHidden(true)
    }
}

/// 톤암. 회전축 (298, 18), 진행 중 30°, 그 외 0° (피그마 Tonearm 설명).
struct Tonearm: View {
    var engaged: Bool

    private static let metal = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xF8F8FA), location: 0), .init(color: Color(hex: 0xB0B2BE), location: 0.42),
            .init(color: Color(hex: 0xECECF1), location: 0.67), .init(color: Color(hex: 0x747782), location: 1),
        ], startPoint: .leading, endPoint: .trailing)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 거치대
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x767984)).frame(width: 14, height: 9).offset(
                x: 291, y: 163)
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x353640)).frame(width: 6, height: 13).offset(
                x: 295, y: 161)
            // 받침
            Circle().fill(Color(hex: 0x000000, opacity: 0.12)).frame(width: 32, height: 32).offset(x: 282, y: 2).blur(
                radius: 2)
            Circle().fill(Self.metal).frame(width: 28, height: 28).offset(x: 284, y: 4)
            Circle().fill(Color(hex: 0x9A9CA8)).frame(width: 14, height: 14).offset(x: 291, y: 11)
            arm
                .rotationEffect(.degrees(engaged ? 30 : 0), anchor: UnitPoint(x: 0.5, y: 22.0 / 208.0))
                .offset(x: 298 - 9, y: 18 - 22)
            Circle().fill(Color(hex: 0x5A5C66)).frame(width: 10, height: 10).offset(x: 293, y: 13)
            Circle().fill(.white.opacity(0.8)).frame(width: 3, height: 3).offset(x: 296, y: 15)
        }
        .frame(width: 326, height: 286, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    /// 축을 (9, 22)에 두는 18 × 208 팔.
    private var arm: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4).fill(Self.metal).frame(width: 18, height: 26)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0x595B66)).frame(width: 16, height: 4)
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x4D4E5A)).frame(width: 7, height: 157).offset(
                x: 1, y: 27)
            RoundedRectangle(cornerRadius: 3).fill(Self.metal).frame(width: 6, height: 162).offset(y: 22)
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x30323C)).frame(width: 14, height: 28).offset(
                x: 1, y: 175)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0x656875)).frame(width: 10, height: 15).offset(
                x: 1, y: 179)
            RoundedRectangle(cornerRadius: 1).fill(Palette.accentMid).frame(width: 10, height: 3).offset(x: 1, y: 197)
            RoundedRectangle(cornerRadius: 1).fill(Color(hex: 0xC6C7CF)).frame(width: 2, height: 5).offset(y: 203)
        }
        .frame(width: 18, height: 208, alignment: .top)
        .shadow(color: .black.opacity(0.24), radius: 2, x: 2, y: 4)
    }
}

/// 레코드 + 톤암 (326 × 286). 세션이 진행 중일 때만 돈다. 각도는 세션 경과에서 계산해 멈춤·재개가 이어진다.
struct RecordPlayer: View {
    var armEngaged: Bool
    var spinning: Bool
    var motionEnabled: Bool
    /// 주어진 시각의 세션 활성 경과(초).
    var elapsedSeconds: (Date) -> Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !(spinning && animationsOn))) { context in
                VinylRecord()
                    .rotationEffect(.degrees(angle(at: context.date)))
            }
            Tonearm(engaged: armEngaged)
                .animation(
                    animationsOn
                        ? .easeInOut(duration: armEngaged ? Theme.Motion.armEngage : Theme.Motion.armPark) : nil,
                    value: armEngaged)
        }
        .frame(width: 326, height: 286, alignment: .topLeading)
    }

    private var animationsOn: Bool { motionEnabled && !reduceMotion }

    private func angle(at date: Date) -> Double {
        guard animationsOn else { return 0 }
        let degrees = elapsedSeconds(date) * 360 / Theme.Motion.recordRevolution
        return degrees.truncatingRemainder(dividingBy: 360)
    }
}
