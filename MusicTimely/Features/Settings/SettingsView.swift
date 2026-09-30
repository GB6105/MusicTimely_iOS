import SwiftUI

/// SCR-09 설정 (FR-004, FR-019, FR-020, FR-038, FR-039).
struct SettingsView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var loopText = ""
    @State private var loopError: String?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: binding(\.averageSongSeconds), in: AppSettings.unitSecondsRange, step: 10) {
                        LabeledContent("평균 곡 길이", value: lengthText(store.settings.averageSongSeconds))
                    }
                    .accessibilityIdentifier("settings.average")
                    Toggle("곡 분량으로 보여주기", isOn: binding(\.showSongs))
                        .accessibilityIdentifier("settings.showSongs")
                    if store.settings.showSongs {
                        Toggle("한 곡 반복으로 듣기", isOn: binding(\.repeatSingleSong))
                        if store.settings.repeatSingleSong {
                            HStack {
                                Text("반복할 곡 길이")
                                Spacer()
                                TextField("3:42", text: $loopText)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numbersAndPunctuation)
                                    .onSubmit(applyLoop)
                                    .accessibilityIdentifier("settings.loop")
                            }
                            if let loopError {
                                Text(loopError).font(AppFont.text(12, .medium)).foregroundStyle(Palette.accentOutline)
                            }
                        }
                    }
                } header: {
                    Text("곡 표시")
                } footer: {
                    Text("바꾼 값은 다음 세션부터 적용돼요. 곡 분량은 평균 길이로 추정한 값이에요.")
                }

                Section("화면") {
                    Picker("테마", selection: binding(\.theme)) {
                        Text("시스템").tag(ThemeChoice.system)
                        Text("라이트").tag(ThemeChoice.light)
                        Text("네이비").tag(ThemeChoice.navy)
                        Text("다크").tag(ThemeChoice.dark)
                    }
                    Toggle("레코드·톤암 움직임", isOn: binding(\.motionEnabled))
                    Toggle("잠금화면에서 세부 숨기기", isOn: binding(\.lockScreenPrivate))
                }

                Section("앱에서 내는 소리") {
                    LabeledContent("소리 크기") {
                        Slider(value: binding(\.noiseVolume), in: 0...1).frame(maxWidth: 180).tint(Palette.accentMid)
                    }
                    Stepper(value: binding(\.fadeInSeconds), in: AppSettings.fadeInRange, step: 0.5) {
                        LabeledContent("시작 페이드", value: String(format: "%.1f초", store.settings.fadeInSeconds))
                    }
                    Stepper(value: binding(\.fadeOutSeconds), in: AppSettings.fadeOutRange, step: 0.5) {
                        LabeledContent("끝 페이드", value: String(format: "%.1f초", store.settings.fadeOutSeconds))
                    }
                }

                Section {
                    LabeledContent(
                        "알림", value: store.notificationsDenied ? String(localized: "꺼짐") : String(localized: "켜짐 또는 미정")
                    )
                } header: {
                    Text("알림")
                } footer: {
                    Text("정한 시간이 지나면 알려요. 기기 설정에 따라 늦거나 오지 않을 수 있어요.")
                }

                if !store.keptThoughts.isEmpty {
                    Section("보관한 생각") {
                        ForEach(store.keptThoughts) { note in
                            Text(note.text)
                                .swipeActions { Button("지우기", role: .destructive) { store.deleteThought(note.id) } }
                        }
                    }
                }

                Section {
                    Button("기본값으로 되돌리기") { store.resetSettings() }
                    Button("모든 데이터 지우기", role: .destructive) { confirmingDelete = true }
                        .accessibilityIdentifier("settings.deleteAll")
                } footer: {
                    Text("설정·진행 중 세션·메모를 지워요. 음악 앱의 음악은 지우지 않아요.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background.ignoresSafeArea())
            .font(AppFont.text(15, relativeTo: .body))
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
            .confirmationDialog("모든 데이터를 지울까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("지우기", role: .destructive) {
                    store.deleteAllData()
                    dismiss()
                }
            }
            .onAppear {
                loopText = store.settings.loopSeconds.map { String(format: "%d:%02d", $0 / 60, $0 % 60) } ?? ""
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { value in store.updateSettings { $0[keyPath: keyPath] = value } })
    }

    private func lengthText(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func applyLoop() {
        switch AppSettings.parseLoopLength(loopText) {
        case .success(let seconds):
            loopError = nil
            store.updateSettings { $0.loopSeconds = seconds }
        case .failure(.format):
            loopError = String(localized: "분:초 형식으로 적어 주세요 (예: 3:42)")
        case .failure(.range):
            loopError = String(localized: "1:00부터 30:00 사이로 적어 주세요")
        }
    }
}
