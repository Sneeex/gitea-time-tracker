# Changelog

All notable changes to **Gitea Time Tracker** will be documented in this file.

## [1.0.20] - 2026-09-19

### ✨ Added & Improved
- **Command+M Shortcut**: Added `⌘M` (`Command + M`) keyboard shortcut in the Quick Switcher alongside `⌥M` to open the app tray menu seamlessly even while typing in the search bar.
- **Clean Quick Switcher Footer**: Removed the menu button from the footer bar to keep the footer clean and focused on keyboard navigation hints.

### 🐛 Fixed
- **Update Checker Safety**: Hardened `UpdateChecker` by using `NSApplication.shared.activate` to prevent potential nil unwrapping in headless or background contexts.

## [1.0.19] - 2026-09-19

### ✨ Added
- **Open App Tray from Quick Switcher**: Added dedicated buttons in the Quick Switcher search header and footer, as well as an `⌥M` keyboard shortcut, to seamlessly dismiss the Quick Switcher and open the menu bar app tray popup.

## [1.0.18] - 2026-08-30

### 🐛 Fixed
- **Quick Switcher Sync**: Resolved an issue where Quick Switcher issues were not synchronized with the Taskbar app (Issue #359).

### ♻️ Refactored
- **Data Provider**: Extracted issue data handling into a central `IssueStore` (Single Source of Truth) to prevent state discrepancies.

## [1.0.17] - 2026-08-26

### 🐛 Fixed
- **Build Error**: Fixed a syntax error introduced in v1.0.16 that caused the CI build to fail.

## [1.0.16] - 2026-08-26

### 🐛 Fixed
- **Quick Switcher Overlay Robustness**: Completely overhauled the Quick Switcher window architecture. It now uses a dedicated `NSPanel` rather than a standard SwiftUI `Window`, which guarantees it successfully renders on top of all macOS fullscreen applications and spaces.

## [1.0.15] - 2026-08-26

### 🐛 Fixed
- **Quick Switcher Full-Screen Support**: Elevated the Quick Switcher window level even higher (`.screenSaver`) to guarantee it appears on top of all macOS full-screen applications.
- **Quick Switcher Active Issue**: Clicking the trash icon in the Quick Switcher now correctly dismisses the active issue and hides the timer header.

## [1.0.14] - 2026-08-26

### 🐛 Fixed
- **Quick Switcher Full-Screen Support**: The Quick Switcher window now correctly appears on top of full-screen applications by adopting the `.popUpMenu` window level.
- **Quick Switcher Keyboard Navigation**: Fixed an issue where up and down arrow key navigation didn't work. It now uses native SwiftUI keyboard shortcuts.
- **Quick Switcher Sorting**: The list of assigned issues now automatically prioritizes the most recently tracked issues at the very top, followed by the rest sorted by ID, making it much more logical to select recent work.

## [1.0.13] - 2026-08-05

### 🎨 Style & UI
- **Native Update Badge Design**: Refined update badges and icons across the App, Menu Bar, and Settings to use clean native macOS system icons (`arrow.down.app.fill` & `arrow.down.circle.fill`) with subtle accent tinting.

## [1.0.12] - 2026-08-05

### ✨ Added
- **Global Hotkey Command Palette**: Introduced system-wide global hotkey support (`GlobalHotkeyService`) to launch the Quick Switcher Command Palette instantly from anywhere on macOS.
- **Spotlight-Style Quick Switcher Window**: Brand-new Spotlight-inspired floating command palette featuring instant fuzzy search across assigned Gitea Issues & PRs, keyboard navigation (`↑↓`, `Enter`, `Esc`), borderless transparent titlebar, and auto-centering on the active monitor.
- **Automated Git Branch & Commit Matching**: Added `GitWatcherService` to monitor local git repository branches and automatically map active git branches/commit keys to corresponding Gitea Issues and Pull Requests.
- **Local macOS Notification System**: Integrated `NotificationService` to deliver native macOS notifications for timer state changes, branch switches, and automated tracking alerts.
- **Skeleton Shimmer Loading States**: Added smooth shimmer animated loading placeholders (`QuickSwitcherSkeletonView` and `IssuePickerSkeletonView`) for non-blocking UI during initial Gitea API fetches.

### 🎨 Style & UI
- **Window Auto-Close on Focus Loss**: Quick Switcher window automatically closes when losing focus or clicking outside.
- **Pixel-Perfect Alignment**: Adjusted horizontal padding to 12pt across headers, cards, and footers, and relocated hidden shortcut buttons to eliminate trailing spacing.

## [1.0.10] - 2026-08-03

### ✨ Improved
- **Full Changelog Comparison Link**: Release workflow now automatically computes the previous tag and embeds the direct GitHub comparison link (`**Full Changelog**: https://github.com/Sneeex/gitea-time-tracker/compare/PREV_TAG...NEW_TAG`) at the end of every release.

## [1.0.9] - 2026-08-03

### 🎨 Style
- **Simplified Release Title**: GitHub Releases are now named directly as `v1.0.X` instead of `Gitea Time Tracker v1.0.X`.

## [1.0.8] - 2026-08-03

### ✨ Improved
- **Automatic GitHub Release Notes**: GitHub Release workflow (`release.yml`) now automatically parses `CHANGELOG.md` for each release tag and embeds the full changelog directly in the GitHub Release notes forever.

## [1.0.7] - 2026-08-03

### 🐛 Fixed
- **App Version Display**: Fixed GitHub Actions release workflow (`release.yml`) which was hardcoding `1.0.0` into `Info.plist`. Bundle version now dynamically matches the release tag.

## [1.0.6] - 2026-08-03

### ✨ Added
- **Dismiss Active Issue/PR**: Added ability to deselect/dismiss the currently active issue or PR from the Stoppuhr banner and from the Issues list.

## [1.0.5] - 2026-07-31

### ✨ Added
- **Automatic GitHub Update Checker**: Automatically checks for new releases on GitHub upon startup and presents an interactive update dialog overlay when a new version is available. Includes manual check button and auto-check toggle in Settings.

### 🐛 Fixed & Improved
- **AFK & Sleep Detection Scoping**: Inactivity and system sleep detection are now strictly scoped to active timers (`state == .running`). When no timer is running, no idle prompts will appear.
- **Monitoring Lifecycle**: `IdleDetector` monitoring starts/stops automatically when timers start, pause, resume, or stop.
- **MenuBar Modal Interactivity**: Converted `IdleConfirmationView` from `.sheet()` to an inline `.overlay(...)` with `NSApp.activate()`. This resolves a macOS `MenuBarExtra` issue where modal sheet buttons were unresponsive to mouse clicks.

## [1.0.4] - 2026-07-31
- Automated GitHub Actions release workflow (`.github/workflows/release.yml`).
- Added framework imports for Xcode 15/16 CI runners.
- Fixed pause/resume time reset bug and added status message auto-clear.
