# Changelog

All notable changes to **Gitea Time Tracker** will be documented in this file.

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
