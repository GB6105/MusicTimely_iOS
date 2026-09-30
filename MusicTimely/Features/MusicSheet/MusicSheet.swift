import SwiftUI

/// SCR-06 음악 선택 시트. 외부 앱은 열기만 하고, 노이즈는 명시적 탭으로만 재생한다.
struct MusicSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var linkText = ""
    @State private var linkError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    section("쓰던 음악 앱") {
                        row(title: "정하지 않음", subtitle: "평소처럼 음악 앱에서 직접 틀어요", selected: isExternal(nil)) {
                            store.selectExternal(nil)
                        }
                        ForEach(MusicProvider.all) { provider in
                            row(
                                title: LocalizedStringKey(provider.name), subtitle: "앱 열기만 해요. 재생은 건드리지 않아요",
                                selected: isExternal(provider.id)
                            ) {
                                store.selectExternal(provider)
                            }
                            .accessibilityIdentifier("music.provider.\(provider.id)")
                        }
                        customLink
                    }
                    section("앱에서 내는 소리") {
                        ForEach(NoiseColor.allCases, id: \.self) { color in
                            row(
                                title: color == .white ? "화이트 노이즈" : "핑크 노이즈",
                                subtitle: "오프라인에서도 나와요. 재생은 따로 눌러요",
                                selected: store.settings.source.type == .builtinNoise
                                    && store.settings.source.noiseColor == color
                            ) { store.selectNoise(color) }
                            .accessibilityIdentifier("music.noise.\(color.rawValue)")
                        }
                        if store.settings.source.type == .builtinNoise { noiseControls }
                    }
                    section("음악 없이") {
                        row(title: "음악 없음", subtitle: "시간만 재요", selected: store.settings.source.type == .none) {
                            store.selectNoMusic()
                        }
                        .accessibilityIdentifier("music.none")
                    }
                    Text("음악 앱의 재생·정지·곡 넘김은 이 앱이 하지 않아요. 앱을 연다고 음악이 재생된다는 뜻은 아니에요.")
                        .font(AppFont.text(12, relativeTo: .caption))
                        .foregroundStyle(palette.muted)
                        .padding(.horizontal, 4)
                }
                .padding(Theme.Spacing.card)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("음악")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func isExternal(_ id: String?) -> Bool {
        store.settings.source.type == .externalD0 && store.settings.source.providerID == id
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(AppFont.text(15, .bold, relativeTo: .headline)).foregroundStyle(palette.ink).padding(
                .leading, 4)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(palette.surface).raised())
        }
        .padding(.bottom, 8)
    }

    private func row(
        title: LocalizedStringKey, subtitle: LocalizedStringKey, selected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AppFont.text(15, .medium, relativeTo: .body)).foregroundStyle(palette.ink)
                    Text(subtitle).font(AppFont.text(12, relativeTo: .caption)).foregroundStyle(palette.muted)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Palette.accentOutline : palette.muted.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var customLink: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(
                    "", text: $linkText,
                    prompt: Text("https:// 로 시작하는 내 플레이리스트 링크").foregroundStyle(palette.muted.opacity(0.7))
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(AppFont.text(13, relativeTo: .footnote))
                .accessibilityIdentifier("music.link")
                Button("저장") { linkError = !store.setCustomLink(linkText) }
                    .font(AppFont.text(13, .medium, relativeTo: .footnote))
                    .foregroundStyle(Palette.accentOutline)
                    .disabled(linkText.isEmpty)
            }
            if linkError {
                Text("https 링크만 저장할 수 있어요").font(AppFont.text(12, .medium, relativeTo: .caption)).foregroundStyle(
                    Palette.accentOutline)
            } else if isExternal(MusicProvider.customLinkID) {
                Text("내가 붙인 링크를 쓰고 있어요").font(AppFont.text(12, relativeTo: .caption)).foregroundStyle(palette.muted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .onAppear { linkText = store.settings.customLinkURL ?? "" }
    }

    private var noiseControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(store.noise.state == .playing ? "소리 멈추기" : "소리 재생하기") { store.toggleNoise() }
                .buttonStyle(TertiaryButtonStyle(height: 46))
                .accessibilityIdentifier("music.noiseToggle")
            HStack {
                Text("앱 소리 크기").font(AppFont.text(12, relativeTo: .caption)).foregroundStyle(palette.muted)
                Slider(
                    value: Binding(
                        get: { store.settings.noiseVolume }, set: { v in store.updateSettings { $0.noiseVolume = v } }),
                    in: 0...1
                )
                .tint(Palette.accentMid)
                .accessibilityLabel("앱 소리 크기, 시스템 볼륨과 별개")
            }
            if store.noise.state == .interrupted || store.noise.state == .unavailable {
                Text("소리가 멈췄어요. 다시 재생하거나 음악 없이 이어가요.")
                    .font(AppFont.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(Palette.accentOutline)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
