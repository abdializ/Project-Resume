# Widget Host Templates

These files are ready to be added to a real Xcode macOS app host and WidgetKit extension.

## Files

- `ProjectResumeWidgets/ProjectResumeWidgetsBundle.swift`
- `ProjectResumeWidgets/ResumeLastProjectWidget.swift`
- `ProjectResumeWidgets/FavoriteProjectsWidget.swift`
- `Config/ProjectResume.entitlements`
- `Config/ProjectResumeWidgets.entitlements`

## Widgets

### Resume Last Project
Quickly jump back into your most recently launched project. Shows the project icon, name, notes, resource breakdown, and launch/capture actions. Available in small, medium, and large.

### Favorite Projects
Quick access to your starred projects from the desktop. Shows favorite projects with icons, names, and tap-to-open deep links. Available in small, medium, and large.

## Use In Xcode

1. Create or open the Xcode macOS app host project.
2. Add a `Widget Extension` target.
3. Add the local `ProjectResume` package to the project.
4. Add the `ProjectResumeWidgetSupport` library product to the widget target.
5. Add the files under `ProjectResumeWidgets/` to the widget target.
6. Apply:
   - `Config/ProjectResume.entitlements` to the main app target
   - `Config/ProjectResumeWidgets.entitlements` to the widget target
7. Add the same App Group id to both targets.
8. Register the `projectresume` custom URL scheme on the app target.
9. Set the real app group in `Sources/ProjectResume/Models/WidgetBridge.swift`.

## Expected Result

The widgets will:
- Read the shared widget snapshot from the app group container
- Render beautiful themed cards with project icons and resource breakdowns
- Deep-link into the app to open or capture projects
- Support light and dark mode with accent theme colors
- Use liquid glass effects on macOS 26+
