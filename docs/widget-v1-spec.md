# Project Resume Widgets

## Goal

Build widgets that feel:

- minimal but information-rich
- beautiful and worth showing on the desktop
- glanceable with clear visual hierarchy
- local-first
- instantly useful — a reason to use Project Resume

The guiding rule:

> Glance -> decide -> resume

## Widgets

### 1. Resume Last Project

The primary widget. The fastest expression of the product promise.

### 2. Favorite Projects

Quick access to starred projects. Surfaces the projects you care about most.

## Sizes

All widgets support three sizes.

### Small (170 x 170)

**Resume Last Project:**
- Accent-colored project icon (rounded square)
- Relative timestamp
- Project name (up to 2 lines)
- Color-coded resource chips (apps, links, commands)
- Compact launch pill

**Favorite Projects:**
- Star header with count
- Lead favorite with icon, name, and resource chips
- Tap opens project

### Medium (360 x 170)

**Resume Last Project:**
- Project icon + name + resource chips in header row
- Relative timestamp
- "NEXT" label with note preview (2 lines)
- Capture + Launch action pills

**Favorite Projects:**
- Star header with project count
- Up to 3 favorite rows with icon, name, resource chips, and arrow
- Each row is a deep link

### Large (360 x 376)

**Resume Last Project:**
- Project icon + name + timestamp header
- "NEXT" label with note preview (up to 3 lines)
- Detailed resource list: applications, links, terminal commands, folder name
- Capture + Launch action pills

**Favorite Projects:**
- Star header with project count
- Up to 5 favorite rows with icon, name, note preview, and arrow
- Each row is a deep link

## Design Language

- Outer shell uses liquid glass on macOS 26+ with subtle gradient tint
- Fallback uses themed canvas with accent-colored overlay
- Content stays matte and legible — no text on glass
- Typography-first hierarchy with rounded design for labels
- Accent-colored project icon in a rounded square
- Color-coded resource chips with SF Symbols (apps, links, terminal)
- Almost no hard borders — subtle strokes and shadows
- One accent color from the selected theme throughout
- Refined action pills with gradient fills

## Data Model

`WidgetProjectSnapshot` includes:
- `id` — project UUID for deep links
- `name` — project name
- `iconSymbol` — SF Symbol name (resolved from project content)
- `appCount` — number of applications
- `linkCount` — number of URLs
- `commandCount` — number of terminal commands
- `folderName` — last path component of project folder
- `notePreview` — first meaningful line of notes (max 96 chars)
- `updatedAt` — last edit date
- `lastLaunchedAt` — last launch date
- `isFavorite` — starred status

`WidgetSnapshot` includes:
- `generatedAt` — snapshot creation time
- `accentTheme` — user's selected theme
- `lastProject` — most recently launched project snapshot
- `favoriteProjects` — up to 5 starred project snapshots

## Interaction

- **Resume Last Project**: Tap launch pill to open via `WidgetBridge.projectURL(for:)`
- **Resume Last Project**: Tap capture pill to trigger session capture via `WidgetBridge.captureURL()`
- **Favorite Projects**: Tap any row to open that project via deep link

## Widget Extension Files

- `ProjectResumeWidgetsBundle.swift` — registers both widgets
- `ResumeLastProjectWidget.swift` — timeline provider + view for resume widget
- `FavoriteProjectsWidget.swift` — timeline provider + view for favorites widget

## What Not To Include

- Live session stats or timers
- Complex controls or editing
- Constant animation or shimmer
- More than 5 favorites in any size
- Full notes or long text

## Motion

- Subtle press/lift on interaction (system default)
- No shimmer, no constant animation
- Glass effect provides the only ambient visual motion

## Theme Behavior

- Light mode: White-based shell with subtle accent tint gradient
- Dark mode: Deep themed canvas matching the main app, stronger accent tint
- Project icon and launch pill use the resolved theme accent
- Resource chip icons use accent at reduced opacity
