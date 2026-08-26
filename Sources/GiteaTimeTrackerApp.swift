import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateChecker.shared.checkForUpdatesOnLaunch()
        NotificationService.shared.requestAuthorization()
        _ = GlobalHotkeyService.shared
    }
}

@main
struct GiteaTimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var timerService = TimerService.shared
    @StateObject private var idleDetector = IdleDetector.shared
    @StateObject private var syncManager = OfflineSyncManager.shared
    @StateObject private var updateChecker = UpdateChecker.shared

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // MARK: - Menu Bar Extra App Scene
        MenuBarExtra {
            MenuBarView()
                .onAppear {
                    setupHotkeyHandler()
                }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: timerService.state == .running ? "timer" : "clock")
                    .symbolRenderingMode(.multicolor)

                if timerService.state == .running || timerService.state == .paused {
                    Text(SmartTimeParser.formatTimerString(timerService.elapsedSeconds))
                        .font(.monospacedDigit(.callout)())
                }
            }
            .onAppear {
                setupHotkeyHandler()
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func setupHotkeyHandler() {
        GlobalHotkeyService.shared.setup {
            QuickSwitcherManager.shared.toggle()
        }
    }
}
