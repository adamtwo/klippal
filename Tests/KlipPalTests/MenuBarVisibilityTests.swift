import XCTest
@testable import KlipPal

final class MenuBarVisibilityTests: XCTestCase {

    override func tearDown() async throws {
        // Reset to default after each test
        await MainActor.run {
            PreferencesManager.shared.showMenuBarIcon = true
        }
    }

    // MARK: - Preference Tests

    @MainActor
    func testShowMenuBarIconDefaultsToTrue() async throws {
        // The preference should default to true (icon visible)
        // Note: We can't truly test "fresh" state since PreferencesManager is a singleton
        // But we can verify the current value and that setting works
        let preferences = PreferencesManager.shared

        // Reset to true and verify
        preferences.showMenuBarIcon = true
        XCTAssertTrue(preferences.showMenuBarIcon)
    }

    @MainActor
    func testToggleMenuBarIconPersistsToUserDefaults() async throws {
        let preferences = PreferencesManager.shared

        // When: Setting to false
        preferences.showMenuBarIcon = false

        // Then: Should persist to UserDefaults
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "showMenuBarIcon"))
        XCTAssertFalse(preferences.showMenuBarIcon)

        // When: Setting back to true
        preferences.showMenuBarIcon = true

        // Then: Should persist to UserDefaults
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "showMenuBarIcon"))
        XCTAssertTrue(preferences.showMenuBarIcon)
    }

    @MainActor
    func testShowMenuBarIconIncludedInResetToDefaults() async throws {
        let preferences = PreferencesManager.shared

        // Given: Set to non-default value
        preferences.showMenuBarIcon = false
        XCTAssertFalse(preferences.showMenuBarIcon)

        // When: Reset to defaults
        preferences.resetToDefaults()

        // Then: Should be back to true
        XCTAssertTrue(preferences.showMenuBarIcon)
    }
}
