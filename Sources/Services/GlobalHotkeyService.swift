import Foundation
import AppKit
import Carbon

@MainActor
public final class GlobalHotkeyService: ObservableObject {
    public static let shared = GlobalHotkeyService()

    public static let defaultKeyCode: UInt32 = UInt32(kVK_ANSI_G)
    public static let defaultModifiers: UInt32 = UInt32(optionKey | shiftKey)
    public static let defaultDisplayString: String = "⌥ ⇧ G"

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

    @Published public private(set) var keyCode: UInt32 = defaultKeyCode
    @Published public private(set) var carbonModifiers: UInt32 = defaultModifiers
    @Published public private(set) var displayString: String = defaultDisplayString

    @Published public var isRecording: Bool = false

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var onTrigger: (() -> Void)?
    private var localEventMonitor: Any?

    private let enabledKey = "gitea_global_hotkey_enabled"
    private let keyCodeKey = "gitea_global_hotkey_keycode"
    private let modifiersKey = "gitea_global_hotkey_modifiers"
    private let displayKey = "gitea_global_hotkey_display"

    private init() {
        loadPreferences()
        if isEnabled {
            registerHotkey()
        }
    }

    public func setup(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        if isEnabled {
            registerHotkey()
        }
    }

    public func setCustomShortcut(keyCode: UInt32, carbonModifiers: UInt32, displayString: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.displayString = displayString
        savePreferences()

        if isEnabled {
            registerHotkey()
        }
    }

    public func resetToDefault() {
        setCustomShortcut(
            keyCode: Self.defaultKeyCode,
            carbonModifiers: Self.defaultModifiers,
            displayString: Self.defaultDisplayString
        )
    }

    public func startRecording() {
        stopRecording()
        isRecording = true

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Require at least one modifier key (command, option, control, or shift)
            if !flags.isEmpty {
                let keyCode = UInt32(event.keyCode)
                let carbonMods = Self.convertToCarbonModifiers(flags)
                let display = Self.formatDisplayString(keyCode: keyCode, flags: flags)

                Task { @MainActor in
                    self.setCustomShortcut(keyCode: keyCode, carbonModifiers: carbonMods, displayString: display)
                    self.stopRecording()
                }
                return nil // Consume event
            }

            return event
        }
    }

    public func stopRecording() {
        isRecording = false
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
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

        InstallEventHandler(GetEventDispatcherTarget(), handlerBlock, 1, &eventType, nil, &eventHandlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(1195725652), id: 1)
        RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
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

    // MARK: - Helpers & Conversion
    public static func convertToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        return carbonFlags
    }

    public static func formatDisplayString(keyCode: UInt32, flags: NSEvent.ModifierFlags) -> String {
        var str = ""
        if flags.contains(.control) { str += "⌃ " }
        if flags.contains(.option) { str += "⌥ " }
        if flags.contains(.shift) { str += "⇧ " }
        if flags.contains(.command) { str += "⌘ " }
        str += keyString(for: keyCode)
        return str
    }

    public static func keyString(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "Key \(keyCode)"
        }
    }

    private func savePreferences() {
        UserDefaults.standard.set(keyCode, forKey: keyCodeKey)
        UserDefaults.standard.set(carbonModifiers, forKey: modifiersKey)
        UserDefaults.standard.set(displayString, forKey: displayKey)
    }

    private func loadPreferences() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }

        if let savedCode = UserDefaults.standard.object(forKey: keyCodeKey) as? UInt32,
           let savedMods = UserDefaults.standard.object(forKey: modifiersKey) as? UInt32,
           let savedDisplay = UserDefaults.standard.string(forKey: displayKey) {
            self.keyCode = savedCode
            self.carbonModifiers = savedMods
            self.displayString = savedDisplay
        }
    }
}
