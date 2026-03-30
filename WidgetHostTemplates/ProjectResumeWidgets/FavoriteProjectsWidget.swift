import SwiftUI
import WidgetKit
import ProjectResumeWidgetSupport

struct FavoriteProjectsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct FavoriteProjectsProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoriteProjectsEntry {
        FavoriteProjectsEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoriteProjectsEntry) -> Void) {
        completion(FavoriteProjectsEntry(date: .now, snapshot: loadSnapshot() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoriteProjectsEntry>) -> Void) {
        let entry = FavoriteProjectsEntry(date: .now, snapshot: loadSnapshot() ?? .preview)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadSnapshot() -> WidgetSnapshot? {
        try? WidgetSnapshotStore().readSnapshot()
    }
}

struct FavoriteProjectsWidgetView: View {
    let entry: FavoriteProjectsProvider.Entry
    @Environment(\.widgetFamily) private var widgetFamily

    private var cardStyle: ResumeProjectWidgetCardStyle {
        switch widgetFamily {
        case .systemSmall: return .small
        case .systemLarge: return .large
        default: return .medium
        }
    }

    var body: some View {
        FavoriteProjectsWidgetCard(
            snapshot: entry.snapshot,
            style: cardStyle
        )
        .containerBackground(.clear, for: .widget)
    }
}

struct FavoriteProjectsWidget: Widget {
    let kind = "FavoriteProjectsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoriteProjectsProvider()) { entry in
            FavoriteProjectsWidgetView(entry: entry)
        }
        .configurationDisplayName("Favorite Projects")
        .description("Quick access to your starred projects from the desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    FavoriteProjectsWidget()
} timeline: {
    FavoriteProjectsEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    FavoriteProjectsWidget()
} timeline: {
    FavoriteProjectsEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemLarge) {
    FavoriteProjectsWidget()
} timeline: {
    FavoriteProjectsEntry(date: .now, snapshot: .preview)
}
