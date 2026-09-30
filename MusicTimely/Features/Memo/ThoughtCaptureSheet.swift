import SwiftUI

/// SCR-08 생각 메모 (피그마 06 Capture). 저장 실패 시 입력을 유지한다 (FR-037).
struct ThoughtCaptureSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        EditorSheet(
            title: "떠오른 생각만 적어둘까요?",
            subtitle: "저장하고 하던 일로 돌아가요.",
            primaryTitle: "저장하고 돌아가기",
            primaryEnabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            fieldMinHeight: 180,
            onPrimary: save
        ) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    "", text: $text, prompt: Text("예: 참고 자료 링크 다시 찾기").foregroundStyle(palette.muted.opacity(0.7)),
                    axis: .vertical
                )
                .lineLimit(4...8)
                .font(AppFont.text(15, .medium, relativeTo: .body))
                .foregroundStyle(palette.ink)
                .focused($focused)
                .onChange(of: text) { _, new in
                    if new.count > ThoughtNote.maxLength { text = String(new.prefix(ThoughtNote.maxLength)) }
                }
                .accessibilityLabel("생각 메모")
                .accessibilityIdentifier("memo.text")
                HStack {
                    if let error {
                        Text(error).font(AppFont.text(12, .medium, relativeTo: .caption)).foregroundStyle(
                            Palette.accentOutline)
                    }
                    Spacer()
                    Text("\(text.count)/\(ThoughtNote.maxLength)").font(AppFont.number(11, .regular)).foregroundStyle(
                        palette.muted)
                }
            }
        }
        .onAppear { focused = true }
    }

    private func save() {
        switch store.addThought(text) {
        case .saved:
            dismiss()
        case .empty:
            break
        case .limitReached:
            error = String(localized: "이번 세션에는 \(ThoughtNote.maxPerSession)개까지 적을 수 있어요")
        case .failed:
            error = String(localized: "저장하지 못했어요. 다시 시도해 주세요")
        }
    }
}
