import AppKit
import SwiftUI

struct ApplicationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    let applications: [DiscoveredApplication]
    let onSelect: (DiscoveredApplication) -> Void

    private var filteredApplications: [DiscoveredApplication] {
        let normalizedQuery = query.trimmed
        guard !normalizedQuery.isEmpty else {
            return applications
        }

        return applications.filter { app in
            app.title.localizedCaseInsensitiveContains(normalizedQuery)
                || app.path.localizedCaseInsensitiveContains(normalizedQuery)
                || (app.bundleIdentifier?.localizedCaseInsensitiveContains(normalizedQuery) == true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose App")
                    .font(.system(size: 24, weight: .semibold))

                Text("Pick an app by name. Click once to add it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search apps", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
            )

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredApplications) { app in
                        Button {
                            onSelect(app)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(nsImage: ApplicationCatalog.icon(for: app.path, size: 32))
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(app.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)

                                        if app.isRunning {
                                            Text("Running")
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
                                        }
                                    }

                                    Text(app.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(nsColor: .windowBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Text("\(filteredApplications.count) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 620, maxWidth: 700, minHeight: 500, idealHeight: 560, maxHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
