import AppKit
import Carbon

/// Represents a keyboard shortcut with key code and modifiers
struct KeyboardShortcut: Equatable, Codable {
    /// The macOS virtual key code
    let keyCode: UInt32

    /// The Carbon modifier flags (cmdKey, shiftKey, optionKey, controlKey)
    let carbonModifiers: UInt32

    // MARK: - Initialization

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = modifiers
    }

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.carbonModifiers = KeyCodeConverter.modifiersToCarbon(modifiers)
    }

    // MARK: - Default Shortcut

    /// The default shortcut: Cmd+Shift+V
    static let `default` = KeyboardShortcut(
        keyCode: 9,  // V
        modifiers: UInt32(cmdKey | shiftKey)
    )

    // MARK: - Description

    /// Human-readable description of the shortcut (e.g., "⇧⌘V")
    var description: String {
        KeyCodeConverter.shortcutDescription(keyCode: keyCode, modifiers: carbonModifiers)
    }

    // MARK: - Validation

    /// Check if this shortcut is valid (not reserved)
    var isValid: Bool {
        ShortcutValidator.isValid(keyCode: keyCode, modifiers: carbonModifiers)
    }

    /// Get the NSEvent modifier flags equivalent
    var modifierFlags: NSEvent.ModifierFlags {
        KeyCodeConverter.carbonToModifiers(carbonModifiers)
    }
}
