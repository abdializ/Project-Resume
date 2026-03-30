import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var sparkleUpdateService: SparkleUpdateService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))

                    Text("Control the quick-access shortcut, session capture behavior, and beta update path.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                settingsCard(title: "Guide", subtitle: "Simple walkthrough and shortcut reference") {
                    Text("Open a lightweight help window with shortcuts first, then the basic workflow.")
                        .foregroundStyle(.secondary)

                    Button("Open Guide") {
                        openWindow(id: "guide")
                    }
                    .buttonStyle(.borderedProminent)
                }

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

                settingsCard(title: "Quick Access", subtitle: "Global launcher behavior") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shortcut")
                            .font(.subheadline.weight(.medium))

                        ShortcutRecorderView(shortcut: $settingsStore.quickAccessShortcut)
                            .frame(width: 220, height: 30)

                        Text("Use Command or Control with another key. Option-only shortcuts like Option-R are not reliable global shortcuts on macOS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Quick project launch: ^⌥1 through ^⌥4 open the first four projects from your Favorites/Recent order without opening any window.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Close quick-access panel after launching a project", isOn: $settingsStore.closeQuickAccessAfterLaunch)
                }

                settingsCard(title: "Project Capture", subtitle: "How generated sessions behave") {
                    Toggle("Show confirmation alert after Capture Session", isOn: $settingsStore.showSessionCaptureAlert)
                }

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
                }

                settingsCard(title: "About", subtitle: "What this utility is optimized for") {
                    Text("Project Resume is designed to stay fast and lightweight while reopening the exact references you need for work: folders, apps, links, commands, and short notes.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .tint(settingsStore.accentTheme.accentColor)
        .frame(width: 600, height: 560)
        .onAppear {
            if sparkleUpdateService.isRunningBetaBuild {
                sparkleUpdateService.configure(feedDirectoryPath: settingsStore.betaUpdateDirectoryPath)
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
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func valueBadge(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(nsColor: .windowBackgroundColor))
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
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
        }
    }
}
