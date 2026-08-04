import Foundation
import AppKit
import Carbon

public enum HotkeyPreset: String, CaseIterable, Identifiable {
    case optionShiftG = "⌥ ⇧ G (Option + Shift + G)"
    case cmdOptionT = "⌘ ⌥ T (Cmd + Option + T)"
    case ctrlOptionG = "⌃ ⌥ G (Ctrl + Option + G)"
    case cmdShiftT = "⌘ ⇧ T (Cmd + Shift + T)"
    case optionSpace = "⌥ Space (Option + Space)"

    public var id: String { rawValue }

    public var keyCodeAndModifiers: (keyCode: UInt32, modifiers: UInt32) {
        switch self {
        case .optionShiftG:
            return (UInt32(kVK_ANSI_G), UInt32(optionKey | shiftKey))
        case .cmdOptionT:
            return (UInt32(kVK_ANSI_T), UInt32(cmdKey | optionKey))
        case .ctrlOptionG:
            return (UInt32(kVK_ANSI_G), UInt32(controlKey | optionKey))
        case .cmdShiftT:
            return (UInt32(kVK_ANSI_T), UInt32(cmdKey | shiftKey))
        case .optionSpace:
            return (UInt32(kVK_Space), UInt32(optionKey))
        }
    }
}

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

    @Published public var selectedPreset: HotkeyPreset = .optionShiftG {
        didSet {
            UserDefaults.standard.set(selectedPreset.rawValue, forKey: presetKey)
            if isEnabled {
                registerHotkey()
            }
        }
    }

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var onTrigger: (() -> Void)?

    private let enabledKey = "gitea_global_hotkey_enabled"
    private let presetKey = "gitea_global_hotkey_preset"

    private init() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
        if let savedPresetRaw = UserDefaults.standard.string(forKey: presetKey),
           let preset = HotkeyPreset(rawValue: savedPresetRaw) {
            self.selectedPreset = preset
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

        let combo = selectedPreset.keyCodeAndModifiers
        let hotKeyID = EventHotKeyID(signature: OSType(1195725652), id: 1)

        RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
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
