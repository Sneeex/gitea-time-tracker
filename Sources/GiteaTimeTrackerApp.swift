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

        // MARK: - Quick Switcher Command Palette Window
        Window("Gitea Quick Switcher", id: "quick-switcher") {
            QuickSwitcherView()
                .onAppear {
                    setupHotkeyHandler()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private func setupHotkeyHandler() {
        GlobalHotkeyService.shared.setup {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "quick-switcher" || $0.title == "Gitea Quick Switcher" }),
               window.isVisible && window.isKeyWindow {
                window.close()
            } else {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "quick-switcher" || $0.title == "Gitea Quick Switcher" }) {
                    window.level = .floating
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    window.center()
                    window.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: "quick-switcher")
                }
            }
        }
    }
}
