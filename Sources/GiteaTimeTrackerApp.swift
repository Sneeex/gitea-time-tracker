import SwiftUI
import AppKit

@main
struct GiteaTimeTrackerApp: App {
    @StateObject private var timerService = TimerService.shared
    @StateObject private var idleDetector = IdleDetector.shared
    @StateObject private var syncManager = OfflineSyncManager.shared
    @StateObject private var updateChecker = UpdateChecker.shared

    @State private var isQuickSwitcherOpen: Bool = false

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // MARK: - Menu Bar Extra App Scene
        MenuBarExtra {
            MenuBarView()
                .onAppear {
                    updateChecker.checkForUpdatesOnLaunch()
                    NotificationService.shared.requestAuthorization()
                    GlobalHotkeyService.shared.setup {
                        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "quick-switcher" || $0.title == "Gitea Quick Switcher" }),
                           window.isVisible && window.isKeyWindow {
                            window.close()
                        } else {
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "quick-switcher")
                        }
                    }
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
        }
        .menuBarExtraStyle(.window)

        // MARK: - Quick Switcher Command Palette Window
        Window("Gitea Quick Switcher", id: "quick-switcher") {
            QuickSwitcherView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
