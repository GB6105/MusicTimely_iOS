import SwiftUI

/// SCR-07 곡 표시 보정 (피그마 07). 시간·목표·알림은 바꾸지 않는다 (FR-016).
struct CorrectionSheet: View {
    enum Mode {
        /// 진행 중: 지금 몇 번째 곡인지 맞춘다.
        case segment(current: Int, noun: String)
        /// 결과: 전체 곡 분량 표시를 고친다.
        case result(current: Int)
    }

    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    var mode: Mode
    @State private var text = ""
    @FocusState private var focused: Bool

    private var value: Int? {
        guard let n = Int(text), text.allSatisfy(\.isASCIIDigit) else { return nil }
        switch mode {
        case .segment: return (1...999).contains(n) ? n : nil
        case .result: return (0...999).contains(n) ? n : nil
        }
    }

    var body: some View {
        EditorSheet(
            title: title,
            subtitle: "정확히 기억나지 않아도 괜찮아요. 정한 시간은 그대로예요.",
            primaryTitle: "이 번호로 맞추기",
            primaryEnabled: value != nil,
            onPrimary: apply
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .font(AppFont.number(34, .regular, relativeTo: .largeTitle))
                    .foregroundStyle(palette.ink)
                    .fixedSize()
                    .focused($focused)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier("correction.value")
                Text(suffix).font(AppFont.text(30, .medium, relativeTo: .title)).foregroundStyle(palette.ink)
            }
        }
        .onAppear {
            switch mode {
            case .segment(let current, _): text = "\(current)"
            case .result(let current): text = "\(current)"
            }
            focused = true
        }
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .segment: "지금 몇 번째 곡인가요?"
        case .result: "곡 분량 고치기"
        }
    }

    private var suffix: String {
        switch mode {
        case .segment(_, let noun): String(localized: "번째 \(noun)")
        case .result: String(localized: "곡 분량")
        }
    }

    private func apply() {
        guard let value else { return }
        switch mode {
        case .segment: store.correctSegment(to: value)
        case .result: store.correctResultUnits(value)
        }
        dismiss()
    }
}

/// 체감 시간 (FR-036). 건너뛰면 기록하지 않는다.
struct PerceivedTimeSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var value: Int? {
        guard let n = Int(text), text.allSatisfy(\.isASCIIDigit), (0...1_440).contains(n) else { return nil }
        return n
    }

    var body: some View {
        EditorSheet(
            title: "얼마나 한 것 같았나요?",
            subtitle: "느낌만 적어도 돼요. 비워 두면 기록하지 않아요.",
            primaryTitle: "적어두기",
            primaryEnabled: value != nil,
            onPrimary: {
                store.setPerceivedMinutes(value)
                dismiss()
            }
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .font(AppFont.number(34, .regular, relativeTo: .largeTitle))
                    .foregroundStyle(palette.ink)
                    .fixedSize()
                    .focused($focused)
                    .accessibilityLabel("체감 시간, 분")
                Text("분").font(AppFont.text(30, .medium, relativeTo: .title)).foregroundStyle(palette.ink)
            }
        }
        .onAppear { focused = true }
    }
}
