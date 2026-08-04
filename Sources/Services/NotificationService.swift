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
        NSUserNotificationCenter.default.delegate = self
        if isAvailable {
            UNUserNotificationCenter.current().delegate = self
            setupNotificationCategories()
            checkAuthorizationStatus()
        }
    }

    public func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                self.isAuthorized = granted
                if !granted {
                    self.checkAuthorizationStatus()
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

    public func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
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
        // 1. Deliver via NSUserNotificationCenter (guaranteed banner delivery on macOS)
        let legacyNotification = NSUserNotification()
        legacyNotification.title = "Test-Benachrichtigung"
        legacyNotification.subtitle = "Gitea Time Tracker"
        legacyNotification.informativeText = "Benachrichtigungen funktionieren einwandfrei!"
        legacyNotification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(legacyNotification)

        // 2. Deliver via UNUserNotificationCenter if available
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            let content = UNMutableNotificationContent()
            content.title = "Test-Benachrichtigung"
            content.subtitle = "Gitea Time Tracker"
            content.body = "Benachrichtigungen funktionieren einwandfrei!"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "test_notification_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    public func sendGitBranchNotification(issue: GiteaIssue, branchName: String) {
        // 1. Deliver via NSUserNotificationCenter
        let legacyNotification = NSUserNotification()
        legacyNotification.title = "Git-Branch gewechselt"
        legacyNotification.subtitle = "\(branchName) → \(issue.formattedKey)"
        legacyNotification.informativeText = "\(issue.title)\nKlicke zum Starten der Stoppuhr."
        legacyNotification.soundName = NSUserNotificationDefaultSoundName
        if let encoded = try? JSONEncoder().encode(issue) {
            legacyNotification.userInfo = ["issue_data": encoded]
        }
        NSUserNotificationCenter.default.deliver(legacyNotification)

        // 2. Deliver via UNUserNotificationCenter
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Git-Branch gewechselt"
        content.subtitle = "\(branchName) → \(issue.formattedKey)"
        content.body = "\(issue.title)\nKlicke unten, um die Stoppuhr jetzt zu starten."
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        if let encoded = try? JSONEncoder().encode(issue) {
            content.userInfo = ["issue_data": encoded]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "git_branch_\(issue.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
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

// MARK: - NSUserNotificationCenterDelegate
extension NotificationService: NSUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }

    public nonisolated func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if let data = notification.userInfo?["issue_data"] as? Data,
           let issue = try? JSONDecoder().decode(GiteaIssue.self, from: data) {
            Task { @MainActor in
                TimerService.shared.start(issue: issue)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
