import Foundation

struct ProjectDraft {
    var sourceProjectID: UUID?
    var createdAt: Date?
    var name: String
    var iconSymbol: String?
    var projectDescription: String
    var folderPath: String
    var folderLaunchMode: FolderLaunchMode
    var apps: [String]
    var urls: [String]
    var terminalCommands: [String]
    var lastNote: String
    var isFavorite: Bool
    var sessionCapturedAt: Date?

    init(
        sourceProjectID: UUID? = nil,
        createdAt: Date? = nil,
        name: String = "",
        iconSymbol: String? = nil,
        projectDescription: String = "",
        folderPath: String = "",
        folderLaunchMode: FolderLaunchMode = .finder,
        apps: [String] = [],
        urls: [String] = [],
        terminalCommands: [String] = [],
        lastNote: String = "",
        isFavorite: Bool = false,
        sessionCapturedAt: Date? = nil,
        project: Project? = nil
    ) {
        if let project {
            self.sourceProjectID = project.id
            self.createdAt = project.createdAt
            self.name = project.name
            self.iconSymbol = project.iconSymbol
            self.projectDescription = project.projectDescription
            self.folderPath = project.folderPath
            self.folderLaunchMode = project.folderLaunchMode
            self.apps = project.apps
            self.urls = project.urls
            self.terminalCommands = project.terminalCommands
            self.lastNote = project.lastNote
            self.isFavorite = project.isFavorite
            self.sessionCapturedAt = project.sessionCapturedAt
            return
        }

        self.sourceProjectID = sourceProjectID
        self.createdAt = createdAt
        self.name = name
        self.iconSymbol = iconSymbol?.nilIfBlank
        self.projectDescription = projectDescription
        self.folderPath = folderPath
        self.folderLaunchMode = folderLaunchMode
        self.apps = apps
        self.urls = urls
        self.terminalCommands = terminalCommands
        self.lastNote = lastNote
        self.isFavorite = isFavorite
        self.sessionCapturedAt = sessionCapturedAt
    }

    var isValid: Bool {
        !name.trimmed.isEmpty
    }

    func buildProject(now: Date = .now) -> Project {
        Project(
            id: sourceProjectID ?? UUID(),
            name: name.trimmed,
            iconSymbol: iconSymbol?.nilIfBlank,
            projectDescription: projectDescription.trimmed,
            folderPath: folderPath.trimmed,
            folderLaunchMode: folderLaunchMode,
            apps: apps.normalizedEntries(),
            urls: urls.normalizedEntries(),
            terminalCommands: terminalCommands.normalizedEntries(),
            lastNote: lastNote.trimmed,
            isFavorite: isFavorite,
            sessionCapturedAt: sessionCapturedAt,
            createdAt: createdAt ?? now,
            updatedAt: now
        )
    }
}
