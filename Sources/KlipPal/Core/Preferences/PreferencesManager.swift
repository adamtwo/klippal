import Foundation
import Combine
import ServiceManagement
import AppKit

/// Modifier key options for triggering plain text paste
enum PlainTextPasteModifier: String, CaseIterable, Identifiable {
    case shift = "shift"
    case option = "option"
    case control = "control"
    case command = "command"

    var id: String { rawValue }

    /// Display name with symbol
    var displayName: String {
        switch self {
        case .shift: return "⇧ Shift"
        case .option: return "⌥ Option"
        case .control: return "⌃ Control"
        case .command: return "⌘ Command"
        }
    }

    /// The NSEvent.ModifierFlags for this modifier
    var modifierFlags: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .option: return .option
        case .control: return .control
        case .command: return .command
        }
    }
}

/// Manages user preferences with UserDefaults storage and Combine publishers
@MainActor
final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let historyLimit = "historyLimit"
        static let retentionDays = "retentionDays"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let launchAtLogin = "launchAtLogin"
        static let showInDock = "showInDock"
        static let fuzzySearchEnabled = "fuzzySearchEnabled"
        static let plainTextPasteModifier = "plainTextPasteModifier"
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    // MARK: - Default Values

    private enum Defaults {
        static let historyLimit = 500
        static let retentionDays = 30
        static let hotkeyKeyCode: UInt32 = 9  // 'V' key
        static let hotkeyModifiers: UInt32 = 0x0100 | 0x0200  // Cmd + Shift
        static let plainTextPasteModifier = PlainTextPasteModifier.shift
    }

    // MARK: - Published Properties

    /// Maximum number of items to keep in history
    @Published var historyLimit: Int {
        didSet {
            UserDefaults.standard.set(historyLimit, forKey: Keys.historyLimit)
        }
    }

    /// Number of days to retain items (0 = forever)
    @Published var retentionDays: Int {
        didSet {
            UserDefaults.standard.set(retentionDays, forKey: Keys.retentionDays)
        }
    }

    /// Hotkey key code
    @Published var hotkeyKeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode)
        }
    }

    /// Hotkey modifier flags
    @Published var hotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(Int(hotkeyModifiers), forKey: Keys.hotkeyModifiers)
        }
    }

    /// Whether to launch at login
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    /// Whether fuzzy search is enabled (off by default)
    @Published var fuzzySearchEnabled: Bool {
        didSet {
            UserDefaults.standard.set(fuzzySearchEnabled, forKey: Keys.fuzzySearchEnabled)
        }
    }

    /// Modifier key for plain text paste (Shift by default)
    @Published var plainTextPasteModifier: PlainTextPasteModifier {
        didSet {
            UserDefaults.standard.set(plainTextPasteModifier.rawValue, forKey: Keys.plainTextPasteModifier)
        }
    }

    /// Whether to show the menu bar icon (true by default)
    @Published var showMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
        }
    }

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard

        // Load values with defaults
        historyLimit = defaults.object(forKey: Keys.historyLimit) as? Int ?? Defaults.historyLimit
        retentionDays = defaults.object(forKey: Keys.retentionDays) as? Int ?? Defaults.retentionDays
        hotkeyKeyCode = UInt32(defaults.object(forKey: Keys.hotkeyKeyCode) as? Int ?? Int(Defaults.hotkeyKeyCode))
        hotkeyModifiers = UInt32(defaults.object(forKey: Keys.hotkeyModifiers) as? Int ?? Int(Defaults.hotkeyModifiers))
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        fuzzySearchEnabled = defaults.bool(forKey: Keys.fuzzySearchEnabled) // defaults to false

        // Load plain text paste modifier (defaults to Shift)
        if let modifierRaw = defaults.string(forKey: Keys.plainTextPasteModifier),
           let modifier = PlainTextPasteModifier(rawValue: modifierRaw) {
            plainTextPasteModifier = modifier
        } else {
            plainTextPasteModifier = Defaults.plainTextPasteModifier
        }

        // Load show menu bar icon (defaults to true)
        if defaults.object(forKey: Keys.showMenuBarIcon) != nil {
            showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        } else {
            showMenuBarIcon = true
        }
    }

    // MARK: - Launch at Login

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                    print("✅ Registered for launch at login")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("✅ Unregistered from launch at login")
                }
            } catch {
                print("⚠️ Failed to update launch at login: \(error)")
            }
        } else {
            print("⚠️ Launch at login requires macOS 13+")
        }
    }

    /// Check current launch at login status from system
    func refreshLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            launchAtLogin = (status == .enabled)
        }
    }

    // MARK: - Reset

    /// Reset all preferences to defaults
    func resetToDefaults() {
        historyLimit = Defaults.historyLimit
        retentionDays = Defaults.retentionDays
        hotkeyKeyCode = Defaults.hotkeyKeyCode
        hotkeyModifiers = Defaults.hotkeyModifiers
        launchAtLogin = false
        fuzzySearchEnabled = false
        plainTextPasteModifier = Defaults.plainTextPasteModifier
        showMenuBarIcon = true
    }

    // MARK: - Hotkey Helpers

    /// Human-readable hotkey description
    var hotkeyDescription: String {
        var parts: [String] = []

        // Check modifiers
        if hotkeyModifiers & 0x0100 != 0 { parts.append("⌘") }  // Cmd
        if hotkeyModifiers & 0x0200 != 0 { parts.append("⇧") }  // Shift
        if hotkeyModifiers & 0x0800 != 0 { parts.append("⌥") }  // Option
        if hotkeyModifiers & 0x1000 != 0 { parts.append("⌃") }  // Control

        // Add key
        parts.append(keyCodeToString(hotkeyKeyCode))

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'",
            40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        ]
        return keyMap[keyCode] ?? "?"
    }
}
