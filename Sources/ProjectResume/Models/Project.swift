import Foundation

struct Project: Identifiable, Codable, Hashable {
    var id: UUID
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
    var lastLaunchedAt: Date?
    var sessionCapturedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var hasFolder: Bool {
        folderPath.nilIfBlank != nil
    }

    init(
        id: UUID,
        name: String,
        iconSymbol: String? = nil,
        projectDescription: String,
        folderPath: String,
        folderLaunchMode: FolderLaunchMode,
        apps: [String],
        urls: [String],
        terminalCommands: [String],
        lastNote: String,
        isFavorite: Bool = false,
        lastLaunchedAt: Date? = nil,
        sessionCapturedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
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
        self.lastLaunchedAt = lastLaunchedAt
        self.sessionCapturedAt = sessionCapturedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconSymbol = try container.decodeIfPresent(String.self, forKey: .iconSymbol)
        projectDescription = try container.decode(String.self, forKey: .projectDescription)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        folderLaunchMode = try container.decode(FolderLaunchMode.self, forKey: .folderLaunchMode)
        apps = try container.decode([String].self, forKey: .apps)
        urls = try container.decode([String].self, forKey: .urls)
        terminalCommands = try container.decode([String].self, forKey: .terminalCommands)
        lastNote = try container.decode(String.self, forKey: .lastNote)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastLaunchedAt = try container.decodeIfPresent(Date.self, forKey: .lastLaunchedAt)
        sessionCapturedAt = try container.decodeIfPresent(Date.self, forKey: .sessionCapturedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconSymbol
        case projectDescription
        case folderPath
        case folderLaunchMode
        case apps
        case urls
        case terminalCommands
        case lastNote
        case isFavorite
        case lastLaunchedAt
        case sessionCapturedAt
        case createdAt
        case updatedAt
    }

    var resolvedIconSymbol: String {
        if let iconSymbol, !iconSymbol.isEmpty {
            return iconSymbol
        }

        if !terminalCommands.normalizedEntries().isEmpty {
            return "terminal"
        }

        if !urls.normalizedEntries().isEmpty && apps.normalizedEntries().isEmpty {
            return "globe"
        }

        if hasFolder {
            return "folder"
        }

        if !apps.normalizedEntries().isEmpty {
            return "square.grid.2x2"
        }

        if !lastNote.trimmed.isEmpty {
            return "note.text"
        }

        return "briefcase"
    }
}

struct FolderLaunchMode: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case finder
        case application
    }

    var kind: Kind
    var applicationEntry: String?

    static let finder = FolderLaunchMode(kind: .finder, applicationEntry: nil)
    static let vscode = FolderLaunchMode(kind: .application, applicationEntry: "com.microsoft.VSCode")

    var id: String {
        switch kind {
        case .finder:
            return "finder"
        case .application:
            return "application:\(applicationEntry ?? "")"
        }
    }

    var title: String {
        switch kind {
        case .finder:
            return "Finder"
        case .application:
            return ApplicationCatalog.displayName(for: applicationEntry ?? "")
        }
    }

    var isFinder: Bool {
        kind == .finder
    }

    static func application(_ entry: String) -> FolderLaunchMode {
        FolderLaunchMode(kind: .application, applicationEntry: entry)
    }

    init(kind: Kind, applicationEntry: String?) {
        self.kind = kind
        self.applicationEntry = applicationEntry?.nilIfBlank
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let legacyValue = try? singleValue.decode(String.self) {
            switch legacyValue {
            case "finder":
                self = .finder
            case "vscode":
                self = .vscode
            default:
                self = .application(legacyValue)
            }
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let applicationEntry = try container.decodeIfPresent(String.self, forKey: .applicationEntry)
        self.init(kind: kind, applicationEntry: applicationEntry)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(applicationEntry, forKey: .applicationEntry)
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case applicationEntry
    }
}
