import SwiftUI

/// 배정 카드의 분→곡 다이얼 (132pt). 곡 분량만큼 호를 나눈다.
struct SongDial: View {
    @Environment(\.palette) private var palette
    var minutesText: String
    var units: Int

    var body: some View {
        let count = min(max(units, 1), 12)
        let gap = count == 1 ? 0.0 : 0.035
        ZStack {
            // 카드 색이 표면과 다르면(Navy) 카드 위에 어두운 홈을 판다.
            if palette.featureCard == palette.surface {
                Circle().fill(palette.surface).frame(width: 132, height: 132).insetSurface(cornerRadius: 66)
            } else {
                Circle().fill(Color.black.opacity(0.28)).frame(width: 132, height: 132)
            }
            ForEach(0..<count, id: \.self) { i in
                let start = Double(i) / Double(count) + gap / 2
                let end = Double(i + 1) / Double(count) - gap / 2
                Circle()
                    .trim(from: start, to: end)
                    .stroke(
                        AngularGradient(
                            colors: [Palette.accentStart, Palette.accentMid, Palette.accentEnd, Palette.accentStart],
                            center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 104, height: 104)
            }
            VStack(spacing: 0) {
                Text(minutesText)
                    .font(AppFont.number(38, .light, relativeTo: .largeTitle))
                    .foregroundStyle(palette.featureInk)
                    .minimumScaleFactor(0.6)
                Text("MIN")
                    .font(AppFont.number(10, .semibold, relativeTo: .caption2))
                    .foregroundStyle(palette.featureMuted)
            }
        }
        .frame(width: 132, height: 132)
        .accessibilityHidden(true)
    }
}

/// 진행 칩 막대 (트랙 306 × 20 inset, 칩 높이 10).
struct ChipTrack: View {
    var chips: [SongMath.Chip]

    var body: some View {
        GeometryReader { geo in
            let count = CGFloat(max(chips.count, 1))
            let width = (geo.size.width - 10 - (count - 1) * 5) / count
            HStack(spacing: 5) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    switch chip {
                    case .filled:
                        Capsule().fill(Palette.sunset).frame(width: width, height: 10)
                    case .current:
                        Capsule().stroke(Palette.accentOutline, lineWidth: 1.6).frame(width: width - 1.6, height: 8.4)
                            .frame(width: width, height: 10)
                    case .empty:
                        Color.clear.frame(width: width, height: 10)
                    }
                }
            }
            .padding(.horizontal, 5)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 20)
        .insetSurface(cornerRadius: 10)
        .accessibilityHidden(true)
    }
}

/// 결과 화면의 작은 레코드 아이콘 (30pt). 추가 분량은 점선 원.
struct SongTokenRow: View {
    var planned: Int
    var done: Int

    var body: some View {
        let total = max(planned, done)
        HStack(spacing: 8) {
            ForEach(0..<min(total, 9), id: \.self) { i in
                if i < planned {
                    VinylRecord(diameter: 30, showsLabelText: false).opacity(i < done ? 1 : 0.35)
                } else {
                    Circle()
                        .stroke(Palette.accentOutline, style: StrokeStyle(lineWidth: 1, dash: [2.5, 2.5]))
                        .frame(width: 30, height: 30)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
