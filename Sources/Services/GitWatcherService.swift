import Foundation
import AppKit
import Combine

@MainActor
public final class GitWatcherService: ObservableObject {
    public static let shared = GitWatcherService()

    @Published public var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    @Published public var watchedFolderPaths: [String] = [] {
        didSet {
            saveWatchedFolders()
        }
    }

    @Published public private(set) var lastDetectedBranch: String?
    @Published public private(set) var lastMatchedIssue: GiteaIssue?

    private var timer: Timer?
    private var lastKnownBranches: [String: String] = [:] // [FolderPath: BranchName]

    private let enabledKey = "gitea_git_matching_enabled"
    private let foldersKey = "gitea_git_watched_folders"

    private init() {
        loadPreferences()
        if isEnabled {
            startMonitoring()
        }
    }

    public func addFolder(_ path: String) {
        guard !watchedFolderPaths.contains(path) else { return }
        watchedFolderPaths.append(path)
        checkBranchChanges()
    }

    public func removeFolder(_ path: String) {
        watchedFolderPaths.removeAll { $0 == path }
        lastKnownBranches.removeValue(forKey: path)
    }

    public func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkBranchChanges()
            }
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func checkBranchChanges() {
        guard isEnabled else { return }

        for folderPath in watchedFolderPaths {
            guard let currentBranch = getCurrentBranch(for: folderPath), !currentBranch.isEmpty else {
                continue
            }

            let previousBranch = lastKnownBranches[folderPath]
            if currentBranch != previousBranch {
                lastKnownBranches[folderPath] = currentBranch
                self.lastDetectedBranch = currentBranch

                // Only process if branch actually changed (not on first run initialization if previous was nil)
                if previousBranch != nil {
                    handleBranchChange(branchName: currentBranch)
                }
            }
        }
    }

    private func getCurrentBranch(for folderPath: String) -> String? {
        let headPath = (folderPath as NSString).appendingPathComponent(".git/HEAD")
        guard FileManager.default.fileExists(atPath: headPath) else {
            return nil
        }

        do {
            let content = try String(contentsOfFile: headPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            if content.hasPrefix("ref: refs/heads/") {
                return String(content.dropFirst("ref: refs/heads/".count))
            } else {
                // Detached HEAD or commit hash
                return nil
            }
        } catch {
            return nil
        }
    }

    private func handleBranchChange(branchName: String) {
        guard let issueIndex = extractIssueNumber(from: branchName) else { return }

        // If timer is already running for this issue, do not notify
        if let active = TimerService.shared.activeIssue, active.number == issueIndex, TimerService.shared.state == .running {
            return
        }

        Task {
            // First check recent issues cache
            var targetIssue = TimerService.shared.recentIssues.first(where: { $0.number == issueIndex })

            // If not found in recents, fetch assigned issues from API
            if targetIssue == nil, let assigned = try? await GiteaAPIService.shared.fetchAssignedIssues() {
                targetIssue = assigned.first(where: { $0.number == issueIndex })
            }

            if let issue = targetIssue {
                self.lastMatchedIssue = issue
                NotificationService.shared.sendGitBranchNotification(issue: issue, branchName: branchName)
            }
        }
    }

    /// Extracts issue index from branch names such as:
    /// - `feature/#42-auth-bug` -> 42
    /// - `feature/42-auth-bug` -> 42
    /// - `issue-42-fix` -> 42
    /// - `fix/42` -> 42
    public func extractIssueNumber(from branchName: String) -> Int? {
        // Skip release branches or semver branches like release/v1.0.0 or v2.1.0
        let lower = branchName.lowercased()
        if lower.contains("/v") || lower.hasPrefix("v") && lower.contains(".") {
            return nil
        }

        let patterns = [
            "#(\\d+)",
            "(?:issue|bug|fix|feat|feature)[/_-]?(\\d+)",
            "^(\\d+)[-_]",
            "[-_](\\d+)[-_]",
            "/(\\d+)$"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: branchName, options: [], range: NSRange(location: 0, length: branchName.utf16.count)) {
                if match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: branchName),
                   let number = Int(branchName[range]) {
                    return number
                }
            }
        }
        return nil
    }

    private func saveWatchedFolders() {
        UserDefaults.standard.set(watchedFolderPaths, forKey: foldersKey)
    }

    private func loadPreferences() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
        if let savedFolders = UserDefaults.standard.stringArray(forKey: foldersKey) {
            self.watchedFolderPaths = savedFolders
        }
    }
}
