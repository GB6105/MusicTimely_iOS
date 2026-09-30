import SwiftUI
import WidgetKit

/// 잠금화면 위젯 (rectangular / circular / inline). 갱신 예산에 기대지 않도록 곡 수·초 단위 값은 넣지 않는다.
struct LauncherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MusicTimelyLauncher", provider: LauncherProvider()) { _ in
            LauncherWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(AppLink.session)
        }
        .configurationDisplayName("집중 세션")
        .description("잠금화면에서 바로 집중 세션을 열어요.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct LauncherEntry: TimelineEntry {
    let date: Date
}

struct LauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry { LauncherEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (LauncherEntry) -> Void) {
        completion(LauncherEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LauncherEntry>) -> Void) {
        completion(Timeline(entries: [LauncherEntry(date: .now)], policy: .never))
    }
}

struct LauncherWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 2) {
                RecordGlyph().frame(width: 26, height: 26)
                Text("열기").font(.system(size: 10, weight: .semibold))
            }
            .accessibilityLabel("집중 세션 열기")
        case .accessoryInline:
            Text("집중 세션 · 앱에서 이어보기")
        default:
            HStack(spacing: 8) {
                RecordGlyph().frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("집중 세션").font(.system(size: 15, weight: .semibold)).widgetAccentable()
                    Text("앱에서 이어보기").font(.system(size: 11))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// 단색 vibrant 렌더링용 레코드 기호.
struct RecordGlyph: View {
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 2.5)
            Circle().frame(width: 8, height: 8)
        }
        .padding(2)
    }
}
