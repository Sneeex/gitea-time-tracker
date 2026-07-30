import Foundation
import Combine

@MainActor
public final class OfflineSyncManager: ObservableObject {
    public static let shared = OfflineSyncManager()

    @Published public private(set) var pendingEntries: [TimeLogEntry] = []
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncMessage: String?

    private let cacheKey = "gitea_pending_time_logs"

    private init() {
        loadPendingEntries()
    }

    public func queueTimeLog(owner: String, repo: String, index: Int, title: String, seconds: Int) {
        let entry = TimeLogEntry(
            repoOwner: owner,
            repoName: repo,
            issueIndex: index,
            issueTitle: title,
            seconds: seconds,
            createdAt: Date(),
            isSynced: false
        )
        pendingEntries.append(entry)
        savePendingEntries()
    }

    public func removeEntry(id: UUID) {
        pendingEntries.removeAll { $0.id == id }
        savePendingEntries()
    }

    public func syncPendingEntries() async {
        guard !pendingEntries.isEmpty, !isSyncing else { return }

        isSyncing = true
        lastSyncMessage = "Synchronisiere \(pendingEntries.count) ungespeicherte Zeiteinträge..."

        var syncedIDs: [UUID] = []

        for entry in pendingEntries {
            do {
                try await GiteaAPIService.shared.logTime(
                    owner: entry.repoOwner,
                    repo: entry.repoName,
                    index: entry.issueIndex,
                    seconds: entry.seconds
                )
                syncedIDs.append(entry.id)
            } catch {
                print("Failed to sync entry \(entry.id): \(error.localizedDescription)")
                break // Stop sync loop if connection fails again
            }
        }

        pendingEntries.removeAll { syncedIDs.contains($0.id) }
        savePendingEntries()

        isSyncing = false
        if syncedIDs.count > 0 {
            lastSyncMessage = "\(syncedIDs.count) Einträge erfolgreich zu Gitea übertragen."
        } else {
            lastSyncMessage = "Synchronisation fehlgeschlagen (Netzwerk nicht erreichbar)."
        }
    }

    private func loadPendingEntries() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([TimeLogEntry].self, from: data) else {
            return
        }
        self.pendingEntries = decoded
    }

    private func savePendingEntries() {
        if let encoded = try? JSONEncoder().encode(pendingEntries) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
}
