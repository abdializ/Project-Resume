# Widget Host Setup

This app is already prepared for widget data and project deep links. The remaining work is to add a real macOS app host and WidgetKit extension in Xcode.

## What Already Exists In The Package

- Shared widget snapshot model:
  - `Sources/ProjectResumeWidgetSupport/WidgetSnapshot.swift`
  - `Sources/ProjectResume/Models/WidgetSnapshot.swift`
- Shared deep-link and bridge helpers:
  - `Sources/ProjectResumeWidgetSupport/WidgetBridge.swift`
  - `Sources/ProjectResume/Models/WidgetBridge.swift`
- Snapshot persistence:
  - `Sources/ProjectResumeWidgetSupport/WidgetSnapshotStore.swift` (read-only, for widget)
  - `Sources/ProjectResume/Persistence/WidgetSnapshotStore.swift` (read/write, for app)
- Shared widget card UI:
  - `Sources/ProjectResumeWidgetSupport/ResumeProjectWidgetCard.swift`
- Accent theme:
  - `Sources/ProjectResumeWidgetSupport/AppAccentTheme.swift`
- Automatic snapshot updates from project storage:
  - `Sources/ProjectResume/Persistence/ProjectStore.swift`
- In-app deep-link handling for opening a project:
  - `Sources/ProjectResume/ProjectResumeApp.swift`
  - `Sources/ProjectResume/Services/AppController.swift`
  - `Sources/ProjectResume/Views/ProjectListView.swift`

## Goal

Create two macOS widgets:

1. **Resume Last Project** — shows the most recently launched project with launch and capture actions
2. **Favorite Projects** — shows starred projects with tap-to-open deep links

Both support small, medium, and large sizes.

## Host App Setup In Xcode

1. Create or migrate to an Xcode macOS app project that hosts the existing package.
2. Add the package as a local package dependency if needed.
3. Keep the current app target as the main executable.

## Add The Widget Target

1. In Xcode, add a new target.
2. Choose `Widget Extension`.
3. Enable macOS support for the widget.
4. Name it `ProjectResumeWidgets`.
5. Copy the files from `WidgetHostTemplates/ProjectResumeWidgets/` into the widget target.

## Add An App Group

1. In Signing & Capabilities, add `App Groups` to both:
   - the main app target
   - the widget extension target
2. Use the group id:
   - `group.app-practice.Project-Resume-Host`
   (or update `WidgetBridge.appGroupIdentifier` in both targets to match your own)
3. Apply entitlements:
   - `WidgetHostTemplates/Config/ProjectResume.entitlements` to the main app target
   - `WidgetHostTemplates/Config/ProjectResumeWidgets.entitlements` to the widget target

After that, the app will automatically start writing widget snapshot data into the shared container.

## Register The URL Scheme

The widgets open the app with URLs such as:

```text
projectresume://open-project?id=<uuid>
projectresume://capture-session
```

Add `projectresume` as a custom URL scheme in the main app target Info settings.

After that, the existing `.onOpenURL` app flow will handle the route and launch the requested project or trigger session capture.

## Widget Data Flow

The main app writes:
- `widget-snapshot.json`

The widget reads:
- the same file from the shared app group container

The snapshot includes:
- accent theme
- last project snapshot (id, name, icon, app/link/command counts, folder name, note preview, dates, favorite status)
- up to 5 favorite project snapshots

## Preview Strategy

Use:
- `WidgetSnapshot.preview`
- `WidgetProjectSnapshot.preview`

for WidgetKit previews so the design can be built before the live target is fully wired. The preview data includes realistic project names, icons, and resource counts.

## Verification Checklist

- App writes `widget-snapshot.json` to the shared app group container
- Both widgets read the snapshot and render in all three sizes
- Resume Last Project shows icon, name, notes, resources, and action pills
- Favorite Projects shows starred projects with icons and deep links
- Clicking the launch pill opens the app and launches the correct project
- Clicking the capture pill triggers session capture
- Light and dark mode render correctly with accent theme colors
- Liquid glass effect renders on macOS 26+
