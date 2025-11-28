import Carbon

/// Validates keyboard shortcuts to ensure they don't conflict with system shortcuts
enum ShortcutValidator {

    // MARK: - Default Shortcut

    /// Default keyboard shortcut: Cmd+Shift+V
    static let defaultKeyCode: UInt32 = 9  // V key
    static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    // MARK: - Reserved Shortcuts

    /// Reserved system shortcuts that should not be overridden
    private static let reservedShortcuts: [(keyCode: UInt32, modifiers: UInt32, description: String)] = [
        // Standard clipboard shortcuts
        (8, UInt32(cmdKey), "Copy (⌘C)"),
        (9, UInt32(cmdKey), "Paste (⌘V)"),
        (7, UInt32(cmdKey), "Cut (⌘X)"),
        (0, UInt32(cmdKey), "Select All (⌘A)"),
        (6, UInt32(cmdKey), "Undo (⌘Z)"),
        (6, UInt32(cmdKey | shiftKey), "Redo (⌘⇧Z)"),

        // Application shortcuts
        (12, UInt32(cmdKey), "Quit (⌘Q)"),
        (13, UInt32(cmdKey), "Close Window (⌘W)"),
        (46, UInt32(cmdKey), "Minimize (⌘M)"),
        (4, UInt32(cmdKey), "Hide (⌘H)"),
        (4, UInt32(cmdKey | optionKey), "Hide Others (⌘⌥H)"),

        // System shortcuts
        (48, UInt32(cmdKey), "App Switcher (⌘Tab)"),
        (49, UInt32(cmdKey), "Spotlight (⌘Space)"),
        (49, UInt32(controlKey), "Input Source (⌃Space)"),

        // File operations
        (1, UInt32(cmdKey), "Save (⌘S)"),
        (1, UInt32(cmdKey | shiftKey), "Save As (⌘⇧S)"),
        (31, UInt32(cmdKey), "Open (⌘O)"),
        (45, UInt32(cmdKey), "New (⌘N)"),
        (35, UInt32(cmdKey), "Print (⌘P)"),

        // Find
        (3, UInt32(cmdKey), "Find (⌘F)"),
        (5, UInt32(cmdKey), "Find & Replace (⌘G)"),

        // Screenshot shortcuts (macOS system)
        (21, UInt32(cmdKey | shiftKey), "Screenshot (⌘⇧4)"),
        (20, UInt32(cmdKey | shiftKey), "Screenshot (⌘⇧3)"),
        (23, UInt32(cmdKey | shiftKey), "Screenshot (⌘⇧5)"),

        // Mission Control
        (126, UInt32(controlKey), "Mission Control (⌃↑)"),
        (125, UInt32(controlKey), "App Windows (⌃↓)"),

        // Text editing
        (0, UInt32(cmdKey | shiftKey), "Select to Start (⌘⇧A)"),
        (5, UInt32(cmdKey | shiftKey), "Select to End (⌘⇧G)"),

        // Bold, Italic, Underline
        (11, UInt32(cmdKey), "Bold (⌘B)"),
        (34, UInt32(cmdKey), "Italic (⌘I)"),
        (32, UInt32(cmdKey), "Underline (⌘U)"),

        // Refresh
        (15, UInt32(cmdKey), "Refresh (⌘R)"),
    ]

    // MARK: - Validation

    /// Check if a shortcut is valid (not reserved and has required modifiers)
    static func isValid(keyCode: UInt32, modifiers: UInt32) -> Bool {
        // Must have at least Command, Control, or Option modifier
        let hasCommand = modifiers & UInt32(cmdKey) != 0
        let hasControl = modifiers & UInt32(controlKey) != 0
        let hasOption = modifiers & UInt32(optionKey) != 0

        // Shift alone is not enough
        if !hasCommand && !hasControl && !hasOption {
            return false
        }

        // Check if it's a reserved shortcut
        if isReserved(keyCode: keyCode, modifiers: modifiers) {
            return false
        }

        return true
    }

    /// Check if a shortcut is reserved by the system
    static func isReserved(keyCode: UInt32, modifiers: UInt32) -> Bool {
        // Normalize modifiers (remove non-modifier bits)
        let normalizedMods = modifiers & UInt32(cmdKey | shiftKey | optionKey | controlKey)

        for reserved in reservedShortcuts {
            if reserved.keyCode == keyCode && reserved.modifiers == normalizedMods {
                return true
            }
        }

        return false
    }

    /// Get a message explaining why a shortcut is reserved
    static func reservedShortcutMessage(keyCode: UInt32, modifiers: UInt32) -> String? {
        let normalizedMods = modifiers & UInt32(cmdKey | shiftKey | optionKey | controlKey)

        for reserved in reservedShortcuts {
            if reserved.keyCode == keyCode && reserved.modifiers == normalizedMods {
                return "\(reserved.description) is reserved by the system"
            }
        }

        return nil
    }
}
