import AppKit
import SwiftUI

struct EditableStringListSection: View {
    @Environment(\.colorScheme) private var colorScheme

    enum RowStyle {
        case plain
        case application
    }

    let title: String
    let subtitle: String?
    let prompt: String
    let emptyMessage: String
    let addLabel: String
    let browseLabel: String?
    let rowStyle: RowStyle
    let accentColor: Color
    let darkSurfaceColor: Color
    @Binding var items: [String]
    var onBrowse: (() -> String?)?
    var onBrowseAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(items.isEmpty ? "No entries yet." : "\(items.count) saved")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(addLabel) {
                        items.append("")
                    }
                    .buttonStyle(.bordered)

                    if let onBrowse {
                        Button(browseLabel ?? "Browse") {
                            if let onBrowseAction {
                                onBrowseAction()
                            } else if let value = onBrowse() {
                                items.append(value)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if items.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                switch rowStyle {
                case .plain:
                    VStack(spacing: 8) {
                        ForEach(Array(items.indices), id: \.self) { index in
                            HStack(alignment: .center, spacing: 12) {
                                TextField(prompt, text: binding(for: index))
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                            .background(Color(nsColor: .textBackgroundColor).cornerRadius(6))
                                    )

                                Button {
                                    items.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark")
                                        .fontWeight(.medium)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.tertiary)
                                .frame(width: 24)
                            }
                        }
                    }
                case .application:
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(Array(items.indices), id: \.self) { index in
                            applicationField(for: index)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { items[index] },
            set: { items[index] = $0 }
        )
    }

    private func applicationField(for index: Int) -> some View {
        let metadata = applicationMetadata(for: items[index])

        return HStack(alignment: .top, spacing: 12) {
            Image(nsImage: metadata.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(metadata.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("Reopens with this project")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 8)

            Button {
                items.remove(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(applicationRowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(applicationRowStroke, lineWidth: 1)
                )
        )
    }

    private func applicationMetadata(for entry: String) -> (title: String, icon: NSImage) {
        (
            ApplicationCatalog.displayName(for: entry),
            ApplicationCatalog.icon(for: entry, size: 32)
        )
    }

    private var applicationRowFill: Color {
        colorScheme == .dark
            ? darkSurfaceColor.opacity(0.92)
            : accentColor.opacity(0.08)
    }

    private var applicationRowStroke: Color {
        colorScheme == .dark
            ? accentColor.opacity(0.24)
            : accentColor.opacity(0.14)
    }
}
