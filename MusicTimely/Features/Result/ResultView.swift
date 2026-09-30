import SwiftUI

/// SCR-05 결과 (피그마 03 Result). 초과율·실패·점수 없음, 곡 분량 출처 표시 (FR-035).
struct ResultView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var showingCorrection = false
    @State private var showingPerceived = false

    var body: some View {
        if let cp = store.checkpoint {
            let summary = ResultSummary(cp: cp)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CircleControl(icon: "icon-close", label: "닫기") { store.closeResult(keepTitle: false) }
                        .padding(.top, 6)
                        .accessibilityIdentifier("result.close")
                    Text(summary.timeRange)
                        .font(AppFont.text(12, relativeTo: .caption))
                        .foregroundStyle(palette.muted)
                        .padding(.top, 16)
                        .padding(.leading, 4)
                    Text(cp.taskTitle ?? String(localized: "지금 하는 일"))
                        .font(AppFont.text(26, .bold, relativeTo: .title))
                        .foregroundStyle(palette.ink)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .accessibilityAddTraits(.isHeader)
                    comparisonCard(summary).padding(.top, 20)
                    Text(summary.headline)
                        .font(AppFont.text(16, .medium, relativeTo: .headline))
                        .foregroundStyle(palette.ink)
                        .padding(.top, 26)
                        .padding(.leading, 4)
                        .accessibilityIdentifier("result.headline")
                    if summary.showsSongs, let planned = summary.plannedUnits {
                        SongTokenRow(planned: planned, done: summary.doneUnits).padding(.top, 14).padding(.leading, 4)
                        Text(summary.legend)
                            .font(AppFont.text(12, relativeTo: .caption))
                            .foregroundStyle(palette.muted)
                            .padding(.top, 10)
                            .padding(.leading, 4)
                    }
                    if summary.showsSongs {
                        Button("곡 분량이 달랐다면 고치기") { showingCorrection = true }
                            .buttonStyle(TertiaryButtonStyle())
                            .padding(.top, 22)
                            .accessibilityIdentifier("result.correct")
                    }
                    ForEach(store.activeThoughts) { note in thoughtCard(note).padding(.top, 20) }
                    perceivedRow(cp).padding(.top, 14)
                }
                .padding(.horizontal, Theme.Spacing.card)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button("다음 할 일 고르기  »") { store.closeResult(keepTitle: false) }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("result.next")
                    Button("같은 일 이어서 하기") { store.closeResult(keepTitle: true) }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("result.again")
                }
                .padding(.horizontal, Theme.Spacing.text)
                .padding(.bottom, 8)
                .padding(.top, 8)
                .background(palette.background)
            }
            .background(palette.background.ignoresSafeArea())
            .sheet(isPresented: $showingCorrection) { CorrectionSheet(mode: .result(current: summary.doneUnits)) }
            .sheet(isPresented: $showingPerceived) { PerceivedTimeSheet() }
        }
    }

    private func comparisonCard(_ s: ResultSummary) -> some View {
        VStack(spacing: 0) {
            comparisonRow(
                label: "잡은 양", caption: "PLANNED", value: s.plannedValue, unit: s.plannedUnitLabel,
                detail: s.plannedDetail)
            Line()
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(height: 1)
                .padding(.vertical, 10)
            comparisonRow(
                label: "세션 시간", caption: "ACTIVE", value: s.activeValue, unit: s.activeUnitLabel, detail: s.activeDetail
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: Theme.CornerRadius.panel, style: .continuous).fill(palette.charcoal))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("result.card")
    }

    private func comparisonRow(label: LocalizedStringKey, caption: String, value: String, unit: String, detail: String)
        -> some View
    {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(AppFont.text(15, .medium, relativeTo: .subheadline)).foregroundStyle(.white)
                Text(caption).font(AppFont.number(10, .medium, relativeTo: .caption2)).foregroundStyle(
                    Color(hex: 0xB4B5BE))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(value).font(AppFont.number(34, .medium, relativeTo: .largeTitle)).foregroundStyle(.white)
                    Text(unit).font(AppFont.text(16, relativeTo: .callout)).foregroundStyle(.white)
                }
                Text(detail).font(AppFont.text(12, relativeTo: .caption)).foregroundStyle(Color(hex: 0xB4B5BE))
            }
        }
    }

    private func thoughtCard(_ note: ThoughtNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("세션 중 적어둔 생각").font(AppFont.text(12, relativeTo: .caption)).foregroundStyle(palette.muted)
            Text(note.text).font(AppFont.text(15, .medium, relativeTo: .body)).foregroundStyle(palette.ink)
            HStack(spacing: 16) {
                Button(note.kept ? "보관함에 있어요" : "보관하기") { store.keepThought(note.id) }
                    .disabled(note.kept)
                Button("지우기", role: .destructive) { store.deleteThought(note.id) }
            }
            .font(AppFont.text(12, .medium, relativeTo: .caption))
            .foregroundStyle(Palette.accentOutline)
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(palette.field))
    }

    private func perceivedRow(_ cp: SessionCheckpoint) -> some View {
        Button {
            showingPerceived = true
        } label: {
            Text(cp.perceivedMinutes.map { String(localized: "체감 시간 \($0)분") } ?? String(localized: "체감 시간 적기 (선택)"))
                .font(AppFont.text(13, .medium, relativeTo: .footnote))
                .foregroundStyle(palette.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityIdentifier("result.perceived")
    }
}

nonisolated private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// 결과 문구. 추정치를 실제 청취로 단정하지 않는다 (FR-015, DEC-06).
struct ResultSummary {
    var timeRange: String
    var plannedValue: String
    var plannedUnitLabel: String
    var plannedDetail: String
    var activeValue: String
    var activeUnitLabel: String
    var activeDetail: String
    var headline: String
    var legend: String
    var plannedUnits: Int?
    var doneUnits: Int
    var showsSongs: Bool

    init(cp: SessionCheckpoint) {
        let unit = cp.allocation.unitMs
        let noun = cp.displayMode == .singleLoop ? String(localized: "바퀴") : String(localized: "곡")
        let active = cp.accumulatedActiveMs
        let activeMinutes = TimeFormat.minutes(active)
        showsSongs = cp.displayMode != .timeOnly
        let estimated = SongMath.elapsedUnits(elapsedMs: active, unitMs: unit)
        doneUnits = cp.resultCorrectedUnits ?? Int(estimated.rounded(.down))

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        let start = formatter.string(from: Date(timeIntervalSince1970: Double(cp.startedAtEpochMs) / 1_000))
        let end = formatter.string(
            from: Date(timeIntervalSince1970: Double(cp.endedAtEpochMs ?? cp.updatedAtEpochMs) / 1_000))
        timeRange = String(localized: "세션 끝 · \(start) – \(end)")

        if let initial = cp.allocation.initialDurationMs {
            let planned = SongMath.plannedUnits(targetMs: initial, unitMs: unit)
            plannedUnits = planned
            plannedValue = showsSongs ? "\(planned)" : "\(initial / 60_000)"
            plannedUnitLabel = showsSongs ? String(localized: "\(noun) 분량") : String(localized: "분")
            plannedDetail = showsSongs ? TimeFormat.minutes(initial) : String(localized: "정한 시간")
        } else {
            plannedUnits = nil
            plannedValue = "∞"
            plannedUnitLabel = ""
            plannedDetail = String(localized: "시간 정하지 않음")
        }

        let valueText = cp.resultCorrectedUnits.map(String.init) ?? SongMath.format(estimated)
        activeValue = showsSongs ? valueText : "\(active / 60_000)"
        activeUnitLabel = showsSongs ? String(localized: "\(noun) 분량") : String(localized: "분")
        let source: String =
            switch cp.confidence {
            case .manual: String(localized: "직접 고친 값")
            case .mixed: String(localized: "직접 맞춘 번호 + 평균 길이 추정")
            default: String(localized: "평균 길이로 추정")
            }
        var detail = showsSongs ? String(localized: "\(activeMinutes) · \(source)") : String(localized: "세션 시간")
        if cp.extensionUsed {
            let added = cp.extensions.reduce(0) { $0 + $1.addedMs }
            detail += String(localized: " · 연장 +\(added / 60_000)분 포함")
        }
        activeDetail = detail

        if showsSongs, let planned = plannedUnits {
            headline = String(localized: "약 \(planned)\(noun) 분량을 잡고 · \(activeMinutes) 했어요")
            let extra = max(0, doneUnits - planned)
            legend =
                extra > 0
                ? String(localized: "● 잡은 \(planned)\(noun) 분량     ◌ 더 이어간 약 \(extra)\(noun) 분량")
                : String(localized: "● 잡은 \(planned)\(noun) 분량 중 약 \(min(doneUnits, planned))\(noun) 분량")
        } else {
            headline = String(localized: "\(activeMinutes) 동안 했어요")
            legend = ""
        }
    }
}
