import AppKit
import Carbon

/// Utility for converting between key codes, modifiers, and human-readable strings
enum KeyCodeConverter {

    // MARK: - Key Code to String

    /// Map of macOS key codes to their string representations
    private static let keyCodeMap: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
        32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'",
        40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        // Function keys
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        // Arrow keys
        123: "←", 124: "→", 125: "↓", 126: "↑",
        // Other special keys
        117: "⌦", 119: "End", 121: "PgDn", 116: "PgUp", 115: "Home",
    ]

    /// Convert a key code to its string representation
    static func keyCodeToString(_ keyCode: UInt32) -> String {
        return keyCodeMap[keyCode] ?? "?"
    }

    /// Convert a key code to its string representation (Int version)
    static func keyCodeToString(_ keyCode: Int) -> String {
        return keyCodeToString(UInt32(keyCode))
    }

    // MARK: - Modifier Symbols

    /// Get the symbol for a modifier key
    static func modifierSymbol(for modifier: NSEvent.ModifierFlags) -> String {
        switch modifier {
        case .command: return "⌘"
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        case .capsLock: return "⇪"
        case .function: return "fn"
        default: return ""
        }
    }

    // MARK: - Carbon <-> NSEvent Modifier Conversion

    /// Convert NSEvent.ModifierFlags to Carbon modifier flags
    static func modifiersToCarbon(_ modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonMods: UInt32 = 0

        if modifiers.contains(.command) {
            carbonMods |= UInt32(cmdKey)
        }
        if modifiers.contains(.shift) {
            carbonMods |= UInt32(shiftKey)
        }
        if modifiers.contains(.option) {
            carbonMods |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            carbonMods |= UInt32(controlKey)
        }

        return carbonMods
    }

    /// Convert Carbon modifier flags to NSEvent.ModifierFlags
    static func carbonToModifiers(_ carbonMods: UInt32) -> NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []

        if carbonMods & UInt32(cmdKey) != 0 {
            modifiers.insert(.command)
        }
        if carbonMods & UInt32(shiftKey) != 0 {
            modifiers.insert(.shift)
        }
        if carbonMods & UInt32(optionKey) != 0 {
            modifiers.insert(.option)
        }
        if carbonMods & UInt32(controlKey) != 0 {
            modifiers.insert(.control)
        }

        return modifiers
    }

    // MARK: - Shortcut Description

    /// Generate a human-readable shortcut description
    static func shortcutDescription(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []

        // Add modifiers in standard macOS order: Control, Option, Shift, Command
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        // Add the key
        parts.append(keyCodeToString(keyCode))

        return parts.joined()
    }

    /// Generate a human-readable shortcut description from NSEvent modifiers
    static func shortcutDescription(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) -> String {
        return shortcutDescription(keyCode: keyCode, modifiers: modifiersToCarbon(modifiers))
    }
}
