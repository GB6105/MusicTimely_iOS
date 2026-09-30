import SwiftUI

/// RECOVERY_REQUIRED (§5.2, §8). 추정값을 실측처럼 이어 붙이지 않는다.
struct RecoveryView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppFont.text(24, .bold, relativeTo: .title))
                .foregroundStyle(palette.ink)
                .padding(.top, 72)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(AppFont.text(14, relativeTo: .body))
                .foregroundStyle(palette.muted)
                .padding(.top, 12)
            if let cp = store.checkpoint {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cp.taskTitle ?? String(localized: "지금 하는 일")).font(AppFont.text(16, .medium)).foregroundStyle(
                        palette.ink)
                    Text("마지막으로 확인된 지점 · \(TimeFormat.clock(cp.accumulatedActiveMs)) 경과")
                        .font(AppFont.number(13, .regular)).foregroundStyle(palette.muted)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(palette.field))
                .padding(.top, 30)
            }
            Spacer()
            VStack(spacing: 20) {
                if store.corruptCheckpoint {
                    Button("새로 시작하기") { store.discardCorruptCheckpoint() }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("여기서 마치기") { store.finishFromRecovery() }
                        .buttonStyle(TertiaryButtonStyle(height: 50))
                        .accessibilityIdentifier("recovery.finish")
                    Button("저장된 지점에서 이어가기") { store.resumeFromRecovery() }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("recovery.resume")
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, Theme.Spacing.text)
        .background(palette.background.ignoresSafeArea())
    }

    private var title: LocalizedStringKey {
        store.corruptCheckpoint ? "저장된 세션을 읽을 수 없어요" : "세션을 어디서 이어갈까요?"
    }

    private var message: LocalizedStringKey {
        if store.corruptCheckpoint { return "저장본이 손상돼 임의로 이어가지 않았어요." }
        switch store.checkpoint?.recoveryReason {
        case .staleCheckpoint: return "마지막 세션이 오래돼 시간을 그대로 이어 붙이지 않았어요."
        case .longInfiniteGap: return "오랫동안 확인되지 않아 시간을 그대로 이어 붙이지 않았어요."
        default: return "기기가 다시 켜져 그동안의 시간을 확인할 수 없어요. 마지막으로 확인된 지점만 남겼어요."
        }
    }
}
