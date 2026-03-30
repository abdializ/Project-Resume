import Foundation

public struct WidgetSnapshot: Codable, Equatable {
    public var generatedAt: Date
    public var accentTheme: AppAccentTheme
    public var lastProject: WidgetProjectSnapshot?
    public var favoriteProjects: [WidgetProjectSnapshot]

    public init(
        generatedAt: Date,
        accentTheme: AppAccentTheme,
        lastProject: WidgetProjectSnapshot?,
        favoriteProjects: [WidgetProjectSnapshot] = []
    ) {
        self.generatedAt = generatedAt
        self.accentTheme = accentTheme
        self.lastProject = lastProject
        self.favoriteProjects = favoriteProjects
    }

    public static var preview: WidgetSnapshot {
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

public struct WidgetProjectSnapshot: Codable, Equatable {
    public var id: UUID
    public var name: String
    public var iconSymbol: String?
    public var appCount: Int
    public var linkCount: Int
    public var commandCount: Int
    public var folderName: String?
    public var notePreview: String?
    public var updatedAt: Date
    public var lastLaunchedAt: Date?
    public var isFavorite: Bool

    public init(
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconSymbol = try container.decodeIfPresent(String.self, forKey: .iconSymbol)
        appCount = try container.decode(Int.self, forKey: .appCount)
        linkCount = try container.decode(Int.self, forKey: .linkCount)
        commandCount = try container.decodeIfPresent(Int.self, forKey: .commandCount) ?? 0
        folderName = try container.decodeIfPresent(String.self, forKey: .folderName)
        notePreview = try container.decodeIfPresent(String.self, forKey: .notePreview)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastLaunchedAt = try container.decodeIfPresent(Date.self, forKey: .lastLaunchedAt)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    public var resolvedIconSymbol: String {
        if let iconSymbol, !iconSymbol.isEmpty { return iconSymbol }
        if commandCount > 0 { return "terminal" }
        if linkCount > 0 && appCount == 0 { return "globe" }
        if folderName != nil { return "folder" }
        if appCount > 0 { return "square.grid.2x2" }
        if notePreview != nil { return "note.text" }
        return "briefcase"
    }

    public var totalResourceCount: Int {
        appCount + linkCount + commandCount
    }

    public static var preview: WidgetProjectSnapshot {
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
