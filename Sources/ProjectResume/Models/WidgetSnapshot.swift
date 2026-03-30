import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var generatedAt: Date
    var accentTheme: AppAccentTheme
    var lastProject: WidgetProjectSnapshot?
    var favoriteProjects: [WidgetProjectSnapshot]

    static func fromProjects(
        _ projects: [Project],
        accentTheme: AppAccentTheme = WidgetBridge.currentAccentTheme(),
        generatedAt: Date = .now
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: generatedAt,
            accentTheme: accentTheme,
            lastProject: projects
                .sorted { lhs, rhs in
                    switch (lhs.lastLaunchedAt, rhs.lastLaunchedAt) {
                    case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                        return lhsDate > rhsDate
                    case (.some, nil):
                        return true
                    case (nil, .some):
                        return false
                    default:
                        return lhs.updatedAt > rhs.updatedAt
                    }
                }
                .first(where: { $0.lastLaunchedAt != nil })
                .map(WidgetProjectSnapshot.init(project:)),
            favoriteProjects: projects
                .filter(\.isFavorite)
                .sorted { lhs, rhs in
                    switch (lhs.lastLaunchedAt, rhs.lastLaunchedAt) {
                    case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                        return lhsDate > rhsDate
                    case (.some, nil):
                        return true
                    case (nil, .some):
                        return false
                    default:
                        return lhs.updatedAt > rhs.updatedAt
                    }
                }
                .prefix(4)
                .map(WidgetProjectSnapshot.init(project:))
        )
    }

    static var preview: WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: .now,
            accentTheme: .rose,
            lastProject: WidgetProjectSnapshot.preview,
            favoriteProjects: [
                WidgetProjectSnapshot.preview,
                WidgetProjectSnapshot(
                    id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
                    name: "Acme Dashboard",
                    iconSymbol: "chart.bar",
                    appCount: 3,
                    linkCount: 2,
                    commandCount: 2,
                    folderName: "acme-dashboard",
                    notePreview: "Review staging before the client check-in.",
                    updatedAt: .now.addingTimeInterval(-7200),
                    lastLaunchedAt: .now.addingTimeInterval(-5400),
                    isFavorite: true
                ),
                WidgetProjectSnapshot(
                    id: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF") ?? UUID(),
                    name: "Design System",
                    iconSymbol: "paintbrush",
                    appCount: 2,
                    linkCount: 3,
                    commandCount: 0,
                    folderName: "design-system",
                    notePreview: nil,
                    updatedAt: .now.addingTimeInterval(-14400),
                    lastLaunchedAt: .now.addingTimeInterval(-10800),
                    isFavorite: true
                ),
                WidgetProjectSnapshot(
                    id: UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-AAAAAAAAAAAA") ?? UUID(),
                    name: "API Server",
                    iconSymbol: "terminal",
                    appCount: 1,
                    linkCount: 4,
                    commandCount: 3,
                    folderName: "api-server",
                    notePreview: "Migrate to the new auth middleware.",
                    updatedAt: .now.addingTimeInterval(-28800),
                    lastLaunchedAt: .now.addingTimeInterval(-21600),
                    isFavorite: true
                )
            ]
        )
    }
}

struct WidgetProjectSnapshot: Codable, Equatable {
    var id: UUID
    var name: String
    var iconSymbol: String?
    var appCount: Int
    var linkCount: Int
    var commandCount: Int
    var folderName: String?
    var notePreview: String?
    var updatedAt: Date
    var lastLaunchedAt: Date?
    var isFavorite: Bool

    init(
        id: UUID,
        name: String,
        iconSymbol: String? = nil,
        appCount: Int,
        linkCount: Int,
        commandCount: Int = 0,
        folderName: String? = nil,
        notePreview: String?,
        updatedAt: Date,
        lastLaunchedAt: Date?,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        self.appCount = appCount
        self.linkCount = linkCount
        self.commandCount = commandCount
        self.folderName = folderName
        self.notePreview = notePreview
        self.updatedAt = updatedAt
        self.lastLaunchedAt = lastLaunchedAt
        self.isFavorite = isFavorite
    }

    init(project: Project) {
        id = project.id
        name = project.name
        iconSymbol = project.resolvedIconSymbol
        appCount = project.apps.normalizedEntries().count
        linkCount = project.urls.normalizedEntries().count
        commandCount = project.terminalCommands.normalizedEntries().count
        folderName = project.folderPath.nilIfBlank.map {
            URL(fileURLWithPath: $0).lastPathComponent
        }
        notePreview = project.lastNote.widgetPreviewText
        updatedAt = project.updatedAt
        lastLaunchedAt = project.lastLaunchedAt
        isFavorite = project.isFavorite
    }

    var resolvedIconSymbol: String {
        if let iconSymbol, !iconSymbol.isEmpty { return iconSymbol }
        if commandCount > 0 { return "terminal" }
        if linkCount > 0 && appCount == 0 { return "globe" }
        if folderName != nil { return "folder" }
        if appCount > 0 { return "square.grid.2x2" }
        if notePreview != nil { return "note.text" }
        return "briefcase"
    }

    var totalResourceCount: Int {
        appCount + linkCount + commandCount
    }

    static var preview: WidgetProjectSnapshot {
        WidgetProjectSnapshot(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID(),
            name: "Resume App",
            iconSymbol: "hammer",
            appCount: 4,
            linkCount: 2,
            commandCount: 1,
            folderName: "resume-app",
            notePreview: "Pick up the dashboard refactor and verify the launch flow before shipping.",
            updatedAt: .now,
            lastLaunchedAt: .now,
            isFavorite: true
        )
    }
}

private extension String {
    var widgetPreviewText: String? {
        let firstMeaningfulLine = split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        let source = firstMeaningfulLine ?? trimmed
        guard !source.isEmpty else {
            return nil
        }

        if source.count <= 96 {
            return source
        }

        let index = source.index(source.startIndex, offsetBy: 93)
        return String(source[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
