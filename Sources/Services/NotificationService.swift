import Foundation
import UserNotifications
import AppKit

@MainActor
public final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()

    public nonisolated static let categoryIdentifier = "GIT_BRANCH_CATEGORY"
    public nonisolated static let actionStartTracking = "START_TRACKING_ACTION"

    @Published public private(set) var isAuthorized: Bool = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
        checkAuthorizationStatus()
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                self.isAuthorized = granted
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }

    public func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }

    private func setupNotificationCategories() {
        let startAction = UNNotificationAction(
            identifier: Self.actionStartTracking,
            title: "▶ Zeiterfassung starten",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [startAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    public func sendGitBranchNotification(issue: GiteaIssue, branchName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Git-Branch gewechselt"
        content.subtitle = "\(branchName) → \(issue.formattedKey)"
        content.body = "\(issue.title)\nKlicke unten, um die Stoppuhr jetzt zu starten."
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        if let encoded = try? JSONEncoder().encode(issue) {
            content.userInfo = ["issue_data": encoded]
        }

        let request = UNNotificationRequest(
            identifier: "git_branch_\(issue.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == Self.actionStartTracking || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let data = userInfo["issue_data"] as? Data,
               let issue = try? JSONDecoder().decode(GiteaIssue.self, from: data) {
                Task { @MainActor in
                    TimerService.shared.start(issue: issue)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }

        completionHandler()
    }
}
