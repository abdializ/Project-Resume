import SwiftUI

enum InAppSettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case capture
    case retention
    case updates
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .capture: return "Capture"
        case .retention: return "Retention"
        case .updates: return "Updates"
        case .about: return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Shortcut and launcher behavior"
        case .appearance: return "Accent and rail color theme"
        case .capture: return "Session creation defaults"
        case .retention: return "Automatic cleanup for captured sessions"
        case .updates: return "Beta update controls"
        case .about: return "What this utility is optimized for"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintpalette"
        case .capture: return "clock.arrow.circlepath"
        case .retention: return "calendar.badge.clock"
        case .updates: return "arrow.down.circle"
        case .about: return "info.circle"
        }
    }
}

struct EmbeddedSettingsDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let selectedSection: InAppSettingsSection
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var sparkleUpdateService: SparkleUpdateService
    @Environment(\.openWindow) private var openWindow

    private var darkCanvasColor: Color {
        settingsStore.accentTheme.darkModeCanvasColor
    }

    private var darkSurfaceColor: Color {
        settingsStore.accentTheme.darkModeSurfaceColor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedSection.title)
                        .font(.system(size: 30, weight: .semibold))

                    Text(selectedSection.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                sectionContent
            }
            .padding(.top, 72)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(detailCanvasBackground)
        .tint(settingsStore.accentTheme.accentColor)
        .onAppear {
            if sparkleUpdateService.isRunningBetaBuild {
                sparkleUpdateService.configure(feedDirectoryPath: settingsStore.betaUpdateDirectoryPath)
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .general:
            settingsCard(title: "Quick Access", subtitle: "Global launcher behavior") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shortcut")
                        .font(.subheadline.weight(.medium))

                    ShortcutRecorderView(shortcut: $settingsStore.quickAccessShortcut)
                        .frame(width: 220, height: 30)

                    Text("Use Command or Control with another key. Option-only shortcuts like Option-R are not reliable global shortcuts on macOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("Close quick-access panel after launching a project", isOn: $settingsStore.closeQuickAccessAfterLaunch)
            }

        case .appearance:
            settingsCard(title: "Appearance", subtitle: "Choose an accent color theme for the app") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Accent Theme")
                        .font(.subheadline.weight(.medium))

                    AccentThemePicker(selectedTheme: $settingsStore.accentTheme)

                    Text("This updates the app’s accent color, the left rail background tint, and the notes rail tint.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case .capture:
            settingsCard(title: "Project Capture", subtitle: "How generated sessions behave") {
                Toggle("Show confirmation alert after Capture Session", isOn: $settingsStore.showSessionCaptureAlert)
            }

        case .retention:
            settingsCard(title: "Session Retention", subtitle: "Automatically remove generated session snapshots") {
                Toggle("Auto-delete captured sessions", isOn: $settingsStore.automaticallyDeleteCapturedSessions)

                if settingsStore.automaticallyDeleteCapturedSessions {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Delete after")
                            .font(.subheadline.weight(.medium))

                        Stepper(value: $settingsStore.capturedSessionRetentionDays, in: 1...30) {
                            Text("\(settingsStore.capturedSessionRetentionDays) day\(settingsStore.capturedSessionRetentionDays == 1 ? "" : "s")")
                        }
                    }
                }

                Text("Only session-generated projects are affected. Manually created projects stay until you delete them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .updates:
            if sparkleUpdateService.isRunningBetaBuild {
                settingsCard(title: "Beta Updates", subtitle: "Point the beta app at the current dev build output") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Version")
                            .font(.subheadline.weight(.medium))
                        valueBadge(sparkleUpdateService.currentVersionDescription)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dev Build Output Folder")
                            .font(.subheadline.weight(.medium))

                        HStack {
                            TextField("Folder path", text: $settingsStore.betaUpdateDirectoryPath)

                            Button("Choose") {
                                if let path = OpenPanelService.chooseUpdateFolder(initialPath: settingsStore.betaUpdateDirectoryPath) {
                                    settingsStore.betaUpdateDirectoryPath = path
                                    sparkleUpdateService.configure(feedDirectoryPath: path)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    statusBlock(title: "Status", value: sparkleUpdateService.statusMessage)
                    statusBlock(title: "Server", value: sparkleUpdateService.lastServerEvent, secondary: true)

                    HStack {
                        Button("Check for Updates") {
                            sparkleUpdateService.checkForUpdates(feedDirectoryPath: settingsStore.betaUpdateDirectoryPath)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Test Update Feed") {
                            sparkleUpdateService.configure(feedDirectoryPath: settingsStore.betaUpdateDirectoryPath)
                            sparkleUpdateService.testFeedConnection()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                settingsCard(title: "Updates", subtitle: "Distribution mode") {
                    Text("Automatic update controls are only available in the beta build.")
                        .foregroundStyle(.secondary)
                }
            }

        case .about:
            VStack(alignment: .leading, spacing: 22) {
                settingsCard(title: "Guide", subtitle: "Simple walkthrough and shortcut reference") {
                    Text("Open a lightweight help window with shortcuts first, then the basic workflow.")
                        .foregroundStyle(.secondary)

                    Button("Open Guide") {
                        openWindow(id: "guide")
                    }
                    .buttonStyle(.borderedProminent)
                }

                settingsCard(title: "About", subtitle: "What this utility is optimized for") {
                    Text("Project Resume is designed to stay fast and lightweight while reopening the exact references you need for work: folders, apps, links, commands, and short notes.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(settingsSurfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 1)
        )
    }

    private func valueBadge(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04))
            )
    }

    private func statusBlock(title: String, value: String, secondary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))

            Text(value)
                .font(.caption)
                .foregroundStyle(secondary ? .tertiary : .secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035))
                )
        }
    }

    private var detailCanvasBackground: Color {
        colorScheme == .dark ? darkCanvasColor : Color.white
    }

    private var settingsSurfaceFill: Color {
        colorScheme == .dark
            ? darkSurfaceColor.opacity(0.84)
            : Color.white.opacity(0.80)
    }
}
