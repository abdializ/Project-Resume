import SwiftUI

public struct ProjectResumeScenes: Scene {
    @StateObject private var store = ProjectStore()
    @StateObject private var sessionTracker = SessionTracker()
    @StateObject private var settingsStore = AppSettingsStore()
    @StateObject private var sparkleUpdateService = SparkleUpdateService()
    private let launcher = ProjectLauncher()
    private let appController = AppController()

    public init() {}

    public var body: some Scene {
        WindowGroup("Projects", id: "main") {
            ProjectListView(
                store: store,
                launcher: launcher,
                sessionTracker: sessionTracker,
                settingsStore: settingsStore,
                sparkleUpdateService: sparkleUpdateService
            )
                .frame(minWidth: 880, minHeight: 460)
                .task {
                    appController.configureIfNeeded(
                        store: store,
                        launcher: launcher,
                        settingsStore: settingsStore,
                        sessionTracker: sessionTracker
                    )
                    sparkleUpdateService.configure(feedDirectoryPath: settingsStore.betaUpdateDirectoryPath)
                }
                .onOpenURL { url in
                    appController.handleDeepLink(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 780)

        Window("Guide", id: "guide") {
            GuideView()
        }
        .defaultSize(width: 760, height: 600)
        .commands {
            CommandMenu("Project Resume") {
                if let lastProject = store.lastLaunchedProject {
                    Button("Resume Last Project") {
                        Task {
                            _ = await launcher.launch(lastProject)
                            store.recordLaunch(of: lastProject)
                        }
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                    Menu("Resume Last Project As") {
                        ForEach(ProjectLaunchMode.allCases) { mode in
                            Button(mode.title) {
                                Task {
                                    _ = await launcher.launch(lastProject, mode: mode)
                                    store.recordLaunch(of: lastProject)
                                }
                            }
                        }
                    }
                }

                Button("Update Project from Current Session") {
                    NotificationCenter.default.post(name: .projectResumeRefreshProjectRequested, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Button("Toggle Quick Access (\(settingsStore.quickAccessShortcut.displayString))") {
                    appController.toggleQuickAccess()
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appController.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .appSettings) {
                Button("Check for Updates...") {
                    sparkleUpdateService.checkForUpdates(feedDirectoryPath: settingsStore.betaUpdateDirectoryPath)
                }
            }

            CommandGroup(after: .help) {
                Button("Project Resume Guide") {
                    NotificationCenter.default.post(name: .projectResumeShowGuideRequested, object: nil)
                }
            }
        }

        MenuBarExtra {
            ScrollView {
                MenuBarProjectsView(
                    store: store,
                    launcher: launcher,
                    appController: appController,
                    settingsStore: settingsStore,
                    sparkleUpdateService: sparkleUpdateService
                )
                .frame(minWidth: 360, idealWidth: 388, maxWidth: 420, alignment: .topLeading)
            }
            .frame(minWidth: 360, idealWidth: 388, maxWidth: 420,
                   minHeight: 420, idealHeight: 500, maxHeight: 620,
                   alignment: .topLeading)
            .task {
                appController.configureIfNeeded(
                    store: store,
                    launcher: launcher,
                    settingsStore: settingsStore,
                    sessionTracker: sessionTracker
                )
                sparkleUpdateService.configure(feedDirectoryPath: settingsStore.betaUpdateDirectoryPath)
            }
        } label: {
            MenuBarStatusIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarStatusIcon: View {
    private static let bundledIcon: NSImage? = {
        guard let iconURL = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: iconURL) else {
            return nil
        }

        image.isTemplate = true
        image.size = NSSize(width: 22, height: 16)
        return image
    }()

    var body: some View {
        Group {
            if let bundledIcon = Self.bundledIcon {
                Image(nsImage: bundledIcon)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.18)
            } else {
                HStack(spacing: 3) {
                    Text("P")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(-0.2)

                    RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                        .frame(width: 1.6, height: 10)

                    Text("R")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(-0.2)
                }
                .foregroundStyle(.primary)
            }
        }
        .frame(width: 22, height: 16, alignment: .center)
        .accessibilityLabel("Project Resume")
    }
}
