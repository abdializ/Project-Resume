import SwiftUI

struct GuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Guide")
                        .font(.system(size: 30, weight: .semibold))

                    Text("A quick reference for using Project Resume day to day.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                guideCard(title: "Shortcuts First", subtitle: "The fastest actions in the app") {
                    shortcutRow("Quick Access", value: "Your custom shortcut from Settings")
                    shortcutRow("Toggle Sidebar", value: "⌘B")
                    shortcutRow("Launch project 1", value: "^⌥1")
                    shortcutRow("Launch project 2", value: "^⌥2")
                    shortcutRow("Launch project 3", value: "^⌥3")
                    shortcutRow("Launch project 4", value: "^⌥4")
                    shortcutRow("Resume Last Project", value: "⇧⌘R")
                }

                guideCard(title: "How Project 1, 2, 3, and 4 Work", subtitle: "The fixed launch ranking") {
                    guideLine("The fixed shortcuts ^⌥1 through ^⌥4 launch the top four projects in this order.")
                    guideLine("1. Favorites first.")
                    guideLine("2. Then recent non-favorite projects.")
                    guideLine("3. If there are still open slots, the app fills them with the next remaining projects.")
                    guideLine("Favorites are ranked ahead of non-favorites. Recent launches push projects upward inside their group.")
                    guideLine("The menu bar shows the current shortcut slot next to any project that is mapped right now.")
                }

                guideCard(title: "How Projects Work", subtitle: "What gets saved") {
                    guideLine("A project saves lightweight references only: a folder, apps, links, commands, and a short note.")
                    guideLine("Nothing is copied. Files, browser data, and recordings stay where they already are.")
                    guideLine("Use the main project folder if you want one-click reopening in Finder or your IDE.")
                }

                guideCard(title: "Fastest Workflow", subtitle: "The intended daily loop") {
                    guideLine("1. Create a project once, or capture your current session.")
                    guideLine("2. Add the apps and links you reopen often.")
                    guideLine("3. Launch the project later from the app, quick access, menu bar, or fixed shortcuts.")
                    guideLine("4. Pin favorites so they stay at the top and on the fixed launch shortcuts.")
                }

                guideCard(title: "Good Defaults", subtitle: "Simple ways to keep it useful") {
                    guideLine("Keep each project small: one folder, a few apps, a few links, and one note.")
                    guideLine("Use favorites for your most important workspaces.")
                    guideLine("Use session capture when you are already in the middle of work and want a quick snapshot.")
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 720, minHeight: 560)
    }

    private func guideCard<Content: View>(
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

    private func shortcutRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(width: 180, alignment: .leading)

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func guideLine(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
