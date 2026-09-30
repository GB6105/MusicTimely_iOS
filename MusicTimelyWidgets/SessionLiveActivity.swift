import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// 잠금화면 Live Activity와 Dynamic Island (피그마 Lock Screen: 7 states, Dynamic Island).
struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            LockScreenCard(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(nil)
                .widgetURL(AppLink.session)
        } dynamicIsland: { context in
            let content = CardContent(state: context.state, isStale: context.isStale, now: .now)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MiniRecord(size: 30, showsArm: false).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.system(size: 15, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(content.title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            Text(content.islandSubtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                        }
                        ActionButtons(content: content, dark: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                MiniRecord(size: 18, showsArm: false)
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .frame(maxWidth: 52)
            } minimal: {
                MiniRecord(size: 18, showsArm: false)
            }
            .widgetURL(AppLink.session)
            .keylineTint(MiniColors.accentMid)
        }
    }
}

/// 상태별 문구 (피그마 Running / Last amount / Paused / Private / Ended / Unlimited).
struct CardContent {
    enum Kind {
        case running, lastUnit, paused, limitReached, ended, unlimited, privateMode
    }

    var kind: Kind
    var title: String
    var subtitle: String
    var footer: String?
    var islandSubtitle: String

    init(state s: SessionActivityAttributes.ContentState, isStale: Bool, now: Date) {
        let elapsed = TimeText.clock(s.elapsedMs)
        let target = s.targetMs.map { "\($0 / 60_000)분" } ?? ""
        let pastTarget = s.targetEnd.map { now >= $0.addingTimeInterval(-1) } ?? false
        let noun = "곡"

        if s.privateMode, s.phase != .ended {
            kind = .privateMode
            title = "집중 세션 진행 중"
            subtitle = "상세 내용은 잠금 해제 후 확인"
            footer = "잠금화면에는 작업·곡명 숨김"
            islandSubtitle = "잠금 해제 후 확인"
            return
        }
        switch s.phase {
        case .ended:
            kind = .ended
            title = "세션을 마쳤어요"
            if let planned = s.plannedUnits, !s.timeOnly {
                let done = Int(Double(s.elapsedMs) / Double(s.unitMs))
                subtitle = "잡은 \(planned)\(noun) 분량 · 약 \(done)\(noun) 분량 동안"
            } else {
                subtitle = "\(s.elapsedMs / 60_000)분 동안 했어요"
            }
            footer =
                s.initialMs.map { "\($0 / 60_000)분 배정 · \(s.elapsedMs / 60_000)분 경과" } ?? "\(s.elapsedMs / 60_000)분 경과"
            islandSubtitle = subtitle
        case .paused:
            kind = .paused
            title = "잠시 멈췄어요"
            subtitle = "세션만 멈춤 · 음악은 음악 앱에서"
            footer = target.isEmpty ? "\(elapsed)에서 멈춤" : "\(elapsed)에서 멈춤 · \(target) 배정"
            islandSubtitle = subtitle
        case .limitReached:
            kind = .limitReached
            title = "정한 시간이 지났어요"
            subtitle = "자동으로 끝내지 않아요 · 앱에서 시간 더하기"
            footer = nil
            islandSubtitle = subtitle
        case .running where pastTarget:
            kind = .limitReached
            title = "정한 시간이 지났어요"
            subtitle = "자동으로 끝내지 않아요 · 앱에서 시간 더하기"
            footer = nil
            islandSubtitle = subtitle
        case .running where s.isInfinite:
            kind = .unlimited
            title = "끝을 정하지 않고"
            let units = Double(s.elapsedMs) / Double(s.unitMs)
            subtitle = s.timeOnly ? "종료 시점 없이 재는 중" : "약 \(Int(units))\(noun) 분량이 지났어요"
            footer = nil
            islandSubtitle = "종료 시점 없음"
        case .running where s.isLastUnit && !isStale:
            kind = .lastUnit
            title = "마무리할 시간이에요"
            subtitle = "마지막 곡 분량 · 강제 종료 없음"
            footer = nil
            islandSubtitle = subtitle
        case .running:
            kind = .running
            if s.timeOnly || isStale {
                title = "집중 세션 진행 중"
            } else {
                title = "약 \(TimeText.ordinal(s.segmentIndex)) \(noun)"
            }
            subtitle = s.totalUnits.map { s.timeOnly ? "\(target) 배정" : "\($0)\(noun) 분량 중 · 평균 길이 기준" } ?? ""
            footer = nil
            islandSubtitle = s.totalUnits.map { s.timeOnly ? "\(target) 배정" : "\($0)\(noun) 분량 중 · \(target) 배정" } ?? ""
        }
    }
}

struct LockScreenCard: View {
    @Environment(\.colorScheme) private var scheme
    var state: SessionActivityAttributes.ContentState
    var isStale: Bool

    var body: some View {
        let content = CardContent(state: state, isStale: isStale, now: .now)
        let dark = scheme == .dark
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("MUSIC TIMELY").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Circle()
                        .fill(
                            state.phase == .running && content.kind != .limitReached ? MiniColors.accentMid : Color.gray
                        )
                        .frame(width: 6, height: 6)
                }
                Text(content.title)
                    .font(.system(size: 19, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 6)
                Text(content.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
                progress(content).padding(.top, 12)
                footer(content).padding(.top, 10)
                ActionButtons(content: content, dark: dark).padding(.top, 12)
            }
            MiniRecord(size: 66, armEngaged: state.phase == .running && content.kind != .limitReached)
                .padding(.top, 14)
        }
        .padding(14)
        .foregroundStyle(dark ? Color.white : MiniColors.ink)
        .background(
            dark
                ? Color(red: 38 / 255, green: 39 / 255, blue: 44 / 255)
                : Color(red: 243 / 255, green: 243 / 255, blue: 245 / 255))
    }

    @ViewBuilder
    private func progress(_ content: CardContent) -> some View {
        switch content.kind {
        case .running, .lastUnit, .paused:
            if !state.timeOnly, let total = state.totalUnits, total <= 8 {
                ChipRow(state: state, count: total)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func footer(_ content: CardContent) -> some View {
        if let footer = content.footer {
            Text(footer).font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
        } else if content.kind == .running || content.kind == .lastUnit || content.kind == .unlimited {
            (ElapsedText.text(state)
                + Text(state.targetMs.map { " 경과 · \($0 / 60_000)분 중" } ?? " 경과 · 종료 시점 없음"))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// 곡 칩. 진행 중에는 각 칩이 자기 구간 동안 스스로 차오른다 (앱 갱신 없이).
struct ChipRow: View {
    var state: SessionActivityAttributes.ContentState
    var count: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                chip(index)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private func chip(_ index: Int) -> some View {
        let unitSeconds = Double(state.unitMs) / 1_000
        let start = state.elapsedOrigin.addingTimeInterval(unitSeconds * Double(index))
        let end =
            state.targetEnd.map { min($0, start.addingTimeInterval(unitSeconds)) }
            ?? start.addingTimeInterval(unitSeconds)
        if state.phase == .running, start < end {
            ProgressView(timerInterval: start...end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(MiniColors.accentMid)
            .labelsHidden()
        } else {
            let filled = Double(state.elapsedMs) >= Double(state.unitMs) * Double(index + 1)
            Capsule().fill(filled ? AnyShapeStyle(MiniColors.sunset) : AnyShapeStyle(Color.gray.opacity(0.35)))
        }
    }
}

/// 경과 시간. 진행 중이면 시스템이 초 단위로 갱신한다.
struct ElapsedText: View {
    var state: SessionActivityAttributes.ContentState

    var body: some View { Self.text(state) }

    /// 다른 Text와 이어 붙일 수 있게 Text로 만든다 (타이머 글자가 폭을 넓게 잡지 않도록).
    static func text(_ state: SessionActivityAttributes.ContentState) -> Text {
        guard state.phase == .running else { return Text(TimeText.clock(state.elapsedMs)) }
        let end = state.targetEnd.map { max($0, state.elapsedOrigin) } ?? .distantFuture
        return Text(timerInterval: state.elapsedOrigin...end, countsDown: false)
    }
}

struct ActionButtons: View {
    var content: CardContent
    var dark: Bool

    var body: some View {
        switch content.kind {
        case .privateMode:
            Link(destination: AppLink.session) { label("잠금 해제 후 확인", primary: true) }
        case .ended:
            Link(destination: AppLink.session) { label("결과 보기", primary: true) }
        case .paused:
            HStack(spacing: 10) {
                Button(intent: ResumeSessionIntent()) { label("세션 재개", primary: true) }
                Button(intent: FinishSessionIntent()) { label("마치기", primary: false) }
            }
            .buttonStyle(.plain)
        case .limitReached:
            HStack(spacing: 10) {
                Link(destination: AppLink.session) { label("시간 더하기", primary: false) }
                Button(intent: FinishSessionIntent()) { label("마치기", primary: true) }.buttonStyle(.plain)
            }
        default:
            HStack(spacing: 10) {
                Button(intent: PauseSessionIntent()) { label("세션 멈춤", primary: true) }
                Button(intent: FinishSessionIntent()) { label("마치기", primary: false) }
            }
            .buttonStyle(.plain)
        }
    }

    private func label(_ text: String, primary: Bool) -> some View {
        let fill: Color
        let ink: Color
        if dark {
            fill = primary ? .white : Color(red: 58 / 255, green: 59 / 255, blue: 66 / 255)
            ink = primary ? MiniColors.ink : .white
        } else {
            fill = primary ? MiniColors.ink : Color(red: 226 / 255, green: 226 / 255, blue: 232 / 255)
            ink = primary ? .white : MiniColors.ink
        }
        return Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(Capsule().fill(fill))
    }
}

nonisolated enum TimeText {
    static func clock(_ ms: Int64) -> String {
        let total = Int(ms / 1_000)
        let h = total / 3_600
        let m = (total % 3_600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    static func ordinal(_ n: Int) -> String {
        let words = ["첫", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]
        return (1...words.count).contains(n) ? "\(words[n - 1]) 번째" : "\(n)번째"
    }
}
