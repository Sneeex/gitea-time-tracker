import Foundation
import AppKit
import CoreGraphics
import Combine

@MainActor
public final class IdleDetector: ObservableObject {
    public static let shared = IdleDetector()

    @Published public var isIdleDialogPresented: Bool = false
    @Published public var detectedIdleSeconds: Int = 0
    @Published public var idleThresholdMinutes: Int = 5

    private var timer: Timer?
    private var lastActiveDate: Date = Date()
    private var isTrackingIdle: Bool = false

    private init() {
        setupSleepNotifications()
    }

    public func startMonitoring(thresholdMinutes: Int = 5) {
        self.idleThresholdMinutes = thresholdMinutes
        self.timer?.invalidate()

        self.timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSystemIdleTime()
            }
        }
    }

    public func stopMonitoring() {
        self.timer?.invalidate()
        self.timer = nil
    }

    private func checkSystemIdleTime() {
        // CGEventSource.secondsSinceLastEventType gets seconds since mouse/keyboard movement
        let idleSeconds = Int(CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .init(rawValue: ~0)!))
        let thresholdSecs = idleThresholdMinutes * 60

        if idleSeconds >= thresholdSecs && !isIdleDialogPresented {
            self.detectedIdleSeconds = idleSeconds
            self.isIdleDialogPresented = true
        }
    }

    private func setupSleepNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lastActiveDate = Date()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let elapsed = Int(Date().timeIntervalSince(self.lastActiveDate))
                if elapsed >= (self.idleThresholdMinutes * 60) && !self.isIdleDialogPresented {
                    self.detectedIdleSeconds = elapsed
                    self.isIdleDialogPresented = true
                }
            }
        }
    }
}
