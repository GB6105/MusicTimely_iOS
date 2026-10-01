import SwiftUI

/// SCR-01 배정 (피그마 light-01-home).
struct AssignView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var showingCustomInput = false
    @State private var showingMusic = false
    @State private var showingSettings = false
    @FocusState private var titleFocused: Bool
    /// 진행 중 세션이 있을 때 홈을 둘러보는 경우 (FR-013)
    var activeSessionReturn: (() -> Void)?

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if let activeSessionReturn { activeBanner(activeSessionReturn) }
                Text("지금은 이것 하나만")
                    .font(AppFont.text(12, relativeTo: .caption))
                    .foregroundStyle(palette.muted)
                    .padding(.leading, 8)
                    .padding(.top, 16)
                taskField(title: $store.draftTitle)
                    .padding(.top, 7)
                Text("얼마나 하실까요?")
                    .font(AppFont.text(21, .bold, relativeTo: .title2))
                    .foregroundStyle(palette.ink)
                    .padding(.leading, 4)
                    .padding(.top, 30)
                modeSwitch.padding(.top, 12)
                if !store.isInfinite {
                    chips.padding(.top, 18)
                }
                translationCard.padding(.top, store.isInfinite ? 24 : 38)
                musicRow.padding(.top, 28)
            }
            .padding(.horizontal, Theme.Spacing.card)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if activeSessionReturn == nil { startButton } else { returnButton }
        }
        .background(palette.background.ignoresSafeArea())
        .sheet(isPresented: $showingCustomInput) { CustomMinutesSheet() }
        .sheet(isPresented: $showingMusic) { MusicSheet() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    private var header: some View {
        HStack {
            Text("집중 세션")
                .font(AppFont.text(24, .bold, relativeTo: .largeTitle))
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            CircleControl(icon: "icon-gear", label: "설정") { showingSettings = true }
                .accessibilityIdentifier("assign.settings")
        }
        .padding(.top, 6)
    }

    private func activeBanner(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text("진행 중인 세션이 있어요")
                    .font(AppFont.text(14, .medium, relativeTo: .subheadline))
                Spacer()
                Image("icon-chevron").renderingMode(.template).foregroundStyle(Palette.accentOutline)
            }
            .foregroundStyle(palette.ink)
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .background(Capsule().fill(palette.surface).raised())
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
    }

    private func taskField(title: Binding<String>) -> some View {
        TextField(
            "",
            text: Binding(get: { title.wrappedValue }, set: { title.wrappedValue = String($0.prefix(100)) }),
            prompt: Text("지금 하는 일").foregroundStyle(palette.muted.opacity(0.7))
        )
        .font(AppFont.text(17, relativeTo: .body))
        .foregroundStyle(palette.ink)
        .focused($titleFocused)
        .submitLabel(.done)
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
        .frame(minHeight: 58)
        .background(Capsule().fill(palette.field))
        .shadow(color: Color(hex: 0x96989E, opacity: palette.isDark ? 0 : 0.18), radius: 5, y: 8)
        .disabled(activeSessionReturn != nil)
        .accessibilityLabel("작업 제목, 선택 입력")
        .accessibilityIdentifier("assign.title")
    }

    /// 정한 시간까지 하는 타이머와, 끝낼 때까지 경과만 재는 스톱워치 중 하나를 고른다.
    private var modeSwitch: some View {
        HStack(spacing: 4) {
            modeOption("시간 정하기", selected: !store.isInfinite, id: "assign.mode.timer") {
                store.isInfinite = false
            }
            modeOption("끝낼 때까지 재기", selected: store.isInfinite, id: "assign.mode.stopwatch") {
                store.isInfinite = true
            }
        }
        .padding(4)
        .background(Capsule().fill(palette.surface).raised())
        .disabled(activeSessionReturn != nil)
        .animation(.easeInOut(duration: 0.2), value: store.isInfinite)
    }

    private func modeOption(
        _ title: LocalizedStringKey, selected: Bool, id: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.text(14, selected ? .bold : .medium, relativeTo: .subheadline))
                .foregroundStyle(selected ? .white : palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if selected { Capsule().fill(Palette.sunset) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private var chips: some View {
        HStack(spacing: 0) {
            ForEach(Allocation.presetMinutes, id: \.self) { minutes in
                DurationChip(
                    value: "\(minutes)", unit: "MIN",
                    isSelected: !store.isInfinite && store.selectedMinutes == minutes,
                    accessibilityText: String(localized: "\(minutes)분")
                ) {
                    store.selectedMinutes = minutes
                    store.isInfinite = false
                }
                .accessibilityIdentifier("assign.chip.\(minutes)")
                Spacer(minLength: 0)
            }
            let customSelected = !store.isInfinite && store.selectedMinutes == nil
            DurationChip(
                value: customSelected ? (store.draftMinutes.map(String.init) ?? "+") : "+", unit: "SET",
                isSelected: customSelected,
                accessibilityText: String(localized: "직접 입력")
            ) { showingCustomInput = true }
            .accessibilityIdentifier("assign.chip.custom")
        }
        .padding(.horizontal, 4)
        .disabled(activeSessionReturn != nil)
    }

    private var translationCard: some View {
        let minutes = store.draftMinutes
        let units = store.draftPlannedUnits
        let showSongs = store.settings.displayMode(for: store.settings.source.type) != .timeOnly
        let noun = store.settings.repeatSingleSong ? String(localized: "바퀴") : String(localized: "곡")
        return HStack(spacing: 22) {
            SongDial(
                minutesText: store.isInfinite ? "∞" : (minutes.map(String.init) ?? "–"),
                units: store.isInfinite ? 1 : (units ?? 1))
            VStack(alignment: .leading, spacing: 6) {
                if store.isInfinite {
                    Text("정한 시간 없이").font(AppFont.text(13, relativeTo: .footnote)).foregroundStyle(palette.featureMuted)
                    Text("끝낼 때까지").font(AppFont.text(28, .medium, relativeTo: .title)).foregroundStyle(
                        palette.featureInk)
                    Text("잔여·끝 예고 없이\n경과만 재요").font(AppFont.text(12, relativeTo: .caption)).foregroundStyle(
                        palette.featureMuted)
                } else if let minutes, let units {
                    Text("\(minutes)분이면").font(AppFont.text(13, relativeTo: .footnote)).foregroundStyle(
                        palette.featureMuted)
                    if showSongs {
                        Text("약 \(units)\(noun) 분량")
                            .font(AppFont.text(30, .medium, relativeTo: .title))
                            .foregroundStyle(palette.featureInk)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text(unitCaption).font(AppFont.text(12, relativeTo: .caption)).foregroundStyle(
                            palette.featureMuted)
                    } else {
                        Text("\(minutes)분").font(AppFont.text(32, .medium, relativeTo: .title)).foregroundStyle(
                            palette.featureInk)
                        Text("곡 표시 꺼짐\n시간만 재요").font(AppFont.text(12, relativeTo: .caption)).foregroundStyle(
                            palette.featureMuted)
                    }
                } else {
                    Text("1~240분 사이의\n정수로 적어 주세요")
                        .font(AppFont.text(14, .medium, relativeTo: .subheadline))
                        .foregroundStyle(Palette.accentOutline)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, minHeight: 188)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.card, style: .continuous).fill(palette.featureCard)
                .raised()
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("assign.translation")
    }

    private var unitCaption: String {
        let seconds = store.unitSeconds
        let m = seconds / 60
        let s = seconds % 60
        let length = s == 0 ? String(localized: "\(m)분") : String(localized: "\(m)분 \(s)초")
        return store.settings.repeatSingleSong
            ? String(localized: "반복 곡 \(length) 기준\n평균으로 추정한 값")
            : String(localized: "한 곡 평균 \(length) 기준\n평균으로 추정한 값")
    }

    private var musicRow: some View {
        Button {
            showingMusic = true
        } label: {
            HStack(spacing: 16) {
                Image("icon-note").renderingMode(.template).foregroundStyle(Palette.accentOutline)
                VStack(alignment: .leading, spacing: 3) {
                    Text(musicTitle).font(AppFont.text(14, .medium, relativeTo: .subheadline)).foregroundStyle(
                        palette.ink)
                    Text(musicSubtitle).font(AppFont.text(12, relativeTo: .caption)).foregroundStyle(palette.muted)
                }
                Spacer()
                Image("icon-chevron").renderingMode(.template).foregroundStyle(Palette.accentOutline)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(Capsule().fill(palette.surface).raised())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("assign.music")
    }

    private var musicTitle: String {
        let source = store.settings.source
        switch source.type {
        case .builtinNoise:
            return source.noiseColor == .white ? String(localized: "화이트 노이즈") : String(localized: "핑크 노이즈")
        case .none: return String(localized: "음악 없이 시간만")
        case .externalD0, .localO0:
            if source.providerID == MusicProvider.customLinkID { return String(localized: "내가 붙인 링크") }
            if let provider = MusicProvider.named(source.providerID) { return provider.name }
            return String(localized: "음악은 쓰던 앱에서 그대로")
        }
    }

    private var musicSubtitle: String {
        switch store.settings.source.type {
        case .builtinNoise: String(localized: "재생 버튼을 눌러야 소리가 나요")
        case .none: String(localized: "곡 대신 시간으로 보여줘요")
        case .externalD0, .localO0: String(localized: "재생은 건드리지 않아요")
        }
    }

    private var startButton: some View {
        Button {
            titleFocused = false
            store.start()
        } label: {
            Text(startTitle)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!store.canStart)
        .padding(.horizontal, Theme.Spacing.text)
        .padding(.bottom, 12)
        .background(palette.background.opacity(0.001))
        .accessibilityIdentifier("assign.start")
    }

    private var startTitle: String {
        if store.isInfinite { return String(localized: "시간 정하지 않고 시작") }
        guard let minutes = store.draftMinutes, let units = store.draftPlannedUnits else {
            return String(localized: "시작")
        }
        if store.settings.displayMode(for: store.settings.source.type) == .timeOnly {
            return String(localized: "\(minutes)분 시작")
        }
        let noun = store.settings.repeatSingleSong ? String(localized: "바퀴") : String(localized: "곡")
        return String(localized: "약 \(units)\(noun) 분량으로 시작")
    }

    private var returnButton: some View {
        Button("진행 중인 세션으로 돌아가기") { activeSessionReturn?() }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.text)
            .padding(.bottom, 12)
    }
}

/// 직접 입력 (1~240 정수, FR-002).
struct CustomMinutesSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var valid: Int? { Allocation.validateMinutes(text) }

    var body: some View {
        EditorSheet(
            title: "몇 분 할까요?",
            subtitle: "1분부터 240분까지 정수로 적어 주세요.",
            primaryTitle: "이 시간으로 정하기",
            primaryEnabled: valid != nil,
            onPrimary: {
                store.customMinutesText = text
                store.selectedMinutes = nil
                store.isInfinite = false
                dismiss()
            }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("25", text: $text)
                        .keyboardType(.numberPad)
                        .font(AppFont.number(40, .regular, relativeTo: .largeTitle))
                        .foregroundStyle(palette.ink)
                        .focused($focused)
                        .accessibilityLabel("분")
                        .accessibilityIdentifier("custom.minutes")
                    Text("분").font(AppFont.text(24, .medium, relativeTo: .title2)).foregroundStyle(palette.ink)
                }
                if !text.isEmpty && valid == nil {
                    Text("1~240 사이의 정수만 쓸 수 있어요")
                        .font(AppFont.text(13, .medium, relativeTo: .footnote))
                        .foregroundStyle(Palette.accentOutline)
                        .accessibilityIdentifier("custom.error")
                }
            }
        }
        .onAppear {
            text = store.customMinutesText
            focused = true
        }
    }
}
