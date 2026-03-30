import AppKit
import SwiftUI

struct ProjectListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var store: ProjectStore
    let launcher: ProjectLauncher
    let sessionTracker: SessionTracker
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var sparkleUpdateService: SparkleUpdateService

    @State private var selection: Project.ID?
    @State private var editorContext: ProjectEditorContext?
    @State private var projectPendingDeletion: Project?
    @State private var userAlert: UserAlert?
    @State private var contentMode: ContentMode = .projects
    @State private var selectedSettingsSection: InAppSettingsSection = .general
    @State private var sidebarWidthOverride: CGFloat?
    @State private var sidebarCollapsed = false
    @State private var dragStartSidebarWidth: CGFloat?
    @State private var showcaseStartedAt = Date()
    @State private var notePanelPresented = false
    @State private var noteDraft = ""
    @State private var noteSaveTask: Task<Void, Never>?
    @State private var sidebarScrollOffset: CGFloat = 0
    @State private var detailScrollOffset: CGFloat = 0
    
    private class HoverStateTracker {
        var lastX: CGFloat = .infinity
    }
    
    @State private var hoverStateTracker = HoverStateTracker()
    @State private var sidebarHoverRevealTask: Task<Void, Never>?
    @State private var sidebarHoverCollapseTask: Task<Void, Never>?
    @State private var sidebarHoverActivated = false
    @State private var captureSheenPosition: CGFloat = -1.3
    @State private var captureSheenTask: Task<Void, Never>?
    @State private var captureButtonHovered = false

    private var appAccentColor: Color {
        settingsStore.accentTheme.resolvedAccentColor(for: colorScheme)
    }

    private var activeStatusColor: Color {
        appAccentColor
    }

    private var windowIsActive: Bool {
        controlActiveState != .inactive
    }

    private var themedDarkSurfaceColor: Color {
        settingsStore.accentTheme.darkModeSurfaceColor
    }

    private var deleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { projectPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    projectPendingDeletion = nil
                }
            }
        )
    }

    private var selectedProject: Project? {
        store.projects.first { $0.id == selection }
    }

    private var totalSavedLinks: Int {
        store.projects.reduce(0) { $0 + $1.urls.count }
    }

    private var totalSavedApps: Int {
        store.projects.reduce(0) { $0 + $1.apps.count }
    }

    private var favoriteProjects: [Project] {
        store.favoriteProjects
    }

    private var recentProjects: [Project] {
        store.recentProjects.filter { !$0.isFavorite }
    }

    private var historyProjects: [Project] {
        let featuredIDs = Set(favoriteProjects.map(\.id) + recentProjects.map(\.id))
        return store.projects.filter { !featuredIDs.contains($0.id) }
    }

    private var sessionUptime: String {
        let elapsed = max(0, Int(sessionTracker.trackedApplications.map(\.accumulatedFocusTime).reduce(0, +)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(max(1, minutes))m"
    }

    private var trackedApps: [TrackedApplicationUsage] {
        Array(sessionTracker.trackedApplications.prefix(6))
    }

    private var showcaseIsActive: Bool {
        Date().timeIntervalSince(showcaseStartedAt) < 40
    }

    private var titlebarBlurActive: Bool {
        // detailScrollOffset starts at ~40-44 due to chromeTopInset.
        // Trigger the blur instantly as soon as they scroll down.
        detailScrollOffset < 38
    }

    var body: some View {
        GeometryReader { proxy in
            let compactLayout = proxy.size.width < 980
            let defaultSidebarWidth = compactLayout ? 240.0 : 280.0
            let minSidebarWidth = compactLayout ? 200.0 : 220.0
            let maxSidebarWidth = max(minSidebarWidth, min(460.0, proxy.size.width - 480.0))
            let resolvedSidebarWidth = min(max(sidebarWidthOverride ?? defaultSidebarWidth, minSidebarWidth), maxSidebarWidth)
            let visibleSidebarWidth = sidebarCollapsed ? 0.0 : resolvedSidebarWidth
            let chromeTopInset = compactLayout ? 40.0 : 44.0
            let contentOuterInset = compactLayout ? 6.0 : 6.0
            let contentVerticalInset = compactLayout ? 6.0 : 6.0
            let rawContentWidth = max(560.0, proxy.size.width - visibleSidebarWidth - 56.0)
            let contentMaxWidth = notePanelPresented
                ? rawContentWidth
                : max(920.0, min(sidebarCollapsed ? 1400.0 : 1220.0, rawContentWidth))

            ZStack {
                sidebarSurfaceBackground
                    .frame(width: visibleSidebarWidth > 0 ? visibleSidebarWidth + 28 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                    .opacity(visibleSidebarWidth > 0 ? 1 : 0)

                HStack(spacing: 0) {
                    sidebar(compactLayout: compactLayout, chromeTopInset: chromeTopInset)
                        .frame(width: resolvedSidebarWidth)
                        .frame(width: visibleSidebarWidth, alignment: .trailing)
                        .clipped()
                        .contentShape(Rectangle())
                        .overlay(alignment: .trailing) {
                            sidebarResizeHandle(maxSidebarWidth: maxSidebarWidth, minSidebarWidth: minSidebarWidth)
                        }

                    ZStack {
                        sidebarSurfaceBackground

                        contentPane(
                            chromeTopInset: chromeTopInset,
                            sidebarCollapsed: sidebarCollapsed,
                            contentMaxWidth: contentMaxWidth
                        )
                            .padding(.top, contentVerticalInset)
                            .padding(.bottom, contentVerticalInset)
                            .padding(.trailing, contentOuterInset)
                            .padding(.leading, sidebarCollapsed ? contentOuterInset : 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .onContinuousHover(coordinateSpace: .local) { phase in
                handleContinuousHover(phase: phase, hoverWidth: resolvedSidebarWidth)
            }
            .onAppear {
                postSidebarChromeLayout(sidebarWidth: visibleSidebarWidth, sidebarCollapsed: sidebarCollapsed)
            }
            .onChange(of: compactLayout) { isCompact in
                let updatedDefault = isCompact ? 240.0 : 280.0
                if sidebarWidthOverride == nil {
                    sidebarWidthOverride = updatedDefault
                }
            }
            .onChange(of: visibleSidebarWidth) { updatedWidth in
                postSidebarChromeLayout(sidebarWidth: updatedWidth, sidebarCollapsed: sidebarCollapsed)
            }
            .onChange(of: sidebarCollapsed) { isCollapsed in
                postSidebarChromeLayout(sidebarWidth: visibleSidebarWidth, sidebarCollapsed: isCollapsed)
            }
        }
        .tint(appAccentColor)
        .background(MainWindowConfigurator())
        .sheet(item: $editorContext) { context in
            ProjectFormView(
                initialProject: context.project,
                initialDraft: context.draft,
                settingsStore: settingsStore,
                isVSCodeInstalled: launcher.isVSCodeInstalled
            ) { draft in
                save(draft.buildProject())
            }
        }
        .confirmationDialog(
            projectPendingDeletion.map { "Delete \"\($0.name)\"?" } ?? "Delete Project?",
            isPresented: deleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive) {
                if let projectPendingDeletion {
                    delete(projectPendingDeletion)
                }

                projectPendingDeletion = nil
            }

            Button("Cancel", role: .cancel) {
                projectPendingDeletion = nil
            }
        } message: {
            Text("This removes the saved profile only. It does not delete files or applications.")
        }
        .alert(item: $userAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            showcaseStartedAt = Date()
            syncSelection()
            syncNoteDraft()
            presentStoreErrorIfNeeded()
            if sparkleUpdateService.isRunningBetaBuild {
                sparkleUpdateService.configure(feedDirectoryPath: settingsStore.betaUpdateDirectoryPath)
            }
        }
        .onChange(of: store.projects) { _ in
            syncSelection()
            syncNoteDraft()
        }
        .onChange(of: selection) { _ in
            syncNoteDraft()
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectResumeCaptureSessionRequested)) { _ in
            captureSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectResumeNewProjectRequested)) { _ in
            contentMode = .projects
            editorContext = .create
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectResumeShowSettingsRequested)) { _ in
            selectedSettingsSection = .general
            contentMode = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectResumeShowGuideRequested)) { _ in
            openWindow(id: "guide")
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectResumeRefreshProjectRequested)) { _ in
            refreshSelectedProjectFromSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectResumeOpenProjectRequested)) { notification in
            handleOpenProjectRequest(notification)
        }
    }

    private func sidebar(compactLayout: Bool, chromeTopInset: CGFloat) -> some View {
        ZStack {
            sidebarSurfaceBackground
            Group {
                switch contentMode {
                case .projects:
                    projectsRail(compactLayout: compactLayout, chromeTopInset: chromeTopInset)
                case .settings:
                    settingsRail(chromeTopInset: chromeTopInset)
                }
            }
        }
    }

    private var sidebarSurfaceBackground: some View {
        ZStack {
            GlassSidebarBackground(material: .sidebar)

            Rectangle()
                .fill(sidebarToneOverlay)
        }
    }

    private func projectsRail(compactLayout: Bool, chromeTopInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: – Compact header
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text("Project Resume")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(sidebarPrimaryText)

                    Spacer()

                    sidebarIconButton(icon: "plus", tooltip: "New Project") {
                        editorContext = .create
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        if let lastProject = store.lastLaunchedProject {
                            launch(lastProject)
                        }
                    } label: {
                        Label("Resume Last", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(store.lastLaunchedProject == nil ? sidebarTertiaryText : sidebarSecondaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.lastLaunchedProject == nil)

                    Text("•")
                        .foregroundStyle(sidebarTertiaryText)

                    Button {
                        captureSession()
                    } label: {
                        Label("Capture", systemImage: "clock.badge.plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(sidebarSecondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, chromeTopInset)
            .padding(.bottom, 14)

            // MARK: – Project list
            if store.projects.isEmpty {
                EmptyStateView(
                    title: "No Projects Yet",
                    systemImage: "folder.badge.plus",
                    message: "Create a project or capture your current session."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        scrollOffsetProbe(in: "sidebarScroll")

                        if !favoriteProjects.isEmpty {
                            railProjectSection(title: "Favorites", projects: favoriteProjects)
                        }

                        if !recentProjects.isEmpty {
                            railProjectSection(title: "Recent", projects: recentProjects)
                        }

                        if !historyProjects.isEmpty {
                            railProjectSection(title: favoriteProjects.isEmpty && recentProjects.isEmpty ? "All" : "Library", projects: historyProjects)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .coordinateSpace(name: "sidebarScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    sidebarScrollOffset = offset
                }
            }

            Spacer(minLength: 0)

            Button {
                selectedSettingsSection = .general
                contentMode = .settings
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(sidebarSecondaryText)

                    Text("Settings")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(sidebarSecondaryText)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func settingsRail(chromeTopInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                Button {
                    contentMode = .projects
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.left")
                        Text("Back to app")
                    }
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(InAppSettingsSection.allCases) { section in
                        Button {
                            selectedSettingsSection = section
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: section.systemImage)
                                    .frame(width: 18)

                                Text(section.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.headline.weight(.medium))
                            .foregroundStyle(sidebarPrimaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(selectedSettingsSection == section ? Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, chromeTopInset)

            Spacer()
        }
    }

    // statsStrip replaced by inline sidebarStatChip in the header

    @ViewBuilder
    private func contentPane(chromeTopInset: CGFloat, sidebarCollapsed: Bool, contentMaxWidth: CGFloat) -> some View {
        Group {
            switch contentMode {
            case .projects:
                detailCanvas(
                    chromeTopInset: chromeTopInset,
                    sidebarCollapsed: sidebarCollapsed,
                    contentMaxWidth: contentMaxWidth
                )
            case .settings:
                EmbeddedSettingsDetailView(
                    selectedSection: selectedSettingsSection,
                    settingsStore: settingsStore,
                    sparkleUpdateService: sparkleUpdateService
                )
            }
        }
        .background(detailCanvasBackground)
        .clipShape(contentPaneShape(sidebarCollapsed: sidebarCollapsed))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08),
            radius: colorScheme == .dark ? 16 : 20,
            x: 0,
            y: 6
        )
        .overlay(alignment: .leading) {
            if !sidebarCollapsed {
                contentPaneSeam
            }
        }
    }

    private func detailCanvas(chromeTopInset: CGFloat, sidebarCollapsed: Bool, contentMaxWidth: CGFloat) -> some View {
        return GeometryReader { proxy in
            let canvasWidth = max(0, proxy.size.width)
            let minimumPrimaryWidth = min(420, max(320, canvasWidth * 0.55))
            let paneOverlap = notePanelPresented ? 8.0 : 0.0
            let maximumSidebarWidth = max(220, canvasWidth - minimumPrimaryWidth - 1)
            let preferredSidebarWidth = max(240, canvasWidth * (canvasWidth < 980 ? 0.32 : 0.26))
            let noteSidebarWidth = notePanelPresented
                ? min(preferredSidebarWidth, maximumSidebarWidth)
                : 0
            let primaryColumnWidth = notePanelPresented
                ? max(minimumPrimaryWidth, canvasWidth - noteSidebarWidth + paneOverlap - 1)
                : canvasWidth

            HStack(spacing: notePanelPresented ? -paneOverlap : 0) {
                ZStack(alignment: .topLeading) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            scrollOffsetProbe(in: "detailScroll")
                            selectedProjectPanel(compactActions: primaryColumnWidth < 860)
                            liveSessionPanel
                        }
                        .padding(.top, chromeTopInset)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .coordinateSpace(name: "detailScroll")
                    .onPreferenceChange(ScrollOffsetKey.self) { offset in
                        detailScrollOffset = offset
                    }

                    if titlebarBlurActive {
                        detailTopGlassStrip
                            .frame(height: 68)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }

                    titlebarSidebarToggle(isCollapsed: sidebarCollapsed)
                        .padding(.top, 14)
                        .padding(.leading, 18)
                }
                .frame(width: primaryColumnWidth, alignment: .topLeading)
                .background(detailCanvasFill)
                .clipShape(primaryDetailPaneShape(notesPresented: notePanelPresented))
                .zIndex(1)
                .clipped()

                if notePanelPresented, let project = selectedProject {
                    ZStack(alignment: .topLeading) {
                        notesSidebarBackground

                        projectNotesPanel(project)
                            .padding(.top, chromeTopInset)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                    }
                    .clipShape(notesRailShape)
                    .frame(width: noteSidebarWidth, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
            .animation(.easeInOut(duration: 0.22), value: notePanelPresented)
        }
    }

    private var contentPaneSeam: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 1)
            .allowsHitTesting(false)
    }

    private func contentPaneShape(sidebarCollapsed: Bool) -> some Shape {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: sidebarCollapsed ? 14 : 12,
                bottomLeading: sidebarCollapsed ? 14 : 12,
                bottomTrailing: 14,
                topTrailing: 14
            ),
            style: .continuous
        )
    }

    private func primaryDetailPaneShape(notesPresented: Bool) -> some Shape {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 0,
                bottomLeading: 0,
                bottomTrailing: 14,
                topTrailing: 14
            ),
            style: .continuous
        )
    }

    private var notesRailShape: some Shape {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 0,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: 0
            ),
            style: .continuous
        )
    }

    private func sidebarResizeHandle(maxSidebarWidth: CGFloat, minSidebarWidth: CGFloat) -> some View {
        ZStack {
            ResizeCursorRegion()
            Rectangle()
                .fill(Color.clear)
        }
            .frame(width: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if dragStartSidebarWidth == nil {
                            dragStartSidebarWidth = sidebarWidthOverride ?? (sidebarCollapsed ? 0 : minSidebarWidth)
                        }

                        let delta = value.location.x - value.startLocation.x
                        let start = dragStartSidebarWidth ?? minSidebarWidth
                        let nextWidth = min(max(start + delta, minSidebarWidth), maxSidebarWidth)
                        sidebarWidthOverride = nextWidth
                    }
                    .onEnded { value in
                        let delta = value.location.x - value.startLocation.x
                        let finalWidth = (dragStartSidebarWidth ?? minSidebarWidth) + delta
                        dragStartSidebarWidth = nil

                        if finalWidth < minSidebarWidth * 0.82 {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                sidebarCollapsed = true
                            }
                            postSidebarChromeLayout(sidebarWidth: 0, sidebarCollapsed: true)
                        } else {
                            sidebarWidthOverride = min(max(finalWidth, minSidebarWidth), maxSidebarWidth)
                            postSidebarChromeLayout(
                                sidebarWidth: sidebarWidthOverride ?? minSidebarWidth,
                                sidebarCollapsed: false
                            )
                        }
                    }
            )
    }

    private func titlebarSidebarToggle(isCollapsed: Bool) -> some View {
        Button {
            sidebarHoverActivated = false
            cancelSidebarHoverReveal()
            cancelSidebarHoverCollapse()
            withAnimation(.easeInOut(duration: 0.18)) {
                sidebarCollapsed.toggle()
                if !sidebarCollapsed && sidebarWidthOverride == nil {
                    sidebarWidthOverride = 300
                }
            }
            postSidebarChromeLayout(
                sidebarWidth: sidebarCollapsed ? 0 : (sidebarWidthOverride ?? 300),
                sidebarCollapsed: sidebarCollapsed
            )
        } label: {
            Image(systemName: isCollapsed ? "sidebar.squares.left" : "sidebar.squares.leading")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary.opacity(colorScheme == .dark ? 0.65 : 0.50))
                .frame(width: 26, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentTransition(.interpolate)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("s", modifiers: [.command])
    }

    private func postSidebarChromeLayout(sidebarWidth: CGFloat, sidebarCollapsed: Bool) {
        NotificationCenter.default.post(
            name: .projectResumeSidebarChromeLayoutChanged,
            object: nil,
            userInfo: [
                "sidebarWidth": sidebarWidth,
                "sidebarCollapsed": sidebarCollapsed
            ]
        )
    }

    private func handleContinuousHover(phase: HoverPhase, hoverWidth: CGFloat) {
        let activeZoneWidth = sidebarCollapsed ? 16.0 : hoverWidth
        
        switch phase {
        case .active(let location):
            hoverStateTracker.lastX = location.x
            
            if location.x <= activeZoneWidth {
                if sidebarCollapsed {
                    scheduleSidebarHoverReveal(sidebarWidth: hoverWidth)
                } else {
                    cancelSidebarHoverCollapse()
                }
            } else {
                if !sidebarCollapsed && sidebarHoverActivated {
                    scheduleSidebarHoverCollapse()
                } else {
                    cancelSidebarHoverReveal()
                }
            }
        case .ended:
            // If the user slung their mouse off the left edge (past the app window), 
            // keep it open! The intent is still targeting the left edge.
            if hoverStateTracker.lastX <= activeZoneWidth {
                // Do nothing, let the 50ms open timer fire or let the 
                // sidebar stay pinned open.
            } else {
                if !sidebarCollapsed && sidebarHoverActivated {
                    scheduleSidebarHoverCollapse()
                } else {
                    cancelSidebarHoverReveal()
                }
            }
            
            // Reset state
            hoverStateTracker.lastX = .infinity
        }
    }

    private func scheduleSidebarHoverReveal(sidebarWidth: CGFloat) {
        guard sidebarCollapsed else { return }

        cancelSidebarHoverReveal()
        sidebarHoverRevealTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000) // 20ms trigger, lightning fast
            guard !Task.isCancelled, sidebarCollapsed else { return }

            sidebarHoverActivated = true
            withAnimation(.easeInOut(duration: 0.18)) {
                sidebarCollapsed = false
                if sidebarWidthOverride == nil {
                    sidebarWidthOverride = sidebarWidth
                }
            }
            postSidebarChromeLayout(
                sidebarWidth: sidebarWidthOverride ?? sidebarWidth,
                sidebarCollapsed: false
            )
        }
    }

    private func scheduleSidebarHoverCollapse() {
        guard sidebarHoverActivated else { return }

        cancelSidebarHoverCollapse()
        sidebarHoverCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms fast dismiss
            guard !Task.isCancelled, !sidebarCollapsed else { return }

            sidebarHoverActivated = false
            withAnimation(.easeInOut(duration: 0.18)) {
                sidebarCollapsed = true
            }
            postSidebarChromeLayout(sidebarWidth: 0, sidebarCollapsed: true)
        }
    }

    private func cancelSidebarHoverReveal() {
        sidebarHoverRevealTask?.cancel()
        sidebarHoverRevealTask = nil
    }

    private func cancelSidebarHoverCollapse() {
        sidebarHoverCollapseTask?.cancel()
        sidebarHoverCollapseTask = nil
    }

    private func selectedProjectPanel(compactActions: Bool) -> some View {
        Group {
            if let project = selectedProject {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 20) {
                        projectHero(project, compactActions: compactActions)
                        projectMetricStrip(project)
                    }

                    projectOverviewSection(project)

                    launchSetupSection(project)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            } else {
                EmptyStateView(
                    title: "Select a Project",
                    systemImage: "rectangle.stack.person.crop",
                    message: "Choose a project on the left to view details and relaunch it."
                )
                .frame(minHeight: 240)
                .padding(.horizontal, 8)
            }
        }
    }

    private var liveSessionPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Text("Live Session")
                    .font(.system(size: 18, weight: .medium, design: .rounded))

                Spacer()

                captureSessionButton
            }

            if trackedApps.isEmpty {
                EmptyStateView(
                    title: "No Session Activity Yet",
                    systemImage: "clock.arrow.circlepath",
                    message: "Keep the app open while you work, then capture the session into a project draft."
                )
                .frame(minHeight: 160)
            } else {
                Text(sessionSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    sectionEyebrow("Now")
                    showcaseLane(items: trackedApps, cardWidth: 190) { app in
                        activeAppCard(app)
                    } empty: {
                        detailPlaceholder("No active apps yet.")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionEyebrow("Recent Activity")

                    VStack(spacing: 0) {
                        ForEach(Array(trackedApps.prefix(5).enumerated()), id: \.element.id) { index, app in
                            activeAppRow(app)

                            if index < min(trackedApps.count, 5) - 1 {
                                Divider()
                                    .overlay(Color.primary.opacity(0.06))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .padding(.top, 2)

                Text("Local only. No screen contents or keystrokes are recorded.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if sparkleUpdateService.isRunningBetaBuild {
                    Text(sparkleUpdateService.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private func projectRow(_ project: Project) -> some View {
        let isSelected = project.id == selection
        let appCount = project.apps.normalizedEntries().count
        let linkCount = project.urls.normalizedEntries().count
        let retentionInfo = retentionStatus(for: project)

        return Button {
            selection = project.id
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(sidebarPrimaryText)
                        .lineLimit(1)

                    if project.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(favoriteAccentColor)
                    }

                    Spacer(minLength: 0)
                }

                HStack(alignment: .center, spacing: 8) {
                    Text("\(appCount) apps · \(linkCount) links")
                        .font(.system(size: 10))
                        .foregroundStyle(sidebarTertiaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if let retentionInfo {
                        HStack(spacing: 5) {
                            Image(systemName: "hourglass")
                                .font(.system(size: 8, weight: .semibold))
                            Text(retentionInfo.label)
                                .lineLimit(1)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(retentionTextColor(isSelected: isSelected))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.06))
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedSidebarRowFill)

                        if let retentionInfo {
                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                appAccentColor.opacity(colorScheme == .dark ? 0.18 : 0.14),
                                                appAccentColor.opacity(colorScheme == .dark ? 0.06 : 0.04)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, proxy.size.width * retentionInfo.progress))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(appAccentColor)
                        .frame(width: 4, height: 26)
                        .offset(x: 2)
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05), lineWidth: 0.6)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Launch") {
                launch(project)
            }

            Menu("Selective Launch") {
                ForEach(ProjectLaunchMode.allCases) { mode in
                    Button {
                        launch(project, mode: mode)
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                }
            }

            Button(project.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                store.toggleFavorite(project)
            }

            Button("Edit") {
                editorContext = .edit(project)
            }

            Divider()

            Button("Delete", role: .destructive) {
                projectPendingDeletion = project
            }
        }
    }

    private var selectedSidebarRowFill: Color {
        colorScheme == .dark
            ? appAccentColor.opacity(0.12)
            : appAccentColor.opacity(0.18)
    }

    private func retentionTextColor(isSelected: Bool) -> Color {
        isSelected
            ? (colorScheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.78))
            : sidebarSecondaryText.opacity(0.9)
    }

    private func retentionStatus(for project: Project) -> (label: String, progress: CGFloat)? {
        guard let retentionDays = settingsStore.sessionRetentionDays,
              let sessionCapturedAt = project.sessionCapturedAt else {
            return nil
        }

        let totalInterval = max(1, Double(retentionDays) * 86_400)
        let elapsed = max(0, Date().timeIntervalSince(sessionCapturedAt))
        let progress = min(1, max(0, elapsed / totalInterval))
        let remaining = max(0, totalInterval - elapsed)
        let remainingDays = Int(ceil(remaining / 86_400))

        let label: String
        switch remainingDays {
        case 0:
            label = "Expires today"
        case 1:
            label = "1 day left"
        default:
            label = "\(remainingDays) days left"
        }

        return (label, CGFloat(progress))
    }

    private func railProjectSection(title: String, projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(sidebarSecondaryText.opacity(0.92))
                .padding(.horizontal, 10)

            VStack(spacing: 2) {
                ForEach(projects) { project in
                    projectRow(project)
                }
            }
        }
    }

    private func activeAppCard(_ app: TrackedApplicationUsage) -> some View {
        HStack(spacing: 12) {
            circularAppIcon(forPath: app.appPath, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(format(duration: app.accumulatedFocusTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Circle()
                        .fill(app.isRunning ? activeStatusColor : Color.secondary.opacity(0.35))
                        .frame(width: 6, height: 6)

                    Text(app.isRunning ? "Running" : "Idle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 176, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var captureSessionButton: some View {
        Button {
            captureSession()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(appAccentColor.opacity(colorScheme == .dark ? 0.18 : 0.12))

                    Image(systemName: "viewfinder.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? .white : appAccentColor)
                }
                .frame(width: 24, height: 24)

                Text("Capture")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.035))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05), lineWidth: 0.6)
            )
            .overlay {
                GeometryReader { proxy in
                    let streakWidth = max(20, proxy.size.width * 0.18)

                    ZStack {
                        LinearGradient(
                            colors: [
                                appAccentColor.opacity(0.02),
                                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.22),
                                appAccentColor.opacity(colorScheme == .dark ? 0.16 : 0.12),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: streakWidth, height: proxy.size.height * 0.74)
                        .clipShape(Capsule(style: .continuous))
                        .blur(radius: 2.4)
                        .rotationEffect(.degrees(-12))
                        .offset(x: captureSheenPosition * proxy.size.width)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(Capsule(style: .continuous))
                    .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            captureButtonHovered = hovering
            if hovering {
                startCaptureSheenLoopIfNeeded()
            } else {
                captureSheenTask?.cancel()
                captureSheenTask = nil
                captureSheenPosition = -1.3
            }
        }
        .onDisappear {
            captureSheenTask?.cancel()
            captureSheenTask = nil
            captureSheenPosition = -1.3
        }
    }

    private func startCaptureSheenLoopIfNeeded() {
        guard captureSheenTask == nil else { return }

        captureSheenTask = Task { @MainActor in
            while !Task.isCancelled && captureButtonHovered {
                captureSheenPosition = -1.3
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled, captureButtonHovered else { break }

                withAnimation(.easeOut(duration: 0.78)) {
                    captureSheenPosition = 1.45
                }

                try? await Task.sleep(nanoseconds: 1_900_000_000)
            }
            captureSheenTask = nil
        }
    }

    private func activeAppRow(_ app: TrackedApplicationUsage) -> some View {
        HStack(spacing: 16) {
            circularAppIcon(forPath: app.appPath, size: 28)
                .grayscale(app.isRunning ? 0 : 0.8)
                .opacity(app.isRunning ? 1.0 : 0.6)

            Text(app.displayName)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(app.isRunning ? .primary : .secondary)

            if app.isRunning {
                Circle()
                    .fill(activeStatusColor)
                    .frame(width: 5, height: 5)
            }

            Spacer()

            Text(format(duration: app.accumulatedFocusTime))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private var sessionSummaryText: String {
        let runningCount = trackedApps.filter(\.isRunning).count
        if let focus = trackedApps.first?.displayName {
            return "\(runningCount) active • \(sessionUptime) tracked • Focus on \(focus)"
        }
        return "\(runningCount) active • \(sessionUptime) tracked"
    }

    private func workspaceSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(primarySurfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05),
            radius: colorScheme == .dark ? 12 : 18,
            x: 0,
            y: 8
        )
    }

    private var detailCanvasFill: Color {
        colorScheme == .dark
            ? settingsStore.accentTheme.darkModeCanvasColor
            : Color.white
    }

    private var detailCanvasBackground: some View {
        detailCanvasFill
    }

    private var detailTopGlassStrip: some View {
        Group {
            if #available(macOS 26.0, *) {
                if windowIsActive {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 0))
                        .overlay {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            detailTopGlassTint.opacity(colorScheme == .dark ? 0.18 : 0.12),
                                            detailTopGlassTint.opacity(colorScheme == .dark ? 0.08 : 0.05),
                                            .clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    detailTopGlassTint.opacity(colorScheme == .dark ? 0.18 : 0.08),
                                    detailCanvasFill.opacity(0.96),
                                    detailCanvasFill.opacity(0.72),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            } else {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    detailTopGlassTint.opacity(colorScheme == .dark ? 0.34 : 0.22),
                                    detailTopGlassTint.opacity(colorScheme == .dark ? 0.18 : 0.11),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.12),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18),
                                    Color.white.opacity(colorScheme == .dark ? 0.03 : 0.08),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.16))
                            .frame(height: 0.9)
                        Spacer()
                    }
                }
            }
        }
        .mask(
            LinearGradient(
                colors: [
                    .black,
                    Color.black.opacity(0.96),
                    Color.black.opacity(0.7),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var detailTopGlassTint: Color {
        colorScheme == .dark
            ? settingsStore.accentTheme.darkModeSurfaceColor
            : appAccentColor.opacity(0.5)
    }

    private func projectHero(_ project: Project, compactActions: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text(projectHeroSubtitle(for: project))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                }

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    heroIconAction(icon: notePanelPresented ? "sidebar.right" : "note.text", tooltip: notePanelPresented ? "Hide Notes" : "Notes") {
                        toggleNotesPanel()
                    }
                    .keyboardShortcut("n", modifiers: [.command, .option])

                    heroIconAction(icon: "arrow.triangle.2.circlepath", tooltip: "Update from Current Session") {
                        refreshSelectedProjectFromSession()
                    }
                    .keyboardShortcut("u", modifiers: [.command, .shift])

                    heroIconAction(icon: "pencil", tooltip: "Edit") {
                        editorContext = .edit(project)
                    }

                    heroIconAction(icon: "trash", tooltip: "Delete", role: .destructive) {
                        projectPendingDeletion = project
                    }

                    HStack(spacing: 4) {
                        Button {
                            launch(project)
                        } label: {
                            HStack(spacing: compactActions ? 0 : 6) {
                                Image(systemName: "play.fill")
                                if !compactActions {
                                    Text("Launch")
                                }
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.leading, compactActions ? 11 : 16)
                            .padding(.trailing, compactActions ? 11 : 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(appAccentColor)
                            )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.defaultAction)

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
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .frame(width: 28, height: 32)
                                .background(Capsule().fill(appAccentColor))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }
                }
            }

            // Meta chips row
            HStack(spacing: 6) {
                if project.sessionCapturedAt != nil {
                    projectMetaChip(title: "Session", systemImage: "clock.badge.checkmark")
                }

                if project.isFavorite {
                    Button {
                        store.toggleFavorite(project)
                    } label: {
                        projectMetaChip(title: "Favorite", systemImage: "star.fill", tint: favoriteAccentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        store.toggleFavorite(project)
                    } label: {
                        projectMetaChip(title: "Favorite", systemImage: "star")
                    }
                    .buttonStyle(.plain)
                }

                if let folderPath = project.folderPath.nilIfBlank {
                    projectMetaChip(title: URL(fileURLWithPath: folderPath.expandedPath).lastPathComponent, systemImage: "folder")
                }
            }
        }
    }

    private func projectHeroSubtitle(for project: Project) -> String {
        if let description = project.projectDescription.nilIfBlank {
            return description
        }

        if let lastLaunchedAt = project.lastLaunchedAt {
            return "Opened \(lastLaunchedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "Updated \(project.updatedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func heroIconAction(icon: String, tooltip: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(role == .destructive ? Color.red.opacity(0.82) : .secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                )
                .overlay(
                    Circle()
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func projectMetricStrip(_ project: Project) -> some View {
        HStack(spacing: 0) {
            compactMetric(value: "\(project.apps.normalizedEntries().count)", subtitle: "Apps")
            compactMetric(value: "\(project.urls.normalizedEntries().count)", subtitle: "Links")
            if !project.terminalCommands.normalizedEntries().isEmpty {
                compactMetric(value: "\(project.terminalCommands.normalizedEntries().count)", subtitle: "Commands")
            }
            if project.hasFolder {
                compactMetric(value: project.folderLaunchMode.title, subtitle: "Opens in")
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func compactMetric(value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 72, alignment: .leading)
        .padding(.trailing, 22)
    }

    private var favoriteAccentColor: Color {
        colorScheme == .dark
            ? appAccentColor.opacity(0.96)
            : appAccentColor.opacity(0.88)
    }

    private func projectOverviewSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if project.folderPath.nilIfBlank != nil || project.sessionCapturedAt != nil || project.lastNote.nilIfBlank != nil {
                Text("Overview")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 40) {
                    if project.folderPath.nilIfBlank != nil || project.sessionCapturedAt != nil {
                        workspaceOverviewColumn(project)
                    }
                    if project.lastNote.nilIfBlank != nil {
                        noteOverviewColumn(project)
                    }
                }

                VStack(alignment: .leading, spacing: 20) {
                    if project.folderPath.nilIfBlank != nil || project.sessionCapturedAt != nil {
                        workspaceOverviewColumn(project)
                    }
                    if project.lastNote.nilIfBlank != nil {
                        noteOverviewColumn(project)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func launchSetupSection(_ project: Project) -> some View {
        let hasApps = !project.apps.normalizedEntries().isEmpty
        let hasLinks = !project.urls.normalizedEntries().isEmpty
        let hasCommands = !project.terminalCommands.normalizedEntries().isEmpty

        return VStack(alignment: .leading, spacing: 16) {
            Text("Launch Setup")
                .font(.system(size: 16, weight: .semibold, design: .rounded))

            VStack(alignment: .leading, spacing: 24) {
                if hasApps {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionEyebrow("Apps to Reopen")
                        showcaseLane(items: project.apps.normalizedEntries(), cardWidth: notePanelPresented ? 184 : 208) { appEntry in
                            projectAppCard(entry: appEntry)
                        } empty: {
                            EmptyView()
                        }
                    }
                }

                if hasLinks || hasCommands {
                    Group {
                        if notePanelPresented {
                            VStack(alignment: .leading, spacing: 24) {
                                if hasLinks { linkColumn(project) }
                                if hasCommands { commandColumn(project) }
                            }
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .top, spacing: 40) {
                                    if hasLinks { linkColumn(project) }
                                    if hasCommands { commandColumn(project) }
                                }

                                VStack(alignment: .leading, spacing: 24) {
                                    if hasLinks { linkColumn(project) }
                                    if hasCommands { commandColumn(project) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func workspaceOverviewColumn(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let folderPath = project.folderPath.nilIfBlank {
                detailLine(label: "Folder", value: folderPath)
            }

            if let created = project.sessionCapturedAt {
                detailLine(
                    label: "Captured from session",
                    value: created.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteOverviewColumn(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Latest Note")
                .font(.headline.weight(.semibold))

            Text(notePreviewText(for: project))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func projectNotesPanel(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Notes")
                        .font(.title3.weight(.semibold))

                    Text("A lightweight scratchpad for updates, ideas, and next steps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: toggleNotesPanel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
                        )
                }
                .buttonStyle(.plain)
            }

            Text(project.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            notionNoteEditor
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Text("Autosaves as you type")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !noteDraft.trimmed.isEmpty {
                    Text("Updated just now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var notionNoteEditor: some View {
        ProjectNotesEditor(
            text: Binding(
                get: { noteDraft },
                set: { newValue in
                    noteDraft = newValue
                    scheduleNoteAutosave()
                }
            ),
            placeholder: "Start typing project updates, blockers, ideas, or next steps...\n\nUse markdown shortcuts like #, ##, -, - [ ], 1. and >."
        )
        .frame(minHeight: 420, maxHeight: .infinity)
    }

    private var notesSidebarBackground: some View {
        ZStack {
            GlassSidebarBackground(material: .sidebar)

            Rectangle()
                .fill(sidebarToneOverlay)
        }
    }

    private func linkColumn(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow("Web Links")

            ForEach(project.urls.normalizedEntries().prefix(3), id: \.self) { url in
                compactReferenceRow(symbol: "link", text: url)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commandColumn(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow("Terminal")

            ForEach(project.terminalCommands.normalizedEntries().prefix(3), id: \.self) { command in
                compactReferenceRow(symbol: "terminal", text: command, monospaced: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionEyebrow(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func detailLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func compactReferenceRow(symbol: String, text: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(appAccentColor)
                .frame(width: 16, height: 16)

            Group {
                if monospaced {
                    Text(text)
                        .font(.system(.subheadline, design: .monospaced))
                } else {
                    Text(text)
                        .font(.subheadline)
                }
            }
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(detailCardFill)
        )
    }

    private func detailPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func minimalLiveStat(value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }

    @ViewBuilder
    private func showcaseStrip<Item: Identifiable, Content: View>(
        items: [Item],
        cardWidth: CGFloat,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        if showcaseIsActive, items.count > 1 {
            AutoShowcaseStrip(
                items: items,
                cardWidth: cardWidth,
                spacing: 12,
                content: content
            )
            .frame(height: 104)
        } else {
            DraggableShowcaseStrip(
                items: items,
                cardWidth: cardWidth,
                spacing: 12,
                content: content
            )
            .frame(height: 104)
        }
    }

    @ViewBuilder
    private func showcaseLane<Item: Identifiable, Content: View, EmptyContent: View>(
        items: [Item],
        cardWidth: CGFloat,
        @ViewBuilder content: @escaping (Item) -> Content,
        @ViewBuilder empty: @escaping () -> EmptyContent
    ) -> some View {
        if items.isEmpty {
            empty()
        } else {
            showcaseStrip(items: items, cardWidth: cardWidth, content: content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(colorScheme == .dark ? themedDarkSurfaceColor : Color.white.opacity(0.9))
                            
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                colorScheme == .dark
                                    ? themedDarkSurfaceColor.opacity(0.72)
                                    : Color.black.opacity(0.06),
                                lineWidth: colorScheme == .dark ? 5 : 2
                            )
                            .blur(radius: 4)
                            .offset(y: colorScheme == .dark ? 3 : 1)
                            .mask(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.15)
                                    : Color.black.opacity(0.05),
                                lineWidth: 1
                            )
                            .padding(1)
                            .mask(
                                LinearGradient(
                                    colors: colorScheme == .dark ? [.clear, .white] : [.white, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                colorScheme == .dark
                                    ? themedDarkSurfaceColor.opacity(0.88)
                                    : Color.black.opacity(0.06),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    @ViewBuilder
    private func showcaseLane<EmptyContent: View>(
        items: [String],
        cardWidth: CGFloat,
        @ViewBuilder content: @escaping (String) -> some View,
        @ViewBuilder empty: @escaping () -> EmptyContent
    ) -> some View {
        let wrapped = items.enumerated().map { IndexedShowcaseItem(index: $0.offset, value: $0.element) }
        showcaseLane(items: wrapped, cardWidth: cardWidth) { item in
            content(item.value)
        } empty: {
            empty()
        }
    }

    @ViewBuilder
    private func showcaseStrip(
        items: [String],
        cardWidth: CGFloat,
        @ViewBuilder content: @escaping (String) -> some View
    ) -> some View {
        let wrapped = items.enumerated().map { IndexedShowcaseItem(index: $0.offset, value: $0.element) }
        showcaseStrip(items: wrapped, cardWidth: cardWidth) { item in
            content(item.value)
        }
    }

    private func projectAppCard(entry: String) -> some View {
        HStack(spacing: 12) {
            circularApplicationIcon(for: entry, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(projectAppDisplayName(for: entry))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text("Reopens with this project")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func projectMetaChip(title: String, systemImage: String, tint: Color? = nil) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint ?? .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.04))
            )
    }

    private var primarySurfaceFill: Color {
        colorScheme == .dark
            ? themedDarkSurfaceColor.opacity(0.84)
            : Color.white.opacity(0.80)
    }

    private var detailCardFill: Color {
        colorScheme == .dark ? themedDarkSurfaceColor : Color(white: 0.96)
    }

    private var nestedSurfaceFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.025)
            : Color.white.opacity(0.58)
    }

    private func minimalMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 21, weight: .semibold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func detailRow(title: String, value: String, secondary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .foregroundStyle(secondary ? .secondary : .primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func projectAppChip(entry: String) -> some View {
        HStack(spacing: 8) {
            if let icon = applicationIcon(for: entry, size: 18) {
                icon
            } else {
                Image(systemName: "app")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(projectAppDisplayName(for: entry))
                .font(.subheadline)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
        )
    }

    private var sidebarToneOverlay: Color {
        settingsStore.accentTheme.railTint(for: colorScheme)
    }

    private var sidebarPrimaryText: Color {
        colorScheme == .dark ? .white : .black
    }

    private var sidebarSecondaryText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.74)
            : Color.black.opacity(0.88)
    }

    private var sidebarTertiaryText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.48)
            : Color.black.opacity(0.62)
    }

    private func sidebarIconButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(sidebarSecondaryText)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func sidebarStatChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(sidebarTertiaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04))
            )
    }

    private func scrollOffsetProbe(in coordinateSpace: String) -> some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: ScrollOffsetKey.self,
                    value: proxy.frame(in: .named(coordinateSpace)).minY
                )
        }
        .frame(height: 0)
    }

    private func infoChip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
    }

    private func compactMeta(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func appIcon(forPath appPath: String, size: CGFloat) -> some View {
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        icon.size = NSSize(width: size * 2, height: size * 2)

        return Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: max(7, size * 0.22), style: .continuous))
    }

    private func applicationIcon(for entry: String?, size: CGFloat) -> AnyView? {
        guard let appURL = resolveApplicationURL(from: entry) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: size * 2, height: size * 2)

        return AnyView(
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(6, size * 0.2), style: .continuous))
        )
    }

    private func resolveApplicationURL(from entry: String?) -> URL? {
        guard let entry else {
            return nil
        }

        let trimmedEntry = entry.trimmed
        guard !trimmedEntry.isEmpty else {
            return nil
        }

        if trimmedEntry.hasPrefix("/") || trimmedEntry.hasPrefix("~") {
            let fileURL = URL(fileURLWithPath: trimmedEntry.expandedPath)
            return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
        }

        if trimmedEntry.contains("."),
           let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmedEntry) {
            return bundleURL
        }

        let candidateNames = trimmedEntry.hasSuffix(".app") ? [trimmedEntry] : [trimmedEntry, "\(trimmedEntry).app"]
        let searchRoots = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "~/Applications"
        ]

        for root in searchRoots {
            let rootURL = URL(fileURLWithPath: root.expandedPath, isDirectory: true)

            for candidateName in candidateNames {
                let candidateURL = rootURL.appendingPathComponent(candidateName, isDirectory: true)
                if FileManager.default.fileExists(atPath: candidateURL.path) {
                    return candidateURL
                }
            }
        }

        return nil
    }

    private func projectAppDisplayName(for entry: String) -> String {
        let trimmedEntry = entry.trimmed

        if trimmedEntry.hasPrefix("/") || trimmedEntry.hasPrefix("~") {
            return URL(fileURLWithPath: trimmedEntry.expandedPath)
                .deletingPathExtension()
                .lastPathComponent
        }

        if trimmedEntry.contains("."),
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmedEntry) {
            return appURL.deletingPathExtension().lastPathComponent
        }

        return trimmedEntry.replacingOccurrences(of: ".app", with: "")
    }

    private func circularAppIcon(forPath appPath: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(detailCardFill)

            appIcon(forPath: appPath, size: size * 0.68)
        }
        .frame(width: size, height: size)
    }

    private func circularApplicationIcon(for entry: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(detailCardFill)

            if let icon = applicationIcon(for: entry, size: size * 0.68) {
                icon
            } else {
                Image(systemName: "app")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func save(_ project: Project) {
        if store.projects.contains(where: { $0.id == project.id }) {
            store.update(project)
        } else {
            store.add(project)
        }

        selection = project.id
        presentStoreErrorIfNeeded()
    }

    private func delete(_ project: Project) {
        store.delete(project)
        if selection == project.id {
            selection = nil
        }

        syncSelection()
        presentStoreErrorIfNeeded()
    }

    private func syncSelection() {
        guard !store.projects.isEmpty else {
            selection = nil
            return
        }

        if let selection,
           store.projects.contains(where: { $0.id == selection }) {
            return
        }

        selection = store.projects.first?.id
    }

    private func handleOpenProjectRequest(_ notification: Notification) {
        guard let projectID = notification.userInfo?["projectID"] as? UUID,
              let project = store.projects.first(where: { $0.id == projectID }) else {
            return
        }

        contentMode = .projects
        selection = project.id
        notePanelPresented = false
        launch(project)
    }

    private func launch(_ project: Project, mode: ProjectLaunchMode = .everything) {
        Task {
            let result = await launcher.launch(project, mode: mode)
            store.recordLaunch(of: project)
            if result.hasWarnings {
                userAlert = UserAlert(
                    title: mode == .everything ? "Launched with Warnings" : "\(mode.title) Launched with Warnings",
                    message: result.warnings.joined(separator: "\n\n")
                )
            }
        }
    }

    private func captureSession() {
        let generator = SessionProjectGenerator(sessionTracker: sessionTracker)
        let generated = generator.generateDraft()
        editorContext = .generated(generated.draft)

        if settingsStore.showSessionCaptureAlert {
            userAlert = UserAlert(
                title: "Session Captured",
                message: "Generated a draft from \(generated.sourceSummary). Review it before saving."
            )
        }
    }

    private func refreshSelectedProjectFromSession() {
        guard let project = selectedProject else {
            return
        }

        let generator = SessionProjectGenerator(sessionTracker: sessionTracker)
        let refreshed = generator.refresh(project: project)

        store.update(refreshed.project)
        selection = refreshed.project.id
        syncNoteDraft()
        presentStoreErrorIfNeeded()

        userAlert = UserAlert(
            title: "Project Updated",
            message: "Updated from \(refreshed.sourceSummary). Existing name, folder, commands, favorites, and notes were kept."
        )
    }

    private func presentStoreErrorIfNeeded() {
        guard let error = store.persistenceError else {
            return
        }

        userAlert = UserAlert(
            title: error.errorDescription ?? "Persistence Error",
            message: error.recoverySuggestion ?? "An unknown storage error occurred."
        )
        store.clearError()
    }

    private func syncNoteDraft() {
        guard let project = selectedProject else {
            noteDraft = ""
            notePanelPresented = false
            noteSaveTask?.cancel()
            noteSaveTask = nil
            return
        }

        if noteDraft != project.lastNote {
            noteDraft = project.lastNote
        }
    }

    private func scheduleNoteAutosave() {
        noteSaveTask?.cancel()

        guard let project = selectedProject else {
            return
        }

        let noteToSave = noteDraft
        noteSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else {
                return
            }

            store.updateNote(for: project.id, note: noteToSave)
        }
    }

    private func toggleNotesPanel() {
        guard selectedProject != nil else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            notePanelPresented.toggle()
        }
    }

    private func notePreviewText(for project: Project) -> String {
        guard let note = project.lastNote.nilIfBlank else {
            return "No note saved yet. Add a short note so future-you knows exactly where to pick back up."
        }

        return note
            .components(separatedBy: .newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "\n")
    }

    private func format(duration: TimeInterval) -> String {
        let totalMinutes = max(1, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }
}

private enum ProjectEditorContext: Identifiable {
    case create
    case edit(Project)
    case generated(ProjectDraft)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let project):
            return "edit-\(project.id.uuidString)"
        case .generated:
            return "generated"
        }
    }

    var project: Project? {
        switch self {
        case .create:
            return nil
        case .edit(let project):
            return project
        case .generated:
            return nil
        }
    }

    var draft: ProjectDraft? {
        switch self {
        case .generated(let draft):
            return draft
        case .create, .edit:
            return nil
        }
    }
}

private enum ContentMode {
    case projects
    case settings
}

private struct UserAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension Notification.Name {
    static let projectResumeCaptureSessionRequested = Notification.Name("projectResumeCaptureSessionRequested")
    static let projectResumeNewProjectRequested = Notification.Name("projectResumeNewProjectRequested")
    static let projectResumeShowSettingsRequested = Notification.Name("projectResumeShowSettingsRequested")
    static let projectResumeShowGuideRequested = Notification.Name("projectResumeShowGuideRequested")
    static let projectResumeRefreshProjectRequested = Notification.Name("projectResumeRefreshProjectRequested")
    static let projectResumeOpenProjectRequested = Notification.Name("projectResumeOpenProjectRequested")
    static let projectResumeSidebarChromeLayoutChanged = Notification.Name("projectResumeSidebarChromeLayoutChanged")
}

private struct IndexedShowcaseItem: Identifiable {
    let index: Int
    let value: String

    var id: Int { index }
}

private struct AutoShowcaseStrip<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let cardWidth: CGFloat
    let spacing: CGFloat
    let content: (Item) -> Content

    var body: some View {
        GeometryReader { proxy in
            let step = cardWidth + spacing
            let contentWidth = CGFloat(items.count) * step

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let travel = contentWidth > proxy.size.width ? CGFloat(elapsed) * 24 : 0
                let offset = contentWidth > 0 ? -(travel.truncatingRemainder(dividingBy: contentWidth)) : 0

                HStack(spacing: spacing) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: cardWidth, alignment: .leading)
                    }

                    if contentWidth > proxy.size.width {
                        ForEach(items) { item in
                            content(item)
                                .frame(width: cardWidth, alignment: .leading)
                        }
                    }
                }
                .offset(x: offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .clipped()
            }
        }
    }
}

private struct DraggableShowcaseStrip<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let cardWidth: CGFloat
    let spacing: CGFloat
    let content: (Item) -> Content

    @State private var settledOffset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = CGFloat(items.count) * cardWidth + CGFloat(max(items.count - 1, 0)) * spacing
            let viewportWidth = proxy.size.width
            let minimumOffset = min(0, viewportWidth - contentWidth)
            let liveOffset = clampedOffset(settledOffset + dragTranslation, minimumOffset: minimumOffset)

            HStack(spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                        .frame(width: cardWidth, alignment: .leading)
                }
            }
            .padding(.vertical, 2)
            .offset(x: liveOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        settledOffset = clampedOffset(settledOffset + value.translation.width, minimumOffset: minimumOffset)
                    }
            )
            .onChange(of: items.count) { _ in
                settledOffset = clampedOffset(settledOffset, minimumOffset: minimumOffset)
            }
            .clipped()
        }
    }

    private func clampedOffset(_ proposed: CGFloat, minimumOffset: CGFloat) -> CGFloat {
        min(0, max(minimumOffset, proposed))
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
