# Gitea Time Tracker

A native macOS menu bar app for tracking time on Gitea and Forgejo issues.

## Features

- **Menu bar timer**: Start, pause, and log time entries directly to Gitea issues.
- **Time adjustments**: Click the timer to set time via steppers or quick duration presets (+15m, +30m, +1h, +2h).
- **Issue & PR browser**: Search and filter issues assigned to you or across your repositories.
- **Auto-detected repos**: Repo dropdown includes personal, organization, and assigned issue repositories.
- **Favorites & recents**: Pin frequently used issues for quick access.
- **AFK / Sleep detection**: Detects system sleep and inactivity with options to adjust logged time.
- **Offline queue**: Automatically queues time entries when offline and syncs when reconnected.
- **Encrypted credentials**: Stores your Personal Access Token encrypted locally using CryptoKit (AES-256-GCM).
- **Autostart**: Optional launch-at-login setting via macOS ServiceManagement.

## Required Gitea Token Scopes

When creating a Personal Access Token in Gitea (**User Settings** > **Applications**), enable the following permissions:

- `issue` (Read & Write) - Required for loading issues and logging time.
- `repository` (Read) - Required for fetching the repository list.
- `user` (Read) - Required for identifying your account in the assigned filter.

## Building from Source

### Requirements
- macOS 14.0 (Sonoma) or newer
- Swift 6 / Xcode 15+

```bash
git clone https://github.com/Sneeex/gitea-time-tracker.git
cd gitea-time-tracker

# Build debug
swift build

# Build release
swift build -c release
```

To run locally:
```bash
swift run GiteaTimeTracker
```

## License

MIT
