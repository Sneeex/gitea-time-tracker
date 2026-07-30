import SwiftUI
import AppKit

@main
struct GiteaTimeTrackerApp: App {
    @StateObject private var timerService = TimerService.shared
    @StateObject private var idleDetector = IdleDetector.shared
    @StateObject private var syncManager = OfflineSyncManager.shared

    @State private var isQuickSwitcherOpen: Bool = false

    var body: some Scene {
        // MARK: - Menu Bar Extra App Scene
        MenuBarExtra {
            MenuBarView()
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
