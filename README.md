# ⏱️ Gitea Time Tracker (macOS Menu Bar App)

A native, lightweight, and modern **macOS Menu Bar Application** for effortless Gitea & Forgejo issue time tracking.

Built with **Swift 6 & SwiftUI**, designed to sit cleanly in your macOS Status Bar.

---

## 🌟 Key Features

- **⏱️ Interactive Timer & Stepper**: Track time live or adjust hours/minutes via a modern popover stepper or quick preset duration chips (`+15m`, `+30m`, `+1h`, `+2h`).
- **📌 Issue & Pull Request Selector**: Search, filter, and assign active issues or PRs directly from your Gitea repositories.
- **🏷️ Smart Repository Dropdown**: Automatically detects assigned issues across all your personal and organization repositories.
- **⭐ Favorites & Recents**: Pin your most frequently accessed issues for one-click access.
- **🔌 Offline Resiliency & Queueing**: Erroneous or offline time logs are automatically queued locally and re-synced once back online.
- **🌙 AFK & Sleep Detection**: Automatically detects Mac system sleep or user inactivity and prompts options to keep or deduct idle time.
- **🔐 Hardware Encrypted Token Storage**: PAT Tokens are encrypted using Apple's `CryptoKit` AES-256-GCM framework – zero annoying keychain password popups.
- **⚡ 1-Click Autostart**: Optional launch-at-login integration via macOS `ServiceManagement`.

---

## 🔐 Required Gitea API Token Permissions

When creating a **Personal Access Token (PAT)** in your Gitea instance (`User Settings ➔ Applications ➔ Generate New Token`), ensure the following scopes are enabled:

| Scope | Permission Level | Purpose |
|---|---|---|
| **`issue`** | **Read & Write** | Fetch assigned issues & post logged time entries (`POST /issues/{index}/times`) |
| **`repository`** | **Read** | List available repositories in the repository selector dropdown |
| **`user`** | **Read** | Retrieve authenticated username for the `@assigned` filter |

---

## 🛠️ Build & Installation

### Requirements
- macOS 14.0 (Sonoma) or newer
- Xcode 15+ or Swift 6 Command Line Tools (for building from source)

### Building from Source

```bash
# Clone the repository
git clone https://github.com/Sneeex/gitea-time-tracker.git
cd gitea-time-tracker

# Build debug executable
swift build

# Build production release executable
swift build -c release
```

### Running Locally

```bash
swift run GiteaTimeTracker
```

---

## 📄 License

Distributed under the MIT License.
