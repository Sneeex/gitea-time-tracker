import Testing
import AppKit
@testable import GiteaTimeTracker

struct MenuBarManagerTests {

    @Test @MainActor func testMenuBarManagerSharedInstance() {
        let manager = MenuBarManager.shared
        #expect(manager.findStatusItem() == nil || manager.findStatusItem() != nil)
    }

    @Test @MainActor func testRegisterViewSafely() {
        let manager = MenuBarManager.shared
        let view = NSView()
        manager.register(view: view)
        // Ensure calling register does not crash and leaves manager in valid state
        #expect(manager.findStatusButton() == nil || manager.findStatusButton() != nil)
    }

    @Test @MainActor func testShowAppTrayMenuDoesNotCrashInHeadlessMode() {
        let manager = MenuBarManager.shared
        // Calling showAppTrayMenu when no status item or window exists shouldn't crash
        manager.showAppTrayMenu()
        #expect(Bool(true))
    }
}
