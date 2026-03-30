import Foundation

enum SampleProjects {
    static var items: [Project] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let seedURL = Bundle.module.url(forResource: "SeedProjects", withExtension: "json"),
           let data = try? Data(contentsOf: seedURL),
           let projects = try? decoder.decode([Project].self, from: data) {
            return projects
        }

        return fallback
    }

    private static var fallback: [Project] {
        [
            Project(
                id: UUID(uuidString: "B5536568-A21C-4689-B8D2-AF0D8E7E41B3") ?? UUID(),
                name: "Acme Dashboard",
                projectDescription: "Frontend workspace for the main customer dashboard.",
                folderPath: "/Users/Shared/AcmeDashboard",
                folderLaunchMode: .vscode,
                apps: [
                    "Visual Studio Code",
                    "Safari",
                    "Slack"
                ],
                urls: [
                    "https://github.com/example/acme-dashboard",
                    "https://linear.app/"
                ],
                terminalCommands: [
                    "npm install",
                    "npm run dev"
                ],
                lastNote: "Resume the release checklist and verify the staging deploy.",
                createdAt: ISO8601DateFormatter().date(from: "2026-01-10T15:00:00Z") ?? .now,
                updatedAt: ISO8601DateFormatter().date(from: "2026-03-11T09:30:00Z") ?? .now
            ),
            Project(
                id: UUID(uuidString: "4D0FC3E7-DF3A-4A84-B7C1-5A93A6B4D9F1") ?? UUID(),
                name: "Client Audit",
                projectDescription: "Review notes, spreadsheet work, and browser links for the quarterly audit.",
                folderPath: "/Users/Shared/ClientAudit",
                folderLaunchMode: .finder,
                apps: [
                    "Numbers",
                    "Notes"
                ],
                urls: [
                    "https://docs.google.com/",
                    "https://calendar.google.com/"
                ],
                terminalCommands: [
                    "git status"
                ],
                lastNote: "Check the missing invoice references before the client call.",
                createdAt: ISO8601DateFormatter().date(from: "2026-02-04T12:45:00Z") ?? .now,
                updatedAt: ISO8601DateFormatter().date(from: "2026-03-13T18:10:00Z") ?? .now
            )
        ]
    }
}
