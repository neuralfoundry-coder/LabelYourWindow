# CLAUDE.md - Agent Guide for LabelYourWindow

## Project Overview

macOS (Apple Silicon) menu bar app that displays translucent label overlays on windows.
Built with Swift, SwiftUI + AppKit, targeting macOS 15.0+.

## Build & Run

```sh
# Generate Xcode project (required after project.yml changes)
xcodegen generate

# Build
xcodebuild -project LabelYourWindow.xcodeproj -scheme LabelYourWindow -configuration Debug -arch arm64 build

# Release build
xcodebuild -project LabelYourWindow.xcodeproj -scheme LabelYourWindow -configuration Release -arch arm64 build

# Run (requires Accessibility permission)
open ~/Library/Developer/Xcode/DerivedData/LabelYourWindow-*/Build/Products/Debug/LabelYourWindow.app
```

## Project Structure

```
LabelYourWindow/
├── App/           # Entry point, AppDelegate, pipeline
├── Core/          # WindowObserver, LabelManager, OverlayManager, SettingsManager
├── Models/        # WindowInfo, LabelRule, LabelAssignment
├── Views/
│   ├── Overlay/   # OverlayWindow (NSPanel), LabelOverlayView (SwiftUI)
│   ├── MenuBar/   # MenuBarView (popover UI)
│   └── Settings/  # SettingsView, General/Appearance/Rules tabs
├── Utilities/     # WindowTitleParser
└── Resources/     # Info.plist, entitlements, assets
```

## Feature Implementation Workflow

All feature requests MUST follow this process:

### 1. SRS Analysis

- Read the current SRS at `docs/SRS_YYYYMMDD.md` (use the latest dated file)
- Determine if the requested feature:
  - Already exists (→ inform user, skip or refine)
  - Conflicts with existing requirements (→ discuss with user)
  - Is a new feature (→ proceed to step 2)

### 2. Implementation Decision

- Assess scope and impact on existing architecture
- Check if the feature touches Core components (WindowObserver, LabelManager, OverlayManager) — these require extra care
- If the change is large or ambiguous, ask the user for clarification before proceeding

### 3. Implementation

- Follow existing code patterns and conventions:
  - `@Observable` classes for stateful managers
  - `UserDefaults` for settings persistence
  - `os.log` with subsystem `com.labelyourwindow.app` for logging
  - NSPanel for overlay windows, NSHostingView to bridge SwiftUI
  - CG→NS coordinate conversion for window positioning
- Do NOT add unnecessary abstractions, comments, or unrelated changes
- Run `xcodebuild` to verify the build succeeds after changes

### 4. Verification

- Build the project: `xcodebuild -scheme LabelYourWindow -configuration Debug -arch arm64 build`
- Launch the app and test the feature
- Check logs: `/usr/bin/log show --predicate 'subsystem == "com.labelyourwindow.app"' --last 30s --info`
- Verify no regressions in existing features

### 5. SRS & README Update

- If the feature adds or changes a functional requirement:
  - Create a new SRS file: `docs/SRS_YYYYMMDD.md` (today's date)
  - Copy the latest SRS, add/update the relevant FR entries
  - Update the revision history table
- If the feature is user-facing:
  - Update `README.md` (features list, usage table, or settings section)

## Key Technical Notes

- **Accessibility API**: Requires user permission. App polls every 2s until granted. AXObserver callbacks are C function pointers — use `Unmanaged.passUnretained` pattern.
- **Coordinate systems**: AX/CG uses top-left origin, NS uses bottom-left. Conversion: `nsY = mainScreenHeight - cgY - windowHeight`.
- **Code signing**: Uses Apple Development certificate for stable TCC permissions across rebuilds. Defined in `project.yml`.
- **CGWindowList fallback**: Some apps (Safari, Chrome) may not respond to AX focused window queries. Fallback reads window info from CGWindowList (requires Screen Recording permission for full access).
- **Overlay windows**: `NSPanel` with `.nonactivatingPanel` + `canBecomeKey = false` to never steal focus.

## Conventions

- Commit messages: imperative mood, concise summary
- No documentation files unless explicitly requested
- No emoji in code or commits unless requested
- Korean language for user-facing communication when the user writes in Korean
