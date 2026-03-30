# Project Resume

Project Resume is a lightweight macOS SwiftUI menu bar app for saving project workspaces and reopening them later with one click.

It can also generate a draft project from the current session by tracking frontmost app time while the app is running and capturing open Safari or Chrome tabs on demand.

It also includes a centered quick-access panel that can be toggled from anywhere with `Cmd+Option+Space`.

The app now includes a native Settings window for quick-access shortcut recording and behavior preferences.

## What it stores

- Project name
- Optional description
- Local folder path
- App names, bundle identifiers, or `.app` paths
- Website URLs
- Terminal command strings
- A short last note
- An optional session capture timestamp

The app stores only lightweight references in a local JSON file under `~/Library/Application Support/ProjectResume/projects.json`.

## Project structure

```text
ProjectResume/
├── Package.swift
├── README.md
└── Sources/
    └── ProjectResume/
        ├── ProjectResumeApp.swift
        ├── Models/
        │   └── Project.swift
        ├── Persistence/
        │   ├── ProjectStore.swift
        │   └── SampleProjects.swift
        ├── Resources/
        │   └── SeedProjects.json
        ├── Services/
        │   ├── ProjectLauncher.swift
        │   └── TerminalCommandRunner.swift
        ├── Utilities/
        │   ├── OpenPanelService.swift
        │   └── String+Sanitizing.swift
        ├── ViewModels/
        │   └── ProjectDraft.swift
        └── Views/
            ├── Components/
            │   ├── EditableStringListSection.swift
            │   └── EmptyStateView.swift
            ├── MenuBarProjectsView.swift
            ├── ProjectDetailView.swift
            ├── ProjectFormView.swift
            ├── ProjectListView.swift
            └── ProjectRowView.swift
```

## MVP behavior

- The main window uses a native `NavigationSplitView`.
- The menu bar dropdown lists saved projects and launches them immediately.
- A floating quick-access panel can be toggled globally with `Cmd+Option+Space`.
- A native Settings window is available for recording the global shortcut and changing capture preferences.
- The app can generate a project draft from the current session with `Capture Session`.
- The main window is a lightweight dashboard with live session stats, saved project cards, and workspace actions.
- Folder launches can target Finder or VS Code.
- App launches use `NSWorkspace`.
- URLs open in the default browser with `NSWorkspace`.
- Terminal commands run in Terminal through AppleScript.
- Session capture tracks app focus time only while Project Resume is open.
- Safari and Google Chrome links are captured on demand through AppleScript.
- Invalid paths and missing apps are surfaced as non-fatal warnings.

## Run locally in Xcode

1. Install full Xcode 15 or newer and make sure the active developer directory points to Xcode, not Command Line Tools.
2. Open `Package.swift` in Xcode.
3. Let Xcode resolve the local package and create the `ProjectResume` run target.
4. Select the `ProjectResume` scheme and run it on **My Mac**.
5. On first launch, macOS may ask for Automation permission so the app can send commands to Terminal and read Safari or Chrome tabs during session capture.

## Build a beta app bundle

You can package the current Swift package into a standalone beta app without converting it to a full `.xcodeproj`.

1. From Terminal, go to the project root.
2. Run `./scripts/build_beta_app.sh`
3. The script will create:
   - `dist/Project Resume Beta.app`
   - `dist/Project-Resume-Beta.zip`
   - `dist/appcast.xml`
4. Move the `.app` into `/Applications` if you want it installed like a normal beta build.
5. If your project lives in an iCloud-backed `Documents` folder, prefer installing from the `.zip` artifact. macOS can attach Finder metadata to the local `.app` copy in-place, while the zipped build stays clean for sharing and extraction.

The beta bundle uses:

- bundle identifier: `com.projectresume.beta`
- display name: `Project Resume Beta`
- an `.icns` app icon generated from the existing icon set
- ad hoc signing so the bundle behaves like a normal local app build
- a Sparkle appcast feed for in-app update checks

If you want a custom version number, run:

```bash
PROJECT_RESUME_VERSION=0.2.0 PROJECT_RESUME_BUILD=5 ./scripts/build_beta_app.sh
```

## Beta updates

The beta app now uses Sparkle for update checks.

1. Build a new beta from the dev workspace with `./scripts/build_beta_app.sh`
2. Open the installed beta app
3. Click `Check for Updates`
4. Sparkle will present the update if the appcast contains a newer build

The packaging script creates and signs the update feed locally:

- `dist/appcast.xml`
- `dist/Project-Resume-Beta.zip`

The Sparkle signing keys are generated once into:

- `.sparkle/`

You can change the feed folder in Settings under `Beta Updates`.

## Quick Access Shortcut

- Press your recorded global shortcut from anywhere on macOS to open the mini quick-access panel in the center of the screen.
- Type to filter projects, then click a project to launch it immediately.
- The same shortcut is also available from the app menu as `Project Resume > Toggle Quick Access`.
- You can record a custom shortcut from the Settings window.

## Session-generated projects

1. Run the app and keep it open in the menu bar while you work.
2. Open the apps and browser tabs you want associated with the current task.
3. Click `Capture Session` from the main window toolbar or the menu bar dropdown.
4. Review the generated draft, add the folder path or commands you want, and save it.

The generated draft uses:

- running and recently focused macOS apps observed while the app is open
- current Safari tabs
- current Google Chrome tabs
- a timestamped note summarizing the captured session

## Notes

- Seed data comes from `Sources/ProjectResume/Resources/SeedProjects.json`.
- The sample folder paths are placeholders and can be edited in the app.
- Browser URLs are not stored automatically in the background; they are imported only when `Capture Session` is used.
- No cloud sync, analytics, indexing, or file duplication is included.
