import AppKit
import SwiftUI

struct QuickAccessPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: ProjectStore
    let launcher: ProjectLauncher
    @ObservedObject var settingsStore: AppSettingsStore
    let sessionTracker: SessionTracker
    let onClose: () -> Void

    @State private var query = ""
    @State private var statusMessage = "Search a project or save a fresh session snapshot."

    private var appAccentColor: Color {
        settingsStore.accentTheme.resolvedAccentColor(for: colorScheme)
    }

    private var darkSurfaceColor: Color {
        settingsStore.accentTheme.darkModeSurfaceColor
    }

    private var filteredProjects: [Project] {
        let normalizedQuery = query.trimmed
        guard !normalizedQuery.isEmpty else {
            return Array(store.projects.prefix(8))
        }

        return store.projects.filter { project in
            project.name.localizedCaseInsensitiveContains(normalizedQuery)
                || project.projectDescription.localizedCaseInsensitiveContains(normalizedQuery)
                || project.lastNote.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var resultSummary: String {
        let count = filteredProjects.count
        return count == 1 ? "1 workspace" : "\(count) workspaces"
    }

    private var favoriteProjects: [Project] {
        Array(store.favoriteProjects.prefix(4))
    }

    private var recentProjects: [Project] {
        Array(store.recentProjects.filter { !$0.isFavorite }.prefix(4))
    }

    private var libraryProjects: [Project] {
        let featuredIDs = Set(favoriteProjects.map(\.id) + recentProjects.map(\.id))
        return Array(store.projects.filter { !featuredIDs.contains($0.id) }.prefix(8))
    }

    private var retentionSummary: String {
        if let days = settingsStore.sessionRetentionDays {
            return "Auto-clear session snapshots after \(days) day\(days == 1 ? "" : "s")"
        }

        return "Keep session snapshots until you delete them"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            searchField
            quickActions
            projectResults
            footer
        }
        .padding(22)
        .frame(width: 560, height: 620, alignment: .topLeading)
        .tint(appAccentColor)
        .background(
            ZStack {
                GlassSidebarBackground(material: .sidebar)

                Rectangle()
                    .fill(panelToneOverlay)

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.11 : 0.045)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.025 : 0.015), lineWidth: 0.6)
        )
        .onAppear {
            query = ""
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Access")
                    .font(.system(size: 24, weight: .semibold))

                Text("Launch a workspace, start a fresh session snapshot, or adjust retention without leaving what you are doing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(settingsStore.quickAccessShortcut.displayString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(fieldFill))

                retentionMenu
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search projects, notes, or descriptions", text: $query)
                .textFieldStyle(.plain)
                .font(.body)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(fieldFill)
        )
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionButton(
                title: "Save Session",
                subtitle: "Create a snapshot now",
                systemImage: "clock.badge.checkmark"
            ) {
                saveCurrentSession()
            }

            quickActionButton(
                title: "New Project",
                subtitle: "Open the full editor",
                systemImage: "square.and.pencil"
            ) {
                showNewProjectEditor()
            }

            quickActionButton(
                title: "Resume Last",
                subtitle: store.lastLaunchedProject?.name ?? "Nothing launched yet",
                systemImage: "arrow.clockwise"
            ) {
                if let project = store.lastLaunchedProject {
                    launch(project)
                } else {
                    statusMessage = "Launch a project once to make it available here."
                }
            }

            if #available(macOS 14.0, *) {
                quickActionButton(
                    title: "Settings",
                    subtitle: "Shortcut and retention",
                    systemImage: "gearshape"
                ) {
                    showEmbeddedSettings()
                }
            } else {
                quickActionButton(
                    title: "Settings",
                    subtitle: "Shortcut and retention",
                    systemImage: "gearshape"
                ) {
                    showEmbeddedSettings()
                }
            }
        }
    }

    private var projectResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved Workspaces")
                        .font(.headline)

                    Text(resultSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

            if filteredProjects.isEmpty {
                EmptyStateView(
                    title: "No Matching Projects",
                    systemImage: "magnifyingglass",
                    message: query.isEmpty ? "Save a project and it will appear here." : "Try a different project name, note, or description."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if query.isEmpty {
                            if !favoriteProjects.isEmpty {
                                projectSection("Favorites", projects: favoriteProjects)
                            }

                            if !recentProjects.isEmpty {
                                projectSection("Recent", projects: recentProjects)
                            }

                            if !libraryProjects.isEmpty {
                                projectSection(favoriteProjects.isEmpty && recentProjects.isEmpty ? "Projects" : "Library", projects: libraryProjects)
                            }
                        } else {
                            projectSection("Matches", projects: filteredProjects)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(sectionFill)
        )
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(retentionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Dismiss", action: onClose)
                .buttonStyle(.bordered)
        }
    }

    private var retentionMenu: some View {
        Menu {
            Button("Keep Forever") {
                settingsStore.automaticallyDeleteCapturedSessions = false
            }

            Divider()

            retentionOption(days: 1)
            retentionOption(days: 3)
            retentionOption(days: 7)
            retentionOption(days: 14)
            retentionOption(days: 30)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text(settingsStore.sessionRetentionDays.map { "\($0)d retention" } ?? "Keep sessions")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(fieldFill))
        }
        .menuStyle(.borderlessButton)
    }

    private func retentionOption(days: Int) -> some View {
        Button(days == 1 ? "Delete after 1 day" : "Delete after \(days) days") {
            settingsStore.automaticallyDeleteCapturedSessions = true
            settingsStore.capturedSessionRetentionDays = days
            statusMessage = "Session retention set to \(days) day\(days == 1 ? "" : "s")."
        }
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            quickActionLabel(title: title, subtitle: subtitle, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func quickActionLabel(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFill)
        )
    }

    private func projectRow(_ project: Project) -> some View {
        Button {
            launch(project)
        } label: {
            HStack(spacing: 12) {
                projectRowIcon(for: project)

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(project.projectDescription.nilIfBlank ?? project.folderPath.nilIfBlank ?? "Quick launch project")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        compactMetaTag("\(project.apps.normalizedEntries().count) apps")
                        compactMetaTag("\(project.urls.normalizedEntries().count) links")
                        if project.sessionCapturedAt != nil {
                            compactMetaTag("session")
                        }
                        if project.isFavorite {
                            compactMetaTag("favorite")
                        }
                    }
                }

                HStack(spacing: 8) {
                    selectiveLaunchMenu(for: project)

                    Image(systemName: "arrow.up.forward")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(cardFill)
            )
        }
        .buttonStyle(.plain)
    }

    private func selectiveLaunchMenu(for project: Project) -> some View {
        Menu {
            ForEach(ProjectLaunchMode.allCases) { mode in
                Button {
                    launch(project, mode: mode)
                } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(fieldFill)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }

    private func projectSection(_ title: String, projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            VStack(spacing: 8) {
                ForEach(projects) { project in
                    projectRow(project)
                }
            }
        }
    }

    private func launch(_ project: Project, mode: ProjectLaunchMode = .everything) {
        Task {
            let result = await launcher.launch(project, mode: mode)
            store.recordLaunch(of: project)

            if result.hasWarnings {
                statusMessage = result.warnings.first ?? "Launched with warnings."
            } else {
                statusMessage = mode == .everything ? "Launched \(project.name)." : "Launched \(mode.title.lowercased()) for \(project.name)."
            }

            if settingsStore.closeQuickAccessAfterLaunch {
                onClose()
            }
        }
    }

    private func saveCurrentSession() {
        let generator = SessionProjectGenerator(sessionTracker: sessionTracker)
        let generated = generator.generateDraft()
        var project = generated.draft.buildProject()

        if store.projects.contains(where: { $0.name == project.name }) {
            let suffix = Date().formatted(date: .omitted, time: .shortened)
            project.name = "\(project.name) \(suffix)"
        }

        store.add(project)

        if let days = settingsStore.sessionRetentionDays {
            statusMessage = "Saved a session snapshot. It will auto-clear after \(days) day\(days == 1 ? "" : "s")."
        } else {
            statusMessage = "Saved a session snapshot."
        }
    }

    private func showEmbeddedSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.identifier?.rawValue == "ProjectResumeMainWindow" })?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .projectResumeShowSettingsRequested, object: nil)
        onClose()
    }

    private func showNewProjectEditor() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.identifier?.rawValue == "ProjectResumeMainWindow" })?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .projectResumeNewProjectRequested, object: nil)
        onClose()
    }

    private func projectRowIcon(for project: Project) -> some View {
        ProjectBadgeView(
            project: project,
            accentColor: appAccentColor,
            size: 42
        )
    }

    private func compactMetaTag(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(fieldFill)
            )
    }

    private var panelToneOverlay: Color {
        colorScheme == .dark
            ? darkSurfaceColor.opacity(0.58)
            : settingsStore.accentTheme.accentColor.opacity(0.07)
    }

    private var fieldFill: Color {
        colorScheme == .dark
            ? darkSurfaceColor.opacity(0.92)
            : Color.white.opacity(0.56)
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? darkSurfaceColor.opacity(0.84)
            : Color.white.opacity(0.48)
    }

    private var sectionFill: Color {
        colorScheme == .dark
            ? darkSurfaceColor.opacity(0.80)
            : Color.white.opacity(0.40)
    }

    private func applicationIcon(for entry: String?, size: CGFloat) -> AnyView? {
        guard let entry else {
            return nil
        }

        let trimmedEntry = entry.trimmed
        guard !trimmedEntry.isEmpty else {
            return nil
        }

        let appURL: URL?
        if trimmedEntry.hasPrefix("/") || trimmedEntry.hasPrefix("~") {
            let candidate = URL(fileURLWithPath: trimmedEntry.expandedPath)
            appURL = FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
        } else if trimmedEntry.contains(".") {
            appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmedEntry)
        } else {
            let searchNames = trimmedEntry.hasSuffix(".app") ? [trimmedEntry] : [trimmedEntry, "\(trimmedEntry).app"]
            let roots = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities", "~/Applications"]
            appURL = roots.lazy
                .compactMap { root -> URL? in
                    let rootURL = URL(fileURLWithPath: root.expandedPath, isDirectory: true)
                    return searchNames
                        .map { rootURL.appendingPathComponent($0, isDirectory: true) }
                        .first(where: { FileManager.default.fileExists(atPath: $0.path) })
                }
                .first
        }

        guard let appURL else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: size * 2, height: size * 2)

        return AnyView(
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        )
    }
}
