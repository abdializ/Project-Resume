import SwiftUI

// MARK: - Style

public enum ResumeProjectWidgetCardStyle: Equatable {
    case small
    case medium
    case large

    var cornerRadius: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 22
        case .large: return 24
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 18
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return 11
        case .medium: return 12
        case .large: return 16
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 28
        case .large: return 34
        }
    }

    var iconFontSize: CGFloat {
        switch self {
        case .small: return 10.5
        case .medium: return 12
        case .large: return 15
        }
    }

    var titleFontSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 17
        case .large: return 21
        }
    }
}

// MARK: - Resume Last Project Card

public struct ResumeProjectWidgetCard: View {
    public let snapshot: WidgetSnapshot
    public let style: ResumeProjectWidgetCardStyle
    public let launchURL: URL?
    public let captureURL: URL?

    @Environment(\.colorScheme) private var colorScheme

    public init(
        snapshot: WidgetSnapshot,
        style: ResumeProjectWidgetCardStyle,
        launchURL: URL? = nil,
        captureURL: URL? = nil
    ) {
        self.snapshot = snapshot
        self.style = style
        self.launchURL = launchURL
        self.captureURL = captureURL
    }

    private var project: WidgetProjectSnapshot {
        snapshot.lastProject ?? .preview
    }

    private var accent: Color {
        snapshot.accentTheme.resolvedAccentColor(for: colorScheme)
    }

    private var statusText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        if let lastLaunchedAt = project.lastLaunchedAt {
            return formatter.localizedString(for: lastLaunchedAt, relativeTo: .now)
        }

        return formatter.localizedString(for: project.updatedAt, relativeTo: .now)
    }

    private var notePreviewText: String {
        if let notePreview = project.notePreview, !notePreview.isEmpty {
            return notePreview
        }
        return "Ready to jump back in."
    }

    public var body: some View {
        WidgetGlassShell(accentTheme: snapshot.accentTheme, cornerRadius: style.cornerRadius) {
            switch style {
            case .small:
                smallLayout
            case .medium:
                mediumLayout
            case .large:
                largeLayout
            }
        }
    }

    // MARK: Small — 158 x 158 usable

    @ViewBuilder
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RESUME")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Spacer(minLength: 8)

            Text(project.name)
                .font(.system(size: style.titleFontSize, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 2)

            HStack(alignment: .center, spacing: 0) {
                ResourceChips(project: project, accent: accent, compact: true)

                Spacer(minLength: 4)

                if let launchURL {
                    WidgetActionPill(
                        title: nil,
                        systemImage: "play.fill",
                        accent: accent,
                        priority: .primary,
                        compact: true,
                        destinationURL: launchURL
                    )
                }
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
    }

    // MARK: Medium — 338 x 158 usable

    @ViewBuilder
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text("RESUME")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text(project.name)
                    .font(.system(size: style.titleFontSize, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(statusText)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }

            Spacer(minLength: 6)

            Text(notePreviewText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 6)

            HStack(alignment: .center, spacing: 0) {
                ResourceChips(project: project, accent: accent, compact: false)

                Spacer(minLength: 6)

                actionRow
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
    }

    // MARK: Large — 338 x 354 usable

    @ViewBuilder
    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RESUME")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Text(project.name)
                        .font(.system(size: style.titleFontSize, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(statusText)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            Spacer(minLength: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)

                Text(notePreviewText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 10)

            ResourceDetailList(project: project, accent: accent)

            Spacer(minLength: 10)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                actionRow
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
    }

    // MARK: Action Row (responsive)

    @ViewBuilder
    private var actionRow: some View {
        ViewThatFits(in: .horizontal) {
            actionPair(captureCompact: false, launchCompact: false)
            actionPair(captureCompact: true, launchCompact: false)
            actionPair(captureCompact: true, launchCompact: true)
            launchOnly
        }
    }

    @ViewBuilder
    private func actionPair(captureCompact: Bool, launchCompact: Bool) -> some View {
        HStack(spacing: 6) {
            if let captureURL {
                WidgetActionPill(
                    title: captureCompact ? nil : "Capture",
                    systemImage: "camera.viewfinder",
                    accent: accent,
                    priority: .secondary,
                    compact: captureCompact,
                    destinationURL: captureURL
                )
            }

            if let launchURL {
                WidgetActionPill(
                    title: launchCompact ? nil : "Launch",
                    systemImage: "play.fill",
                    accent: accent,
                    priority: .primary,
                    compact: launchCompact,
                    destinationURL: launchURL
                )
            }
        }
    }

    @ViewBuilder
    private var launchOnly: some View {
        if let launchURL {
            WidgetActionPill(
                title: nil,
                systemImage: "play.fill",
                accent: accent,
                priority: .primary,
                compact: true,
                destinationURL: launchURL
            )
        }
    }
}

// MARK: - Favorites Card

public struct FavoriteProjectsWidgetCard: View {
    public let snapshot: WidgetSnapshot
    public let style: ResumeProjectWidgetCardStyle

    @Environment(\.colorScheme) private var colorScheme

    public init(snapshot: WidgetSnapshot, style: ResumeProjectWidgetCardStyle) {
        self.snapshot = snapshot
        self.style = style
    }

    private var accent: Color {
        snapshot.accentTheme.resolvedAccentColor(for: colorScheme)
    }

    private var projects: [WidgetProjectSnapshot] {
        let favorites = snapshot.favoriteProjects
        if favorites.isEmpty, let lastProject = snapshot.lastProject {
            return [lastProject]
        }
        return favorites
    }

    public var body: some View {
        WidgetGlassShell(accentTheme: snapshot.accentTheme, cornerRadius: style.cornerRadius) {
            switch style {
            case .small:
                smallLayout
            case .medium:
                mediumLayout
            case .large:
                largeLayout
            }
        }
    }

    // MARK: Small

    @ViewBuilder
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accent)

                Text("FAVS")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Spacer(minLength: 6)

            if let project = projects.first {
                if let url = WidgetBridge.projectURLIfValid(for: project.id) {
                    Link(destination: url) {
                        smallFavoriteContent(project)
                    }
                    .buttonStyle(.plain)
                } else {
                    smallFavoriteContent(project)
                }
            } else {
                emptyState
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
    }

    @ViewBuilder
    private func smallFavoriteContent(_ project: WidgetProjectSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FAVORITE")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Text(project.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 1)

            ResourceChips(project: project, accent: accent, compact: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Medium

    @ViewBuilder
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accent)

                Text("FAVORITES")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(projects.count)")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            if projects.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(projects.prefix(3), id: \.id) { project in
                        favoriteRow(for: project, showNote: false)
                    }
                }
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
    }

    // MARK: Large

    @ViewBuilder
    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)

                Text("FAVORITES")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(projects.count) project\(projects.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            if projects.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(projects.prefix(5), id: \.id) { project in
                        favoriteRow(for: project, showNote: true)
                    }
                }
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
    }

    // MARK: Shared Rows

    @ViewBuilder
    private func favoriteRow(for project: WidgetProjectSnapshot, showNote: Bool) -> some View {
        let content = HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: showNote ? 12.5 : 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if showNote, let note = project.notePreview, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else {
                    ResourceChips(project: project, accent: accent, compact: true)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent.opacity(colorScheme == .dark ? 0.6 : 0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, showNote ? 8 : 6)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04), lineWidth: 0.6)
                }
        }

        if let url = WidgetBridge.projectURLIfValid(for: project.id) {
            Link(destination: url) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "star")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.tertiary)

            Text("No favorites yet")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Resource Chips

private struct ResourceChips: View {
    let project: WidgetProjectSnapshot
    let accent: Color
    let compact: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            if project.appCount > 0 {
                chip(icon: "square.grid.2x2", count: project.appCount)
            }
            if project.linkCount > 0 {
                chip(icon: "link", count: project.linkCount)
            }
            if project.commandCount > 0 {
                chip(icon: "terminal", count: project.commandCount)
            }
        }
    }

    @ViewBuilder
    private func chip(icon: String, count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: compact ? 7.5 : 8.5, weight: .semibold))
                .foregroundStyle(accent.opacity(colorScheme == .dark ? 0.8 : 0.65))

            Text("\(count)")
                .font(.system(size: compact ? 9.5 : 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Resource Detail List (Large Widget)

private struct ResourceDetailList: View {
    let project: WidgetProjectSnapshot
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if project.appCount > 0 {
                resourceRow(
                    icon: "square.grid.2x2",
                    text: "\(project.appCount) App\(project.appCount == 1 ? "" : "s")"
                )
            }
            if project.linkCount > 0 {
                resourceRow(
                    icon: "link",
                    text: "\(project.linkCount) Link\(project.linkCount == 1 ? "" : "s")"
                )
            }
            if project.commandCount > 0 {
                resourceRow(
                    icon: "terminal",
                    text: "\(project.commandCount) Command\(project.commandCount == 1 ? "" : "s")"
                )
            }
            if let folderName = project.folderName {
                resourceRow(icon: "folder", text: folderName)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.04 : 0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.04), lineWidth: 0.5)
                }
        }
    }

    @ViewBuilder
    private func resourceRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent.opacity(0.75))
                .frame(width: 16, alignment: .center)

            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Glass Shell

private struct WidgetGlassShell<Content: View>: View {
    let accentTheme: AppAccentTheme
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color {
        accentTheme.resolvedAccentColor(for: colorScheme)
    }

    private var shellBase: Color {
        colorScheme == .dark
            ? accentTheme.darkModeSurfaceColor
            : Color.white.opacity(0.98)
    }

    private var shellOverlay: Color {
        accent.opacity(colorScheme == .dark ? 0.035 : 0.025)
    }

    private var outerStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.07)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    shape.fill(shellBase)
                    shape.fill(shellOverlay)
                    shape.stroke(outerStroke, lineWidth: 0.8)
                }
            }
            .clipShape(shape)
    }
}

// MARK: - Action Pill

private struct WidgetActionPill: View {
    enum Priority {
        case primary
        case secondary
    }

    let title: String?
    let systemImage: String
    let accent: Color
    let priority: Priority
    let compact: Bool
    let destinationURL: URL

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Link(destination: destinationURL) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: compact ? 9 : 9.5, weight: .bold))

                if let title {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 6 : 7)
            .background {
                Capsule(style: .continuous)
                    .fill(background)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(strokeColor, lineWidth: 0.7)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch priority {
        case .primary:
            return colorScheme == .dark ? .white : accent
        case .secondary:
            return .primary.opacity(0.8)
        }
    }

    private var background: AnyShapeStyle {
        switch priority {
        case .primary:
            return AnyShapeStyle(
                accent.opacity(colorScheme == .dark ? 0.24 : 0.14)
            )
        case .secondary:
            return AnyShapeStyle(
                Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035)
            )
        }
    }

    private var strokeColor: Color {
        switch priority {
        case .primary:
            return accent.opacity(colorScheme == .dark ? 0.24 : 0.16)
        case .secondary:
            return Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05)
        }
    }
}

// MARK: - Helpers

private extension WidgetBridge {
    static func projectURLIfValid(for projectID: UUID) -> URL? {
        projectURL(for: projectID)
    }
}
