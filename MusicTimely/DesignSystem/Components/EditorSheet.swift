import SwiftUI

/// 입력 화면 공통 배치 (피그마 06 Capture, 07 Correct song count).
struct EditorSheet<Field: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    var primaryTitle: LocalizedStringKey
    var primaryEnabled = true
    var fieldMinHeight: CGFloat = 120
    var onPrimary: () -> Void
    @ViewBuilder var field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppFont.text(24, .bold, relativeTo: .title))
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 72)
                .padding(.horizontal, 4)
            Text(subtitle)
                .font(AppFont.text(13, relativeTo: .footnote))
                .foregroundStyle(palette.muted)
                .padding(.top, 12)
                .padding(.horizontal, 4)
            field
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: fieldMinHeight, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(palette.field))
                .padding(.top, 38)
            Spacer(minLength: 24)
            VStack(spacing: 26) {
                Button("취소") { dismiss() }
                    .buttonStyle(TertiaryButtonStyle(height: 50))
                    .accessibilityIdentifier("editor.cancel")
                Button(primaryTitle, action: onPrimary)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!primaryEnabled)
                    .accessibilityIdentifier("editor.primary")
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, Theme.Spacing.card)
        .background(palette.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}
