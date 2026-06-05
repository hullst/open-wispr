import AppKit
import Foundation

// Stores and fires the user-assigned silent-rewrite hotkey.
// Key combo is persisted in UserDefaults as keyCode + modifierFlags rawValue.
// The recorder UI (in PreferencesView) writes those values; this class reads them.
final class RewriteHotkeyManager {
    static let shared = RewriteHotkeyManager()

    private var monitor: Any?
    private var onFire: (() -> Void)?

    private init() {}

    struct HotkeyCombo: Equatable {
        let keyCode: UInt16
        let modifiers: NSEvent.ModifierFlags

        static func load() -> HotkeyCombo? {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: "rewriteHotkeyCode") != nil else { return nil }
            let code = UInt16(defaults.integer(forKey: "rewriteHotkeyCode"))
            let mods = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: "rewriteHotkeyMods")))
            return HotkeyCombo(keyCode: code, modifiers: mods)
        }

        func save() {
            UserDefaults.standard.set(Int(keyCode), forKey: "rewriteHotkeyCode")
            UserDefaults.standard.set(Int(modifiers.rawValue), forKey: "rewriteHotkeyMods")
        }

        static func clear() {
            UserDefaults.standard.removeObject(forKey: "rewriteHotkeyCode")
            UserDefaults.standard.removeObject(forKey: "rewriteHotkeyMods")
        }

        var displayString: String {
            var parts: [String] = []
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            if modifiers.contains(.command) { parts.append("⌘") }
            parts.append(keyCodeLabel(keyCode))
            return parts.joined()
        }

        private func keyCodeLabel(_ code: UInt16) -> String {
            let map: [UInt16: String] = [
                36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
                49: "Space", 117: "⌦", 115: "↖", 119: "↘",
                116: "⇞", 121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑",
            ]
            if let label = map[code] { return label }
            // Try to get the character from the current keyboard layout.
            if let str = keyCodeToString(code) { return str.uppercased() }
            return "(\(code))"
        }

        private func keyCodeToString(_ code: UInt16) -> String? {
            guard let source = CGEventSource(stateID: .hidSystemState),
                  let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true) else { return nil }
            var length = 0
            event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
            guard length > 0 else { return nil }
            var chars = [UniChar](repeating: 0, count: length)
            event.keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &chars)
            return String(utf16CodeUnits: chars, count: length)
        }
    }

    func start(onFire: @escaping () -> Void) {
        self.onFire = onFire
        register()
    }

    func reload() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        register()
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func register() {
        guard let combo = HotkeyCombo.load() else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == combo.keyCode else { return }
            let required = combo.modifiers.intersection([.command, .option, .shift, .control])
            let current = event.modifierFlags.intersection([.command, .option, .shift, .control])
            guard current == required else { return }
            self?.onFire?()
        }
    }
}
