import AppKit
import SwiftUI

@MainActor
public class MenuBarManager: ObservableObject {
    public static let shared = MenuBarManager()

    public weak var statusItem: NSStatusItem?
    public weak var statusButton: NSStatusBarButton?
    public weak var statusBarWindow: NSWindow?

    private enum SPI {
        static let beginSession = NSSelectorFromString("_beginExpandedInterfaceSession:")
        static let session = NSSelectorFromString("expandedInterfaceSession")
        static let delegate = NSSelectorFromString("expandedInterfaceDelegate")
    }

    private init() {}

    /// Registers the status item or button from the view hierarchy inside the MenuBarExtra label
    public func register(view: NSView) {
        if let window = view.window {
            self.statusBarWindow = window
            if let item = window.value(forKey: "statusItem") as? NSStatusItem {
                self.statusItem = item
            }
        }

        var current: NSView? = view
        while let curr = current {
            if let button = curr as? NSStatusBarButton {
                self.statusButton = button
                break
            }
            current = curr.superview
        }
    }

    /// Finds the status item created by MenuBarExtra by querying NSApp.windows
    public func findStatusItem() -> NSStatusItem? {
        if let item = statusItem {
            return item
        }

        for window in NSApplication.shared.windows {
            if window.className.contains("NSStatusBarWindow") {
                if let item = (window.value(forKey: "statusItem") as? NSStatusItem)
                    ?? (Mirror(reflecting: window).descendant("statusItem") as? NSStatusItem) {
                    self.statusItem = item
                    return item
                }
            }
        }
        return nil
    }

    /// Finds the status bar button
    public func findStatusButton() -> NSStatusBarButton? {
        if let btn = statusButton {
            return btn
        }

        if let item = findStatusItem(), let btn = item.button {
            self.statusButton = btn
            return btn
        }

        for window in NSApplication.shared.windows {
            if window.className.contains("NSStatusBarWindow") {
                if let button = window.contentView?.subviews.first(where: { $0 is NSStatusBarButton }) as? NSStatusBarButton {
                    self.statusButton = button
                    return button
                }
            }
        }
        return nil
    }

    /// Dismisses Quick Switcher and presents the MenuBarExtra app tray popup
    public func showAppTrayMenu() {
        // 1. Hide the Quick Switcher panel
        QuickSwitcherManager.shared.hide()

        // 2. Open the menu bar popup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let item = self.findStatusItem()
            let button = self.findStatusButton() ?? item?.button

            // macOS 15+ Expanded Interface Session mechanism
            if let item = item,
               item.responds(to: SPI.beginSession),
               item.responds(to: SPI.delegate),
               item.perform(SPI.delegate) != nil {

                // If already presented, do nothing
                if let session = item.perform(SPI.session)?.takeUnretainedValue() as? NSObject {
                    _ = session
                    return
                }

                if let impl = item.method(for: SPI.beginSession) {
                    typealias BeginSession = @convention(c) (NSStatusItem, Selector, TimeInterval) -> Void
                    unsafeBitCast(impl, to: BeginSession.self)(item, SPI.beginSession, .greatestFiniteMagnitude)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    return
                }
            }

            // Fallback for macOS 14 and earlier / standard button action
            if let button = button {
                button.performClick(button)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
}

/// Helper view modifier / representable to capture the NSStatusBarButton directly from MenuBarExtra's label
public struct StatusItemAccessor: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            MenuBarManager.shared.register(view: view)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            MenuBarManager.shared.register(view: nsView)
        }
    }
}
