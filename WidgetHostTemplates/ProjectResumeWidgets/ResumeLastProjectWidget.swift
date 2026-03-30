import SwiftUI
import WidgetKit
import ProjectResumeWidgetSupport

struct ResumeLastProjectEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct ResumeLastProjectProvider: TimelineProvider {
    func placeholder(in context: Context) -> ResumeLastProjectEntry {
        ResumeLastProjectEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ResumeLastProjectEntry) -> Void) {
        completion(ResumeLastProjectEntry(date: .now, snapshot: loadSnapshot() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ResumeLastProjectEntry>) -> Void) {
        let entry = ResumeLastProjectEntry(date: .now, snapshot: loadSnapshot() ?? .preview)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadSnapshot() -> WidgetSnapshot? {
        try? WidgetSnapshotStore().readSnapshot()
    }
}

struct ResumeLastProjectWidgetView: View {
    let entry: ResumeLastProjectProvider.Entry
    @Environment(\.widgetFamily) private var widgetFamily

    private var launchURL: URL? {
        guard let projectID = entry.snapshot.lastProject?.id else { return nil }
        return WidgetBridge.projectURL(for: projectID)
    }

    private var captureURL: URL? {
        WidgetBridge.captureURL()
    }

    private var cardStyle: ResumeProjectWidgetCardStyle {
        switch widgetFamily {
        case .systemSmall: return .small
        case .systemLarge: return .large
        default: return .medium
        }
    }

    var body: some View {
        Group {
            if launchURL != nil {
                ResumeProjectWidgetCard(
                    snapshot: entry.snapshot,
                    style: cardStyle,
                    launchURL: launchURL,
                    captureURL: captureURL
                )
            } else {
                ResumeProjectWidgetCard(
                    snapshot: entry.snapshot,
                    style: cardStyle
                )
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct ResumeLastProjectWidget: Widget {
    let kind = "ResumeLastProjectWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ResumeLastProjectProvider()) { entry in
            ResumeLastProjectWidgetView(entry: entry)
        }
        .configurationDisplayName("Resume Last Project")
        .description("Quickly jump back into your most recently launched project.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    ResumeLastProjectWidget()
} timeline: {
    ResumeLastProjectEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    ResumeLastProjectWidget()
} timeline: {
    ResumeLastProjectEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemLarge) {
    ResumeLastProjectWidget()
} timeline: {
    ResumeLastProjectEntry(date: .now, snapshot: .preview)
}
