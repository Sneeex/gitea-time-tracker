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
                    window.styleMask.insert(.fullSizeContentView)
                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.isMovableByWindowBackground = true
                    if let screen = NSScreen.main ?? window.screen ?? NSScreen.screens.first {
                        let screenFrame = screen.visibleFrame
                        let windowSize = window.frame.size
                        let x = screenFrame.minX + (screenFrame.width - windowSize.width) / 2
                        let y = screenFrame.minY + (screenFrame.height - windowSize.height) * 0.65
                        window.setFrameOrigin(NSPoint(x: x, y: y))
                    }
                    window.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: "quick-switcher")
                }
            }
        }
    }
}
