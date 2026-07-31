# Changelog

All notable changes to **Gitea Time Tracker** will be documented in this file.

## [1.0.5] - 2026-07-31

### 🐛 Fixed & Improved
- **AFK & Sleep Detection Scoping**: Inactivity and system sleep detection are now strictly scoped to active timers (`state == .running`). When no timer is running, no idle prompts will appear.
- **Monitoring Lifecycle**: `IdleDetector` monitoring starts/stops automatically when timers start, pause, resume, or stop.
- **MenuBar Modal Interactivity**: Converted `IdleConfirmationView` from `.sheet()` to an inline `.overlay(...)` with `NSApp.activate()`. This resolves a macOS `MenuBarExtra` issue where modal sheet buttons were unresponsive to mouse clicks.

## [1.0.4] - 2026-07-31
- Automated GitHub Actions release workflow (`.github/workflows/release.yml`).
- Added framework imports for Xcode 15/16 CI runners.
- Fixed pause/resume time reset bug and added status message auto-clear.
