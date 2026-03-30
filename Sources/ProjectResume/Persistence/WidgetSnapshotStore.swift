import Foundation

struct WidgetSnapshotStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let appGroupIdentifier: String?

    init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String? = WidgetBridge.appGroupIdentifier
    ) {
        self.fileManager = fileManager
        self.appGroupIdentifier = appGroupIdentifier

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func writeSnapshot(for projects: [Project]) throws {
        let directoryURL = try snapshotDirectoryURL()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let snapshot = WidgetSnapshot.fromProjects(projects)
        let data = try encoder.encode(snapshot)
        try data.write(to: directoryURL.appendingPathComponent("widget-snapshot.json"), options: .atomic)
    }

    func readSnapshot() throws -> WidgetSnapshot? {
        let fileURL = try snapshotFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(WidgetSnapshot.self, from: data)
    }

    func snapshotFileURL() throws -> URL {
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
}
