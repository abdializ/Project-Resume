import SwiftUI

enum ResumeProjectWidgetCardStyle: Equatable {
    case small
    case medium
    case large

    var cornerRadius: CGFloat {
        switch self {
        case .small: return 22
        case .medium: return 24
        case .large: return 26
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

struct ResumeProjectWidgetCard: View {
    let snapshot: WidgetSnapshot
    let style: ResumeProjectWidgetCardStyle

    @Environment(\.colorScheme) private var colorScheme

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

    private var shellColor: Color {
        colorScheme == .dark
            ? snapshot.accentTheme.darkModeCanvasColor.opacity(0.92)
            : Color.white.opacity(0.86)
    }

    private var shellTint: Color {
        colorScheme == .dark
            ? accent.opacity(0.14)
            : accent.opacity(0.08)
    }

    private var strokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.06)
    }

    var body: some View {
        Group {
            switch style {
            case .small:
                smallLayout
            case .medium:
                mediumLayout
            case .large:
                largeLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            widgetShell
        }
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(strokeColor, lineWidth: 0.9)
        }
    }

    // MARK: Small

    @ViewBuilder
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            projectIcon(size: style.iconSize, fontSize: style.iconFontSize)

            Spacer(minLength: 4)

            Text(project.name)
                .font(.system(size: style.titleFontSize, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 2)

            HStack(alignment: .center, spacing: 0) {
                resourceChips(compact: true)

                Spacer(minLength: 4)

                launchPill(compact: true)
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
    }

    // MARK: Medium

    @ViewBuilder
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                projectIcon(size: style.iconSize, fontSize: style.iconFontSize)

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
                resourceChips(compact: false)

                Spacer(minLength: 6)

                launchPill(compact: false)
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
    }

    // MARK: Large

    @ViewBuilder
    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                projectIcon(size: style.iconSize, fontSize: style.iconFontSize)

                VStack(alignment: .leading, spacing: 2) {
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

            resourceDetailList

            Spacer(minLength: 10)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                launchPill(compact: false)
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
    }

    // MARK: Components

    @ViewBuilder
    private func projectIcon(size: CGFloat, fontSize: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(accent.opacity(colorScheme == .dark ? 0.22 : 0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .stroke(accent.opacity(colorScheme == .dark ? 0.18 : 0.08), lineWidth: 0.5)
                }

            Image(systemName: project.resolvedIconSymbol)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func resourceChips(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 7) {
            if project.appCount > 0 {
                chip(icon: "square.grid.2x2", count: project.appCount, compact: compact)
            }
            if project.linkCount > 0 {
                chip(icon: "link", count: project.linkCount, compact: compact)
            }
            if project.commandCount > 0 {
                chip(icon: "terminal", count: project.commandCount, compact: compact)
            }
        }
    }

    @ViewBuilder
    private func chip(icon: String, count: Int, compact: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: compact ? 7.5 : 8.5, weight: .semibold))
                .foregroundStyle(accent.opacity(colorScheme == .dark ? 0.8 : 0.65))

            Text("\(count)")
                .font(.system(size: compact ? 9.5 : 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resourceDetailList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if project.appCount > 0 {
                resourceRow(icon: "square.grid.2x2", text: "\(project.appCount) App\(project.appCount == 1 ? "" : "s")")
            }
            if project.linkCount > 0 {
                resourceRow(icon: "link", text: "\(project.linkCount) Link\(project.linkCount == 1 ? "" : "s")")
            }
            if project.commandCount > 0 {
                resourceRow(icon: "terminal", text: "\(project.commandCount) Command\(project.commandCount == 1 ? "" : "s")")
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

    @ViewBuilder
    private func launchPill(compact: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill")
                .font(.system(size: compact ? 9 : 9.5, weight: .bold))
            if !compact {
                Text("Launch")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .foregroundStyle(colorScheme == .dark ? Color.white : accent)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 6 : 7)
        .background {
            Capsule(style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? accent.opacity(0.28)
                        : accent.opacity(0.12)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(accent.opacity(colorScheme == .dark ? 0.28 : 0.18), lineWidth: 0.8)
                }
        }
    }

    @ViewBuilder
    private var widgetShell: some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            shape
                .fill(shellColor)
                .overlay { shape.fill(shellTint) }
                .glassEffect(.regular, in: shape)
        } else {
            shape
                .fill(shellColor)
                .overlay { shape.fill(shellTint) }
        }
    }
}

#Preview("Small Widget Card") {
    ResumeProjectWidgetCard(snapshot: .preview, style: .small)
        .frame(width: 158, height: 158)
        .padding()
        .background(Color.black.opacity(0.08))
}

#Preview("Medium Widget Card") {
    ResumeProjectWidgetCard(
        snapshot: WidgetSnapshot(
            generatedAt: .now,
            accentTheme: .sky,
            lastProject: .preview,
            favoriteProjects: [.preview]
        ),
        style: .medium
    )
    .frame(width: 338, height: 158)
    .padding()
    .background(Color.black.opacity(0.08))
}

#Preview("Large Widget Card") {
    ResumeProjectWidgetCard(snapshot: .preview, style: .large)
        .frame(width: 338, height: 354)
        .padding()
        .background(Color.black.opacity(0.08))
}
