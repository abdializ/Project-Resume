import Combine
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published var persistenceError: ProjectStoreError?

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let widgetSnapshotStore: WidgetSnapshotStore

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.widgetSnapshotStore = WidgetSnapshotStore(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        loadProjects()
    }

    var favoriteProjects: [Project] {
        projects
            .filter { project in project.isFavorite }
            .sorted(by: favoriteSort)
    }

    var recentProjects: [Project] {
        projects
            .filter { project in project.lastLaunchedAt == nil ? false : true }
            .sorted(by: recentSort)
    }

    var lastLaunchedProject: Project? {
        recentProjects.first
    }

    var launchShortcutProjects: [Project] {
        let featuredIDs = Set(favoriteProjects.map { project in project.id } + recentProjects.map { project in project.id })
        let remainder = projects.filter { project in featuredIDs.contains(project.id) == false }
        return Array((favoriteProjects + recentProjects + remainder).prefix(4))
    }

    func add(_ project: Project) {
        projects.append(project)
        persistProjects()
    }

    func update(_ project: Project) {
        guard let index = projects.firstIndex(where: { existingProject in existingProject.id == project.id }) else {
            add(project)
            return
        }

        projects[index] = project
        persistProjects()
    }

    func delete(_ project: Project) {
        projects.removeAll { existingProject in existingProject.id == project.id }
        persistProjects()
    }

    func toggleFavorite(_ project: Project) {
        guard let index = projects.firstIndex(where: { existingProject in existingProject.id == project.id }) else {
            return
        }

        projects[index].isFavorite.toggle()
        persistProjects()
    }

    func recordLaunch(of project: Project, at date: Date = .now) {
        guard let index = projects.firstIndex(where: { existingProject in existingProject.id == project.id }) else {
            return
        }

        projects[index].lastLaunchedAt = date
        persistProjects()
    }

    func updateNote(for projectID: UUID, note: String, at date: Date = .now) {
        guard let index = projects.firstIndex(where: { project in project.id == projectID }) else {
            return
        }

        projects[index].lastNote = note
        projects[index].updatedAt = date
        persistProjects()
    }

    @discardableResult
    func pruneExpiredCapturedProjects(retentionDays: Int?) -> Int {
        guard let retentionDays else {
            return 0
        }

        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) ?? .distantPast
        let originalCount = projects.count

        projects.removeAll { project in
            guard let sessionCapturedAt = project.sessionCapturedAt else {
                return false
            }

            return sessionCapturedAt < cutoff
        }

        let removedCount = originalCount - projects.count
        if removedCount > 0 {
            persistProjects()
        }

        return removedCount
    }

    func clearError() {
        persistenceError = nil
    }

    private func loadProjects() {
        do {
            try migrateLegacyProjectsIfNeeded()
            let fileURL = try storageFileURL()

            if fileManager.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                projects = sortProjects(try decoder.decode([Project].self, from: data))
            } else {
                projects = sortProjects(SampleProjects.items)
                try saveProjects()
            }

            syncWidgetSnapshot()
        } catch {
            projects = sortProjects(SampleProjects.items)
            syncWidgetSnapshot()
            persistenceError = ProjectStoreError(
                operation: "load",
                underlyingError: error
            )
        }
    }

    private func persistProjects() {
        projects = sortProjects(projects)

        do {
            try saveProjects()
            syncWidgetSnapshot()
        } catch {
            persistenceError = ProjectStoreError(
                operation: "save",
                underlyingError: error
            )
        }
    }

    private func saveProjects() throws {
        let directoryURL = try storageDirectoryURL()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let data = try encoder.encode(projects)
        try data.write(to: directoryURL.appendingPathComponent("projects.json"), options: .atomic)
    }

    private func syncWidgetSnapshot() {
        do {
            try widgetSnapshotStore.writeSnapshot(for: projects)
#if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
#endif
        } catch {
            persistenceError = ProjectStoreError(
                operation: "update widget snapshot",
                underlyingError: error
            )
        }
    }

    private func migrateLegacyProjectsIfNeeded() throws {
        guard let sharedContainerURL = sharedProjectsDirectoryURL(),
              let legacyFileURL = legacyProjectsFileURL(),
              fileManager.fileExists(atPath: legacyFileURL.path) else {
            return
        }

        let sharedFileURL = sharedContainerURL.appendingPathComponent("projects.json")
        guard !fileManager.fileExists(atPath: sharedFileURL.path) else {
            return
        }

        try fileManager.createDirectory(
            at: sharedContainerURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let data = try Data(contentsOf: legacyFileURL)
        try data.write(to: sharedFileURL, options: .atomic)
    }

    private func storageDirectoryURL() throws -> URL {
        if let sharedDirectoryURL = sharedProjectsDirectoryURL() {
            return sharedDirectoryURL
        }

        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupportURL.appendingPathComponent("ProjectResume", isDirectory: true)
    }

    private func storageFileURL() throws -> URL {
        let directoryURL = try storageDirectoryURL()
        return directoryURL.appendingPathComponent("projects.json")
    }

    private func sharedProjectsDirectoryURL() -> URL? {
        guard let appGroupIdentifier = WidgetBridge.appGroupIdentifier,
              let groupContainerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }

        return groupContainerURL.appendingPathComponent("ProjectResume", isDirectory: true)
    }

    private func legacyProjectsFileURL() -> URL? {
        let applicationSupportURL: URL
        do {
            applicationSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        } catch {
            return nil
        }

        return applicationSupportURL
            .appendingPathComponent("ProjectResume", isDirectory: true)
            .appendingPathComponent("projects.json")
    }

    private func sortProjects(_ projects: [Project]) -> [Project] {
        projects.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func favoriteSort(lhs: Project, rhs: Project) -> Bool {
        if let lhsLaunch = lhs.lastLaunchedAt, let rhsLaunch = rhs.lastLaunchedAt, lhsLaunch != rhsLaunch {
            return lhsLaunch > rhsLaunch
        }

        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func recentSort(lhs: Project, rhs: Project) -> Bool {
        switch (lhs.lastLaunchedAt, rhs.lastLaunchedAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate > rhsDate
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

struct ProjectStoreError: Identifiable, LocalizedError {
    let id = UUID()
    let operation: String
    let underlyingError: Error

    var errorDescription: String? {
        "Failed to " + operation + " projects."
    }

    var recoverySuggestion: String? {
        underlyingError.localizedDescription
    }
}
