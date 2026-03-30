import AppKit
import SwiftUI

struct MenuBarProjectsView: View {
    @ObservedObject var store: ProjectStore
    let launcher: ProjectLauncher
    let appController: AppController
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var sparkleUpdateService: SparkleUpdateService

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    private var darkCanvasColor: Color {
        settingsStore.accentTheme.darkModeCanvasColor
    }

    private var darkSurfaceColor: Color {
        settingsStore.accentTheme.darkModeSurfaceColor
    }

    private var favoriteProjects: [Project] {
        Array(store.favoriteProjects.prefix(2))
    }

    private var recentProjects: [Project] {
        Array(store.recentProjects.filter { !$0.isFavorite }.prefix(2))
    }

    private var fallbackProjects: [Project] {
        let featuredIDs = Set(favoriteProjects.map(\.id) + recentProjects.map(\.id))
        return Array(store.projects.filter { !featuredIDs.contains($0.id) }.prefix(4))
    }

    private var featuredProjects: [Project] {
        if !favoriteProjects.isEmpty || !recentProjects.isEmpty {
            return favoriteProjects + recentProjects
        }

        return fallbackProjects
    }

    private var launchShortcutProjects: [Project] {
        store.launchShortcutProjects
    }

    private var totalProjectCount: Int {
        store.projects.count
    }

    private var compactStatsText: String {
        let favorites = store.projects.filter(\.isFavorite).count
        if favorites > 0 {
            return "\(totalProjectCount) projects • \(favorites) favorites"
        }
        return "\(totalProjectCount) saved projects"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            popupHeader

            if store.projects.isEmpty {
                emptyState
            } else {
                projectsPanel
            }

            actionPanel
            utilityRow
        }
        .padding(14)
        .tint(settingsStore.accentTheme.resolvedAccentColor(for: colorScheme))
        .background(popupBackground)
    }

    private var popupHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(headerGlyphBackground)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "arrow.trianglehead.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(headerGlyphColor)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Project Resume")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(store.projects.isEmpty ? "Open a workspace fast" : compactStatsText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let lastProject = store.lastLaunchedProject {
                    Button {
                        launch(lastProject)
                    } label: {
                        Text("Resume Last")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No projects yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Create a project or capture what you’re working on now.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                actionCapsule("Open App", systemImage: "rectangle.stack") {
                    openWindow(id: "main")
                }

                actionCapsule("Capture", systemImage: "clock.badge.plus") {
                    openWindow(id: "main")
                    NotificationCenter.default.post(name: .projectResumeCaptureSessionRequested, object: nil)
                }
            }
        }
        .padding(14)
        .background(panelBackground)
    }

    private var projectsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Projects")

            VStack(spacing: 6) {
                ForEach(featuredProjects) { project in
                    Button {
                        launch(project)
                    } label: {
                        projectRow(project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 10) {
            projectIcon(for: project)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if project.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(projectStarColor)
                    }
                }

                Text(projectRowSubtitle(for: project))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            selectiveLaunchMenu(for: project)

            if let shortcutSlot = shortcutSlot(for: project) {
                Text("^⌥\(shortcutSlot)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(projectRowBackground)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Actions")

            HStack(spacing: 8) {
                actionCapsule("Quick Access", systemImage: "command") {
                    appController.toggleQuickAccess()
                }

                actionCapsule("Capture", systemImage: "clock.badge.plus") {
                    openWindow(id: "main")
                    NotificationCenter.default.post(name: .projectResumeCaptureSessionRequested, object: nil)
                }
            }

            HStack(spacing: 8) {
                actionCapsule("Projects", systemImage: "rectangle.stack") {
                    openWindow(id: "main")
                }

                if sparkleUpdateService.isRunningBetaBuild {
                    actionCapsule("Updates", systemImage: "arrow.down.circle") {
                        appController.presentMainWindow()
                        sparkleUpdateService.checkForUpdates(feedDirectoryPath: settingsStore.betaUpdateDirectoryPath)
                    }
                }
            }
        }
    }

    private var utilityRow: some View {
        HStack(spacing: 8) {
            utilityButton("Settings", systemImage: "gearshape") {
                appController.showSettings()
            }

            Spacer()

            utilityButton("Quit", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(.top, 2)
    }

    private func actionCapsule(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(actionCapsuleBackground)
        }
        .buttonStyle(.plain)
    }

    private func utilityButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.4)
    }

    private func projectIcon(for project: Project) -> some View {
        ProjectBadgeView(
            project: project,
            accentColor: settingsStore.accentTheme.resolvedAccentColor(for: colorScheme),
            size: 32
        )
    }

    private func projectRowSubtitle(for project: Project) -> String {
        let apps = project.apps.normalizedEntries().count
        let links = project.urls.normalizedEntries().count

        if let lastLaunchedAt = project.lastLaunchedAt {
            return "\(apps) apps • \(links) links • \(relativeDate(lastLaunchedAt))"
        }

        return "\(apps) apps • \(links) links"
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func launch(_ project: Project, mode: ProjectLaunchMode = .everything) {
        Task {
            _ = await launcher.launch(project, mode: mode)
            store.recordLaunch(of: project)
        }
    }

    private func shortcutSlot(for project: Project) -> Int? {
        guard let index = launchShortcutProjects.firstIndex(where: { $0.id == project.id }) else {
            return nil
        }

        return index + 1
    }

    private var popupBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(colorScheme == .dark ? darkCanvasColor.opacity(0.96) : Color.white.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 0.8)
            )
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(sidebarSurfaceTone.opacity(colorScheme == .dark ? 0.96 : 0.84))
    }

    private var projectRowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(sidebarSurfaceTone.opacity(colorScheme == .dark ? 0.92 : 0.72))
    }

    private var actionCapsuleBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(sidebarSurfaceTone.opacity(colorScheme == .dark ? 0.94 : 0.76))
    }

    private var headerGlyphBackground: Color {
        colorScheme == .dark
            ? Color.accentColor.opacity(0.18)
            : Color.accentColor.opacity(0.10)
    }

    private var headerGlyphColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.92)
            : Color.accentColor.opacity(0.95)
    }

    private var projectStarColor: Color {
        Color(red: 0.93, green: 0.74, blue: 0.27)
    }

    private var sidebarSurfaceTone: Color {
        colorScheme == .dark
            ? darkSurfaceColor
            : Color.black.opacity(0.055)
    }
}
