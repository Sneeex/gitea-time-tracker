import Foundation
import Combine
import AppKit

public enum TimerState: String, Sendable {
    case stopped
    case running
    case paused
}

@MainActor
public final class TimerService: ObservableObject {
    public static let shared = TimerService()

    @Published public private(set) var state: TimerState = .stopped
    @Published public var activeIssue: GiteaIssue?
    @Published public private(set) var elapsedSeconds: Int = 0
    @Published public private(set) var statusMessage: String?
    @Published public var isSubmitting: Bool = false

    @Published public private(set) var recentIssues: [GiteaIssue] = []
    @Published public private(set) var favoriteIssueIDs: Set<Int> = []

    private var timer: Timer?
    private var statusMessageTask: Task<Void, Never>?
    private let recentIssuesKey = "gitea_recent_issues"
    private let favoriteIssuesKey = "gitea_favorite_issue_ids"

    private init() {
        loadSavedPreferences()
    }

    // MARK: - Status Message Handling (Auto-clears after duration)
    public func setStatusMessage(_ message: String?, autoClearSeconds: Double = 4.0) {
        statusMessageTask?.cancel()
        self.statusMessage = message

        if message != nil {
            statusMessageTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(autoClearSeconds * 1_000_000_000))
                if !Task.isCancelled {
                    self.statusMessage = nil
                }
            }
        }
    }

    // MARK: - Timer Control
    public func start(issue: GiteaIssue) {
        // If resuming the same issue while paused, resume instead of resetting elapsedSeconds
        if activeIssue?.id == issue.id && state == .paused {
            resume()
            return
        }

        if activeIssue?.id != issue.id && state != .stopped {
            stop()
        }

        self.activeIssue = issue
        self.state = .running
        self.elapsedSeconds = 0
        addToRecentIssues(issue)

        startTimerTicker()
        IdleDetector.shared.startMonitoring()
    }

    public func resume() {
        guard activeIssue != nil, state == .paused else { return }
        self.state = .running
        startTimerTicker()
    }

    public func pause() {
        guard state == .running else { return }
        self.state = .paused
        timer?.invalidate()
        timer = nil
    }

    public func stop() {
        self.state = .stopped
        self.timer?.invalidate()
        self.timer = nil
        self.elapsedSeconds = 0
    }

    public func addSeconds(_ seconds: Int) {
        self.elapsedSeconds = max(0, self.elapsedSeconds + seconds)
    }

    public func setElapsedSeconds(_ seconds: Int) {
        self.elapsedSeconds = max(0, seconds)
    }

    public func deductIdleSeconds(_ seconds: Int) {
        self.elapsedSeconds = max(0, self.elapsedSeconds - seconds)
    }

    public func stopAndLogTime() async {
        guard let issue = activeIssue, elapsedSeconds > 0 else {
            stop()
            return
        }

        isSubmitting = true
        setStatusMessage("Buche \(SmartTimeParser.formatHumanReadable(elapsedSeconds)) zu \(issue.formattedKey)...", autoClearSeconds: 10.0)

        let owner = issue.repoOwnerName
        let repo = issue.repoName
        let index = issue.number
        let secondsToLog = elapsedSeconds

        do {
            try await GiteaAPIService.shared.logTime(
                owner: owner,
                repo: repo,
                index: index,
                seconds: secondsToLog
            )
            setStatusMessage("Erfolgreich \(SmartTimeParser.formatHumanReadable(secondsToLog)) verbucht!", autoClearSeconds: 4.0)
            stop()
        } catch {
            print("Direct log failed, queueing offline: \(error.localizedDescription)")
            OfflineSyncManager.shared.queueTimeLog(
                owner: owner,
                repo: repo,
                index: index,
                title: issue.title,
                seconds: secondsToLog
            )
            setStatusMessage("Offline gespeichert. Wird synchronisiert, sobald Gitea erreichbar ist.", autoClearSeconds: 5.0)
            stop()
        }

        isSubmitting = false
    }

    public func logManualTime(issue: GiteaIssue, seconds: Int) async -> Bool {
        guard seconds > 0 else { return false }

        isSubmitting = true
        setStatusMessage("Buche \(SmartTimeParser.formatHumanReadable(seconds)) zu \(issue.formattedKey)...", autoClearSeconds: 10.0)

        let owner = issue.repoOwnerName
        let repo = issue.repoName
        let index = issue.number

        addToRecentIssues(issue)

        do {
            try await GiteaAPIService.shared.logTime(
                owner: owner,
                repo: repo,
                index: index,
                seconds: seconds
            )
            setStatusMessage("Manuell \(SmartTimeParser.formatHumanReadable(seconds)) verbucht!", autoClearSeconds: 4.0)
            isSubmitting = false
            return true
        } catch {
            OfflineSyncManager.shared.queueTimeLog(
                owner: owner,
                repo: repo,
                index: index,
                title: issue.title,
                seconds: seconds
            )
            setStatusMessage("Manuelle Zeit offline in Warteschlange gespeichert.", autoClearSeconds: 5.0)
            isSubmitting = false
            return true
        }
    }

    // MARK: - Favorites & Recents
    public func toggleFavorite(_ issue: GiteaIssue) {
        if favoriteIssueIDs.contains(issue.id) {
            favoriteIssueIDs.remove(issue.id)
        } else {
            favoriteIssueIDs.insert(issue.id)
        }
        saveFavorites()
    }

    public func isFavorite(_ issue: GiteaIssue) -> Bool {
        favoriteIssueIDs.contains(issue.id)
    }

    private func addToRecentIssues(_ issue: GiteaIssue) {
        recentIssues.removeAll { $0.id == issue.id }
        recentIssues.insert(issue, at: 0)
        if recentIssues.count > 10 {
            recentIssues = Array(recentIssues.prefix(10))
        }
        saveRecents()
    }

    // MARK: - Private Helpers
    private func startTimerTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func saveRecents() {
        if let data = try? JSONEncoder().encode(recentIssues) {
            UserDefaults.standard.set(data, forKey: recentIssuesKey)
        }
    }

    private func saveFavorites() {
        let array = Array(favoriteIssueIDs)
        UserDefaults.standard.set(array, forKey: favoriteIssuesKey)
    }

    private func loadSavedPreferences() {
        if let data = UserDefaults.standard.data(forKey: recentIssuesKey),
           let decoded = try? JSONDecoder().decode([GiteaIssue].self, from: data) {
            self.recentIssues = decoded
        }

        if let favoritesArray = UserDefaults.standard.array(forKey: favoriteIssuesKey) as? [Int] {
            self.favoriteIssueIDs = Set(favoritesArray)
        }
    }
}
