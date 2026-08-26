import AppKit
import SwiftUI

public class QuickSwitcherManager: NSObject, NSWindowDelegate {
    public static let shared = QuickSwitcherManager()
    
    private var panel: NSPanel?
    
    private override init() {
        super.init()
    }
    
    public func toggle() {
        if let p = panel, p.isVisible && p.isKeyWindow {
            hide()
        } else {
            show()
        }
    }
    
    public func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 330),
                styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .closable],
                backing: .buffered,
                defer: false
            )
            
            panel.isFloatingPanel = true
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.isMovableByWindowBackground = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            
            panel.delegate = self
            
            let hostingView = NSHostingView(rootView: QuickSwitcherView())
            // Ensure background is transparent so SwiftUI material shows
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            
            panel.contentView = hostingView
            
            self.panel = panel
        }
        
        guard let p = panel else { return }
        
        updateSize()
        
        // Always recenter when showing to ensure it's on the active screen
        if let screen = NSScreen.main ?? p.screen ?? NSScreen.screens.first {
            let screenFrame = screen.visibleFrame
            let windowSize = p.frame.size
            let x = screenFrame.minX + (screenFrame.width - windowSize.width) / 2
            let y = screenFrame.minY + (screenFrame.height - windowSize.height) * 0.65
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func hide() {
        panel?.close()
    }
    
    public func updateSize() {
        guard let p = panel else { return }
        
        // This must run on main thread
        DispatchQueue.main.async {
            let targetHeight: CGFloat = TimerService.shared.activeIssue != nil ? 410 : 330
            p.setContentSize(NSSize(width: 520, height: targetHeight))
        }
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
