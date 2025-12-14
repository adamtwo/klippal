import XCTest
@testable import KlipPal

/// Tests for PreferencesManager and PreferencesWindowController
final class PreferencesTests: XCTestCase {

    override func setUp() async throws {
        // Clear any existing preferences for clean tests
        UserDefaults.standard.removeObject(forKey: "historyLimit")
        UserDefaults.standard.removeObject(forKey: "retentionDays")
        UserDefaults.standard.removeObject(forKey: "hotkeyKeyCode")
        UserDefaults.standard.removeObject(forKey: "hotkeyModifiers")
        UserDefaults.standard.removeObject(forKey: "launchAtLogin")
        UserDefaults.standard.removeObject(forKey: "fuzzySearchEnabled")
    }

    // MARK: - PreferencesManager Tests

    @MainActor
    func testPreferencesManagerDefaultValues() async throws {
        let prefs = PreferencesManager.shared

        // Reset to defaults first
        prefs.resetToDefaults()

        XCTAssertEqual(prefs.historyLimit, 500, "Default history limit should be 500")
        XCTAssertEqual(prefs.retentionDays, 30, "Default retention days should be 30")
        XCTAssertEqual(prefs.hotkeyKeyCode, 9, "Default hotkey should be 'V' (keycode 9)")
        XCTAssertFalse(prefs.launchAtLogin, "Launch at login should be false by default")
        XCTAssertFalse(prefs.fuzzySearchEnabled, "Fuzzy search should be disabled by default")
    }

    @MainActor
    func testPreferencesManagerPersistsHistoryLimit() async throws {
        let prefs = PreferencesManager.shared

        prefs.historyLimit = 1000

        // Read directly from UserDefaults
        let saved = UserDefaults.standard.integer(forKey: "historyLimit")
        XCTAssertEqual(saved, 1000, "History limit should be persisted to UserDefaults")
    }

    @MainActor
    func testPreferencesManagerPersistsRetentionDays() async throws {
        let prefs = PreferencesManager.shared

        prefs.retentionDays = 60

        let saved = UserDefaults.standard.integer(forKey: "retentionDays")
        XCTAssertEqual(saved, 60, "Retention days should be persisted to UserDefaults")
    }

    @MainActor
    func testHotkeyDescription() async throws {
        let prefs = PreferencesManager.shared

        // Default is Cmd+Shift+V
        prefs.hotkeyKeyCode = 9  // V
        prefs.hotkeyModifiers = 0x0100 | 0x0200  // Cmd + Shift

        let description = prefs.hotkeyDescription
        XCTAssertTrue(description.contains("⌘"), "Should contain Command symbol")
        XCTAssertTrue(description.contains("⇧"), "Should contain Shift symbol")
        XCTAssertTrue(description.contains("V"), "Should contain V key")
    }

    @MainActor
    func testResetToDefaults() async throws {
        let prefs = PreferencesManager.shared

        // Change values
        prefs.historyLimit = 100
        prefs.retentionDays = 7
        prefs.fuzzySearchEnabled = true

        // Reset
        prefs.resetToDefaults()

        XCTAssertEqual(prefs.historyLimit, 500, "History limit should reset to 500")
        XCTAssertEqual(prefs.retentionDays, 30, "Retention days should reset to 30")
        XCTAssertFalse(prefs.fuzzySearchEnabled, "Fuzzy search should reset to disabled")
    }

    // MARK: - Fuzzy Search Preference Tests

    @MainActor
    func testFuzzySearchEnabledDefaultsToFalse() async throws {
        // Clear any existing value
        UserDefaults.standard.removeObject(forKey: "fuzzySearchEnabled")

        // UserDefaults.bool returns false for missing keys
        let value = UserDefaults.standard.bool(forKey: "fuzzySearchEnabled")
        XCTAssertFalse(value, "Fuzzy search should default to false when not set")
    }

    @MainActor
    func testFuzzySearchEnabledPersistsToUserDefaults() async throws {
        let prefs = PreferencesManager.shared

        prefs.fuzzySearchEnabled = true

        let saved = UserDefaults.standard.bool(forKey: "fuzzySearchEnabled")
        XCTAssertTrue(saved, "Fuzzy search enabled should be persisted to UserDefaults")

        prefs.fuzzySearchEnabled = false

        let savedFalse = UserDefaults.standard.bool(forKey: "fuzzySearchEnabled")
        XCTAssertFalse(savedFalse, "Fuzzy search disabled should be persisted to UserDefaults")
    }

    @MainActor
    func testFuzzySearchEnabledCanBeToggled() async throws {
        let prefs = PreferencesManager.shared

        prefs.fuzzySearchEnabled = false
        XCTAssertFalse(prefs.fuzzySearchEnabled)

        prefs.fuzzySearchEnabled = true
        XCTAssertTrue(prefs.fuzzySearchEnabled)

        prefs.fuzzySearchEnabled = false
        XCTAssertFalse(prefs.fuzzySearchEnabled)
    }

    // MARK: - PreferencesWindowController Tests

    @MainActor
    func testPreferencesWindowControllerCreatesWindow() async throws {
        let controller = PreferencesWindowController()

        XCTAssertNotNil(controller.window, "Window should be created")
        XCTAssertEqual(controller.window?.title, "KlipPal Preferences", "Window should have correct title")
    }

    @MainActor
    func testPreferencesWindowControllerShowCreatesSharedInstance() async throws {
        // Clear any existing instance
        PreferencesWindowController.shared = nil

        PreferencesWindowController.show()

        XCTAssertNotNil(PreferencesWindowController.shared, "Shared instance should be created")
        XCTAssertNotNil(PreferencesWindowController.shared?.window, "Window should exist")
    }

    @MainActor
    func testPreferencesWindowIsNotReleasedWhenClosed() async throws {
        let controller = PreferencesWindowController()

        XCTAssertFalse(controller.window?.isReleasedWhenClosed ?? true, "Window should not be released when closed")
    }

    @MainActor
    func testPreferencesWindowHasCorrectSize() async throws {
        let controller = PreferencesWindowController()

        let frame = controller.window?.frame
        XCTAssertEqual(frame?.width, 450, "Window width should be 450")
        // Height includes title bar, so check minimum content height
        XCTAssertGreaterThanOrEqual(frame?.height ?? 0, 300, "Window height should be at least 300")
    }

    @MainActor
    func testPreferencesWindowHasContentView() async throws {
        let controller = PreferencesWindowController()

        XCTAssertNotNil(controller.window?.contentView, "Window should have content view")
    }
}

// Note: StatusBarController tests require window server connection and can't run in CI
// The StatusBarController menu actions are tested via manual testing
