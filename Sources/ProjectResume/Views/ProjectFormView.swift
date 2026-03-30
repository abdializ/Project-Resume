import SwiftUI

struct ProjectFormView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProjectDraft
    @State private var isShowingApplicationPicker = false
    @State private var availableApplications: [DiscoveredApplication] = []
    @State private var isShowingFolderOpenerPicker = false
    @State private var availableIDEApplications: [DiscoveredApplication] = []

    @ObservedObject var settingsStore: AppSettingsStore
    let isVSCodeInstalled: Bool
    let onSave: (ProjectDraft) -> Void

    init(
        initialProject: Project?,
        initialDraft: ProjectDraft? = nil,
        settingsStore: AppSettingsStore,
        isVSCodeInstalled: Bool,
        onSave: @escaping (ProjectDraft) -> Void
    ) {
        _draft = State(initialValue: initialDraft ?? ProjectDraft(project: initialProject))
        self.settingsStore = settingsStore
        self.isVSCodeInstalled = isVSCodeInstalled
        self.onSave = onSave
    }

    private var title: String {
        draft.sourceProjectID == nil ? "New Project" : "Edit Project"
    }

    private var subtitle: String {
        draft.sourceProjectID == nil
            ? "Save what you need to reopen this project quickly."
            : "Update what should reopen with this project."
    }

    private var appAccentColor: Color {
        settingsStore.accentTheme.resolvedAccentColor(for: colorScheme)
    }

    private var darkCanvasColor: Color {
        settingsStore.accentTheme.darkModeCanvasColor
    }

    private var darkSurfaceColor: Color {
        settingsStore.accentTheme.darkModeSurfaceColor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))

                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 4)

                    formSection(
                        title: "Project Basics",
                        subtitle: "A clear name and a short reminder are enough.",
                        systemImage: "square.text.square"
                    ) {
                        labeledField(
                            title: "Project name",
                            placeholder: "Client dashboard, iOS redesign, tax prep...",
                            text: $draft.name
                        )
                        labeledField(
                            title: "Short description",
                            placeholder: "What is this project for?",
                            text: $draft.projectDescription
                        )

                        if let sessionCapturedAt = draft.sessionCapturedAt {
                            subtleCallout("Generated from your current session on \(sessionCapturedAt.formatted(date: .abbreviated, time: .shortened)).")
                        }
                    }

                    formSection(
                        title: "Workspace Folder",
                        subtitle: "Choose a folder only if this project lives in one place.",
                        systemImage: "folder"
                    ) {
                        labeledField(
                            title: "Folder path",
                            placeholder: "Choose the folder you want to reopen later",
                            text: $draft.folderPath
                        )

                        HStack {
                            Button("Choose Folder") {
                                if let path = OpenPanelService.chooseFolder(initialPath: draft.folderPath) {
                                    draft.folderPath = path
                                }
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Open this folder with")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            folderOpenerChooser

                            HStack(spacing: 8) {
                                Button("Choose Another App") {
                                    availableIDEApplications = ApplicationCatalog.discoverInstalledApplications()
                                    isShowingFolderOpenerPicker = true
                                }
                                .buttonStyle(.bordered)

                                Button("Use Finder") {
                                    draft.folderLaunchMode = .finder
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        if availableIDEApplications.isEmpty {
                            subtleCallout("No editors were detected automatically. You can still choose any app or just use Finder.")
                        }
                    }

                    EditableStringListSection(
                        title: "Apps to Reopen",
                        subtitle: "Pick the apps you normally use for this project.",
                        prompt: "App name or path",
                        emptyMessage: "Choose apps like Xcode, Safari, Slack, or Terminal so they open with the project.",
                        addLabel: "Add Manually",
                        browseLabel: "Choose App",
                        rowStyle: .application,
                        accentColor: appAccentColor,
                        darkSurfaceColor: darkSurfaceColor,
                        items: $draft.apps,
                        onBrowse: OpenPanelService.chooseApplication,
                        onBrowseAction: {
                            availableApplications = ApplicationCatalog.discoverInstalledApplications()
                            isShowingApplicationPicker = true
                        }
                    )

                    EditableStringListSection(
                        title: "Web Links",
                        subtitle: "Save websites you want reopened, like docs, dashboards, or tickets.",
                        prompt: "https://example.com",
                        emptyMessage: "Add the websites you always revisit for this project.",
                        addLabel: "Add Link",
                        browseLabel: nil,
                        rowStyle: .plain,
                        accentColor: appAccentColor,
                        darkSurfaceColor: darkSurfaceColor,
                        items: $draft.urls
                    )

                    EditableStringListSection(
                        title: "Terminal Commands",
                        subtitle: "Optional. These run in Terminal when you launch the project.",
                        prompt: "npm run dev",
                        emptyMessage: "Examples: npm run dev, pnpm test, swift build, git status",
                        addLabel: "Add Command",
                        browseLabel: nil,
                        rowStyle: .plain,
                        accentColor: appAccentColor,
                        darkSurfaceColor: darkSurfaceColor,
                        items: $draft.terminalCommands
                    )

                    formSection(
                        title: "Last Note",
                        subtitle: "Leave a quick note for future-you.",
                        systemImage: "note.text"
                    ) {
                        textEditorWithPlaceholder(
                            text: $draft.lastNote,
                            placeholder: "What should you remember next time? Example: finish the settings screen and review staging deploy."
                        )
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(colorScheme == .dark ? darkCanvasColor : Color(nsColor: .windowBackgroundColor))
            .tint(appAccentColor)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .automatic)
            .onAppear {
                if availableApplications.isEmpty {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let apps = ApplicationCatalog.discoverInstalledApplications()
                        let ides = ApplicationCatalog.discoverIDEApplications()
                        DispatchQueue.main.async {
                            self.availableApplications = apps
                            self.availableIDEApplications = ides
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
        .sheet(isPresented: $isShowingApplicationPicker) {
            ApplicationPickerSheet(applications: availableApplications) { app in
                if !draft.apps.contains(app.path) {
                    draft.apps.append(app.path)
                }
            }
        }
        .sheet(isPresented: $isShowingFolderOpenerPicker) {
            ApplicationPickerSheet(applications: availableIDEApplications) { app in
                draft.folderLaunchMode = .application(app.path)
            }
        }
        .frame(
            minWidth: 700,
            idealWidth: 760,
            maxWidth: 820,
            minHeight: 540,
            idealHeight: 620,
            maxHeight: 700
        )
    }

    private func labeledField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? darkSurfaceColor : Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
        }
    }

    private func formSection<Content: View>(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                content()
            }
            .padding(.bottom, 6)
        }
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func subtleCallout(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? darkSurfaceColor.opacity(0.72) : Color.primary.opacity(0.04))
            )
    }

    private func textEditorWithPlaceholder(text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .font(.body)
                .padding(8)
                .frame(minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? darkSurfaceColor : Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )

            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private var folderOpenerChooser: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                folderOpenerChip(
                    title: "Finder",
                    subtitle: "Default Mac folder view",
                    icon: Image(systemName: "folder"),
                    isSelected: draft.folderLaunchMode.isFinder
                ) {
                    draft.folderLaunchMode = .finder
                }

                ForEach(availableIDEChoices, id: \.id) { app in
                    folderOpenerChip(
                        title: app.title,
                        subtitle: app.isRunning ? "Running now" : "Open folder here",
                        icon: Image(nsImage: ApplicationCatalog.icon(for: app.path, size: 28)),
                        isSelected: isFolderOpenerSelected(app),
                    ) {
                        draft.folderLaunchMode = .application(app.path)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var availableIDEChoices: [DiscoveredApplication] {
        let ideas = availableIDEApplications
        if ideas.isEmpty {
            return []
        }
        return Array(ideas.prefix(8))
    }

    private func isFolderOpenerSelected(_ app: DiscoveredApplication) -> Bool {
        guard draft.folderLaunchMode.kind == .application,
              let selectedEntry = draft.folderLaunchMode.applicationEntry else {
            return false
        }

        if selectedEntry == app.path {
            return true
        }

        if let bundleIdentifier = app.bundleIdentifier {
            return selectedEntry == bundleIdentifier
        }

        return false
    }

    private func folderOpenerChip(
        title: String,
        subtitle: String,
        icon: Image,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                icon
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 138, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                            ? appAccentColor.opacity(colorScheme == .dark ? 0.22 : 0.16)
                            : (colorScheme == .dark ? darkSurfaceColor : Color(nsColor: .textBackgroundColor))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? appAccentColor.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
