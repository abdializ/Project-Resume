import Foundation

public struct WidgetSnapshotStore {
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let appGroupIdentifier: String?

    public init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String? = WidgetBridge.appGroupIdentifier
    ) {
        self.fileManager = fileManager
        self.appGroupIdentifier = appGroupIdentifier

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func readSnapshot() throws -> WidgetSnapshot? {
        let fileURL = try snapshotFileURL()
        if fileManager.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(WidgetSnapshot.self, from: data)
        }

        return try readFallbackSnapshotFromProjects()
    }

    public func snapshotFileURL() throws -> URL {
        try snapshotDirectoryURL().appendingPathComponent("widget-snapshot.json")
    }

    private func snapshotDirectoryURL() throws -> URL {
        if let appGroupIdentifier,
           let groupContainerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupContainerURL.appendingPathComponent("WidgetData", isDirectory: true)
        }

        if let manualGroupContainerURL = WidgetBridge.manualAppGroupContainerURL(fileManager: fileManager) {
            return manualGroupContainerURL.appendingPathComponent("WidgetData", isDirectory: true)
        }

        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupportURL
            .appendingPathComponent("ProjectResume", isDirectory: true)
            .appendingPathComponent("WidgetData", isDirectory: true)
    }

    private func readFallbackSnapshotFromProjects() throws -> WidgetSnapshot? {
        let projectsFileURL = try projectsFileURL()
        guard fileManager.fileExists(atPath: projectsFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: projectsFileURL)
        let projects = try decoder.decode([FallbackProject].self, from: data)
        let sortedProjects = projects.sorted(by: FallbackProject.widgetSort)
        guard let lastProject = sortedProjects.first(where: { $0.lastLaunchedAt != nil }) else {
            return nil
        }

        return WidgetSnapshot(
            generatedAt: .now,
            accentTheme: WidgetBridge.currentAccentTheme(),
            lastProject: WidgetProjectSnapshot(project: lastProject),
            favoriteProjects: sortedProjects
                .filter(\.isFavorite)
                .prefix(4)
                .map(WidgetProjectSnapshot.init(project:))
        )
    }

    private func projectsFileURL() throws -> URL {
        if let appGroupIdentifier,
           let groupContainerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupContainerURL
                .appendingPathComponent("ProjectResume", isDirectory: true)
                .appendingPathComponent("projects.json")
        }

        if let manualGroupContainerURL = WidgetBridge.manualAppGroupContainerURL(fileManager: fileManager) {
            return manualGroupContainerURL
                .appendingPathComponent("ProjectResume", isDirectory: true)
                .appendingPathComponent("projects.json")
        }

        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupportURL
            .appendingPathComponent("ProjectResume", isDirectory: true)
            .appendingPathComponent("projects.json")
    }
}

private struct FallbackProject: Codable {
    let id: UUID
    let name: String
    let iconSymbol: String?
    let apps: [String]
    let urls: [String]
    let terminalCommands: [String]
    let folderPath: String
    let lastNote: String
    let updatedAt: Date
    let lastLaunchedAt: Date?
    let isFavorite: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconSymbol = try container.decodeIfPresent(String.self, forKey: .iconSymbol)
        apps = try container.decode([String].self, forKey: .apps)
        urls = try container.decode([String].self, forKey: .urls)
        terminalCommands = try container.decodeIfPresent([String].self, forKey: .terminalCommands) ?? []
        folderPath = try container.decodeIfPresent(String.self, forKey: .folderPath) ?? ""
        lastNote = try container.decode(String.self, forKey: .lastNote)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastLaunchedAt = try container.decodeIfPresent(Date.self, forKey: .lastLaunchedAt)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    static func widgetSort(lhs: FallbackProject, rhs: FallbackProject) -> Bool {
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
}

private extension WidgetProjectSnapshot {
    init(project: FallbackProject) {
        let folderName: String? = {
            let trimmed = project.folderPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return URL(fileURLWithPath: trimmed).lastPathComponent
        }()

        self.init(
            id: project.id,
            name: project.name,
            iconSymbol: project.iconSymbol,
            appCount: project.apps.normalizedEntries().count,
            linkCount: project.urls.normalizedEntries().count,
            commandCount: project.terminalCommands.normalizedEntries().count,
            folderName: folderName,
            notePreview: project.lastNote.widgetPreviewText,
            updatedAt: project.updatedAt,
            lastLaunchedAt: project.lastLaunchedAt,
            isFavorite: project.isFavorite
        )
    }
}

private extension Array where Element == String {
    func normalizedEntries() -> [String] {
        compactMap { entry in
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

private extension String {
    var widgetPreviewText: String? {
        let firstMeaningfulLine = split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        let source = firstMeaningfulLine ?? trimmingCharacters(in: .whitespacesAndNewlines)
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
