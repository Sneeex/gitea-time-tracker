import Foundation
import AppKit
import Carbon

@MainActor
public final class GlobalHotkeyService: ObservableObject {
    public static let shared = GlobalHotkeyService()

    @Published public var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if isEnabled {
                registerHotkey()
            } else {
                unregisterHotkey()
            }
        }
    }

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var onTrigger: (() -> Void)?

    private let enabledKey = "gitea_global_hotkey_enabled"

    private init() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
    }

    public func setup(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        if isEnabled {
            registerHotkey()
        }
    }

    public func registerHotkey() {
        unregisterHotkey()
        guard isEnabled else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerBlock: EventHandlerUPP = { _, _, _ in
            Task { @MainActor in
                GlobalHotkeyService.shared.handleHotkeyTriggered()
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handlerBlock, 1, &eventType, nil, &eventHandlerRef)

        // Hotkey: Option + Shift + G (KeyCode 5 for 'g', optionKey | shiftKey)
        let hotKeyID = EventHotKeyID(signature: OSType(1195725652), id: 1)
        let modifiers = UInt32(optionKey | shiftKey)
        let keyCode = UInt32(kVK_ANSI_G)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    public func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    private func handleHotkeyTriggered() {
        onTrigger?()
    }
}
