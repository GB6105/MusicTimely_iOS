import SwiftUI

/// SCR-02 진행 · SCR-03 일시정지 · SCR-04 배정 도달 (피그마 02 Running / Estimated / Paused / Last song).
struct SessionView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var showingMemo = false
    @State private var showingCorrection = false
    @State private var showingMusic = false
    @State private var showingSettings = false
    var onBrowseHome: () -> Void

    var body: some View {
        if let cp = store.checkpoint, let display = store.display() {
            content(cp, display)
                .sheet(isPresented: $showingMemo) { ThoughtCaptureSheet() }
                .sheet(isPresented: $showingCorrection) {
                    CorrectionSheet(mode: .segment(current: display.segmentIndex, noun: display.unitNoun))
                }
                .sheet(isPresented: $showingMusic) { MusicSheet() }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .alert(
                    store.linkFailure ?? "",
                    isPresented: Binding(get: { store.linkFailure != nil }, set: { if !$0 { store.linkFailure = nil } })
                ) {
                    Button("그대로 진행", role: .cancel) {}
                    Button("다른 소리 고르기") { showingMusic = true }
                } message: {
                    Text("타이머는 그대로 가고 있어요.")
                }
                .alert(
                    "앱 전환 안내",
                    isPresented: Binding(
                        get: { store.sourceNotice != nil }, set: { if !$0 { store.sourceNotice = nil } })
                ) {
                    Button("확인", role: .cancel) {}
                } message: {
                    Text("요금제·지역에 따라 앱 전환 시 재생이 멈출 수 있어요.")
                }
        }
    }

    private func content(_ cp: SessionCheckpoint, _ d: SessionDisplay) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                header(cp)
                ZStack {
                    RecordPlayer(
                        armEngaged: cp.state == .running,
                        spinning: cp.sourceType == .builtinNoise && store.noise.state == .playing
                            && cp.state == .running,
                        motionEnabled: store.settings.motionEnabled
                    )
                    .offset(x: 16)
                    if cp.state == .paused { pausedPill }
                }
                .frame(height: 286)
                .padding(.top, 14)
                sourceLine(cp, d).padding(.top, 22)
                panel(cp, d).padding(.top, 18).padding(.horizontal, Theme.Spacing.card)
                if cp.state == .limitReached { extensionRow.padding(.top, 20) }
                controls(cp).padding(.top, cp.state == .limitReached ? 24 : 34)
                if cp.state == .paused {
                    Text(cp.sourceType == .builtinNoise ? "앱 소리는 작게 줄였어요." : "타이머만 멈췄어요. 음악은 음악 앱에서 조절해요.")
                        .font(AppFont.text(11, relativeTo: .caption2))
                        .foregroundStyle(palette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                        .padding(.horizontal, 30)
                }
            }
            .padding(.bottom, 24)
        }
        .background(palette.background.ignoresSafeArea())
    }

    private func header(_ cp: SessionCheckpoint) -> some View {
        HStack {
            CircleControl(icon: "icon-back", label: "홈 둘러보기, 세션은 계속돼요", action: onBrowseHome)
                .accessibilityIdentifier("session.home")
            Spacer()
            VStack(spacing: 4) {
                Text("집중 세션").font(AppFont.text(11, relativeTo: .caption2)).foregroundStyle(palette.muted)
                Text(cp.taskTitle ?? String(localized: "지금 하는 일"))
                    .font(AppFont.text(14, .medium, relativeTo: .subheadline))
                    .foregroundStyle(palette.ink)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(cp.taskTitle ?? String(localized: "지금 하는 일"))
            }
            Spacer()
            Menu {
                if cp.displayMode != .timeOnly, cp.state.isActive {
                    Button("곡 표시 맞추기") { showingCorrection = true }
                }
                Button("음악 바꾸기") { showingMusic = true }
                Button("설정") { showingSettings = true }
            } label: {
                Image("icon-more").renderingMode(.template).foregroundStyle(palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(palette.surface).raised())
            }
            .accessibilityLabel("더 보기")
            .accessibilityIdentifier("session.more")
        }
        .padding(.horizontal, Theme.Spacing.card)
        .padding(.top, 6)
    }

    private var pausedPill: some View {
        Text("타이머만 쉬고 있어요")
            .font(AppFont.text(17, .medium, relativeTo: .headline))
            .foregroundStyle(palette.isDark ? Color(hex: 0x26262C) : palette.ink)
            .frame(width: 270, height: 62)
            .background(Capsule().fill(Color(hex: 0xF3F3F5)))
            .shadow(color: .white.opacity(0.9), radius: 16)
            .offset(y: 2)
            .accessibilityIdentifier("session.pausedLabel")
    }

    @ViewBuilder
    private func sourceLine(_ cp: SessionCheckpoint, _ d: SessionDisplay) -> some View {
        VStack(spacing: 6) {
            switch cp.sourceType {
            case .builtinNoise:
                Text(cp.sourceProviderID == NoiseColor.white.rawValue ? "화이트 노이즈" : "핑크 노이즈")
                    .font(AppFont.text(20, .medium, relativeTo: .title3)).foregroundStyle(palette.ink)
                Button(store.noise.state == .playing ? "소리 멈추기" : "소리 재생하기") { store.toggleNoise() }
                    .font(AppFont.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(Palette.accentOutline)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("session.noiseToggle")
            case .none:
                Text("음악 없음").font(AppFont.text(20, .medium, relativeTo: .title3)).foregroundStyle(palette.ink)
                Text("시간만 재고 있어요").font(AppFont.text(11, relativeTo: .caption2)).foregroundStyle(palette.muted)
            case .externalD0, .localO0:
                if cp.displayMode == .timeOnly || !cp.allocation.isBounded && cp.displayMode == .timeOnly {
                    Text(externalName(cp)).font(AppFont.text(20, .medium, relativeTo: .title3)).foregroundStyle(
                        palette.ink)
                } else {
                    Text("약 \(SongMath.koreanOrdinal(d.segmentIndex)) \(d.unitNoun)")
                        .font(AppFont.text(20, .medium, relativeTo: .title3))
                        .foregroundStyle(palette.ink)
                        .accessibilityIdentifier("session.segment")
                }
                Text(cp.correction == nil ? "곡 정보 없이 평균 길이로 추정 중" : "직접 맞춘 번호에서 평균 길이로 이어서 추정 중")
                    .font(AppFont.text(11, relativeTo: .caption2))
                    .foregroundStyle(palette.muted)
                Button("음악 앱 열기") { Task { await store.openSelectedMusic() } }
                    .font(AppFont.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(Palette.accentOutline)
                    .frame(minHeight: 36)
                    .accessibilityIdentifier("session.openMusic")
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Theme.Spacing.text)
    }

    private func externalName(_ cp: SessionCheckpoint) -> String {
        if cp.sourceProviderID == MusicProvider.customLinkID { return String(localized: "내가 붙인 링크") }
        return MusicProvider.named(cp.sourceProviderID)?.name ?? String(localized: "쓰던 음악 앱")
    }

    private func panel(_ cp: SessionCheckpoint, _ d: SessionDisplay) -> some View {
        let text = PanelText(cp: cp, d: d)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(text.title)
                    .font(AppFont.text(22, .bold, relativeTo: .title2))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .accessibilityIdentifier("session.panelTitle")
                Spacer(minLength: 8)
                if let trailing = text.trailing {
                    Text(trailing).font(AppFont.text(13, relativeTo: .footnote)).foregroundStyle(palette.muted)
                }
            }
            if let chips = d.chips, cp.displayMode != .timeOnly {
                ChipTrack(chips: chips).padding(.top, 14)
            } else if let target = d.targetMs {
                ProgressTrack(fraction: Double(d.elapsedMs) / Double(max(target, 1))).padding(.top, 14)
            }
            Text(text.footer)
                .font(AppFont.number(12, .regular, relativeTo: .caption))
                .foregroundStyle(palette.muted)
                .padding(.top, 16)
                .accessibilityIdentifier("session.elapsed")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 134, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.panel, style: .continuous).fill(palette.surface).raised()
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.accessibility)
        .accessibilityIdentifier("session.panel")
    }

    private var extensionRow: some View {
        HStack(spacing: 14) {
            ForEach(TimerMachine.extensionMinutes, id: \.self) { minutes in
                Button("+\(minutes)분") { store.send(.extend(minutes: minutes)) }
                    .font(AppFont.number(15, .medium, relativeTo: .subheadline))
                    .foregroundStyle(palette.ink)
                    .frame(width: 84, height: 48)
                    .background(Capsule().fill(palette.surface).raised())
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(minutes)분 더 하기")
                    .accessibilityIdentifier("session.extend.\(minutes)")
            }
        }
    }

    private func controls(_ cp: SessionCheckpoint) -> some View {
        HStack(alignment: .top, spacing: 16) {
            control(icon: "icon-plus", size: 60, label: "생각 메모", id: "session.memo") { showingMemo = true }
            switch cp.state {
            case .paused:
                control(icon: "icon-play", size: 84, label: "세션 다시 시작", id: "session.resume") { store.send(.resume) }
            case .limitReached:
                Color.clear.frame(width: 90, height: 84)
            default:
                control(icon: "icon-pause", size: 84, label: "세션 잠시 멈춤", id: "session.pause") { store.send(.pause) }
            }
            control(icon: "icon-stop", size: 60, label: "마치기", id: "session.finish") { store.send(.finish) }
        }
        .frame(maxWidth: .infinity)
    }

    private func control(
        icon: String, size: CGFloat, label: LocalizedStringKey, id: String, action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 14) {
            CircleControl(icon: icon, size: size, tint: Palette.accentOutline, label: label, action: action)
                .accessibilityIdentifier(id)
            Text(label)
                .font(AppFont.text(11, relativeTo: .caption2))
                .foregroundStyle(palette.muted)
                .accessibilityHidden(true)
        }
        .frame(width: 90)
    }
}

/// 진행 패널 문구 (FR-014, FR-017, FR-020, SCR-04).
struct PanelText {
    var title: String
    var trailing: String?
    var footer: String
    var accessibility: String

    init(cp: SessionCheckpoint, d: SessionDisplay) {
        let elapsed = TimeFormat.clock(d.elapsedMs)
        let noun = d.unitNoun
        let songs = d.mode != .timeOnly
        let target = d.targetMs.map { TimeFormat.minutes($0) }

        if cp.state == .limitReached {
            title = String(localized: "정한 시간이 지났어요")
            trailing = nil
            footer = String(localized: "\(elapsed) 경과 · \(target ?? "") 중")
            accessibility = String(localized: "정한 시간이 지났어요. \(TimeFormat.spoken(d.elapsedMs)) 경과. 마치거나 시간을 더할 수 있어요.")
            return
        }
        guard let remainingMs = d.remainingMs, let remainingUnits = d.remainingUnits, let totalUnits = d.totalUnits
        else {
            title = String(localized: "끝낼 때까지 하는 중")
            trailing = songs ? String(localized: "약 \(SongMath.format(d.elapsedUnits))\(noun) 분량") : nil
            footer = String(localized: "\(elapsed) 경과")
            accessibility = String(localized: "정한 시간 없이 하는 중. \(TimeFormat.spoken(d.elapsedMs)) 경과.")
            return
        }
        let remaining = TimeFormat.clock(remainingMs)
        if !songs {
            title = String(localized: "\(TimeFormat.minutesLeft(remainingMs)) 남음")
            trailing = nil
            accessibility = String(
                localized: "\(TimeFormat.spoken(remainingMs)) 남음, \(TimeFormat.spoken(d.elapsedMs)) 경과")
        } else if d.isLastUnit {
            title = String(localized: "대략 한 \(noun) 분량 남았어요")
            trailing = String(localized: "마무리하셔도 돼요")
            accessibility = String(localized: "대략 한 \(noun) 분량 남음, \(TimeFormat.spoken(d.elapsedMs)) 경과, 평균 길이로 추정")
        } else {
            title = String(localized: "약 \(remainingUnits)\(noun) 분량 남음")
            trailing = String(localized: "약 \(totalUnits)\(noun) 중")
            accessibility = String(
                localized: "약 \(remainingUnits)\(noun) 분량 남음, \(TimeFormat.spoken(d.elapsedMs)) 경과, 평균 길이로 추정")
        }
        footer = String(localized: "\(elapsed) 경과 · \(remaining) 남음 · \(target ?? "") 중")
    }
}

/// 곡 칩 대신 쓰는 연속 진행 막대.
struct ProgressTrack: View {
    var fraction: Double

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Palette.sunset)
                .frame(width: max(10, (geo.size.width - 10) * min(1, max(0, fraction))), height: 10)
                .padding(.horizontal, 5)
                .frame(maxHeight: .infinity)
        }
        .frame(height: 20)
        .insetSurface(cornerRadius: 10)
        .accessibilityHidden(true)
    }
}

enum TimeFormat {
    static func clock(_ ms: Int64) -> String {
        let total = Int(ms / 1_000)
        let h = total / 3_600
        let m = (total % 3_600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    static func minutes(_ ms: Int64) -> String {
        String(localized: "\(Int(ms / 60_000))분")
    }

    static func minutesLeft(_ ms: Int64) -> String {
        let minutes = Int((ms + 59_999) / 60_000)
        return String(localized: "\(minutes)분")
    }

    static func spoken(_ ms: Int64) -> String {
        let total = Int(ms / 1_000)
        let m = total / 60
        let s = total % 60
        if m == 0 { return String(localized: "\(s)초") }
        return s == 0 ? String(localized: "\(m)분") : String(localized: "\(m)분 \(s)초")
    }
}
