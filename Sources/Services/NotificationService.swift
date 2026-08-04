import Foundation
import UserNotifications
import AppKit

@MainActor
public final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()

    public nonisolated static let categoryIdentifier = "GIT_BRANCH_CATEGORY"
    public nonisolated static let actionStartTracking = "START_TRACKING_ACTION"

    @Published public private(set) var isAuthorized: Bool = false

    public var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private override init() {
        super.init()
        if isAvailable {
            UNUserNotificationCenter.current().delegate = self
            setupNotificationCategories()
            checkAuthorizationStatus()
        }
    }

    public func requestAuthorization() {
        guard isAvailable else {
            print("NotificationService: UNUserNotificationCenter disabled (running outside .app bundle)")
            return
        }
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
        guard isAvailable else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }

    private func setupNotificationCategories() {
        guard isAvailable else { return }
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

    public func sendTestNotification() {
        guard isAvailable else {
            print("TestNotification: Cannot send (no .app bundle identifier)")
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification request error: \(error.localizedDescription)")
            }

            let content = UNMutableNotificationContent()
            content.title = "Test-Benachrichtigung"
            content.subtitle = "Gitea Time Tracker"
            content.body = "Benachrichtigungen funktionieren einwandfrei!"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
            let request = UNNotificationRequest(
                identifier: "test_notification_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to deliver test notification: \(error.localizedDescription)")
                }
            }
        }
    }

    public func sendGitBranchNotification(issue: GiteaIssue, branchName: String) {
        guard isAvailable else {
            print("GitBranchNotification: Cannot send notification (no .app bundle identifier)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Git-Branch gewechselt"
        content.subtitle = "\(branchName) → \(issue.formattedKey)"
        content.body = "\(issue.title)\nKlicke unten, um die Stoppuhr jetzt zu starten."
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        if let encoded = try? JSONEncoder().encode(issue) {
            content.userInfo = ["issue_data": encoded]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "git_branch_\(issue.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
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
        completionHandler([.banner, .sound, .list, .badge])
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
