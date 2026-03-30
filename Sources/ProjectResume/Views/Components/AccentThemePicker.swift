import SwiftUI

struct AccentThemePicker: View {
    @Binding var selectedTheme: AppAccentTheme
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.adaptive(minimum: 52), spacing: 14)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(AppAccentTheme.allCases) { theme in
                Button {
                    selectedTheme = theme
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                selectedTheme == theme
                                    ? Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06)
                                    : Color.clear
                            )
                            .frame(width: 42, height: 42)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.accentColor.opacity(colorScheme == .dark ? 0.98 : 0.92),
                                        theme.accentColor.opacity(colorScheme == .dark ? 0.58 : 0.48)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                            .overlay {
                                Circle()
                                    .stroke(
                                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.42),
                                        lineWidth: 0.8
                                    )
                            }
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                selectedTheme == theme
                                    ? theme.accentColor.opacity(colorScheme == .dark ? 0.75 : 0.55)
                                    : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06),
                                lineWidth: selectedTheme == theme ? 1.4 : 1
                            )
                            .frame(width: 42, height: 42)
                    }
                }
                .buttonStyle(.plain)
                .help(theme.title)
                .accessibilityLabel(Text(theme.title))
            }
        }
    }
}
