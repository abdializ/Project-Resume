import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    let isVSCodeInstalled: Bool
    let onLaunch: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private let launcher = ProjectLauncher()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                workspaceSection
                valuesSection(title: "Apps", values: project.apps, emptyMessage: "No apps saved.")
                valuesSection(title: "URLs", values: project.urls, emptyMessage: "No URLs saved.")
                commandsSection
                noteSection
                metadataSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(project.name)
                    .font(.largeTitle.weight(.semibold))

                if let description = project.projectDescription.nilIfBlank {
                    Text(description)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack {
                Button("Launch", action: onLaunch)
                    .keyboardShortcut(.defaultAction)

                Button("Edit", action: onEdit)

                Button("Delete", role: .destructive, action: onDelete)
            }
        }
    }

    private var workspaceSection: some View {
        GroupBox("Workspace") {
            VStack(alignment: .leading, spacing: 12) {
                detailRow(label: "Folder", value: project.folderPath.nilIfBlank ?? "Not set")

                if project.hasFolder {
                    detailRow(
                        label: "Open folder with",
                        value: launcher.displayName(for: project.folderLaunchMode)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var commandsSection: some View {
        GroupBox("Terminal Commands") {
            if project.terminalCommands.isEmpty {
                Text("No terminal commands saved.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(project.terminalCommands, id: \.self) { command in
                        Text(command)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var noteSection: some View {
        GroupBox("Last Note") {
            Text(project.lastNote.nilIfBlank ?? "No note saved.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(project.lastNote.nilIfBlank == nil ? .secondary : .primary)
                .textSelection(.enabled)
        }
    }

    private var metadataSection: some View {
        GroupBox("Metadata") {
            VStack(alignment: .leading, spacing: 12) {
                detailRow(
                    label: "Created",
                    value: project.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
                detailRow(
                    label: "Updated",
                    value: project.updatedAt.formatted(date: .abbreviated, time: .shortened)
                )
                if let sessionCapturedAt = project.sessionCapturedAt {
                    detailRow(
                        label: "Session Captured",
                        value: sessionCapturedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func valuesSection(title: String, values: [String], emptyMessage: String) -> some View {
        GroupBox(title) {
            if values.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
