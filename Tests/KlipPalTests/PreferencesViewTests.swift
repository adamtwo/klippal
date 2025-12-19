import XCTest
@testable import KlipPal

/// Tests for the PreferencesView sidebar navigation
final class PreferencesViewTests: XCTestCase {

    // MARK: - SettingsCategory Enum Tests

    func testSettingsCategoryAllCases() {
        let allCases = SettingsCategory.allCases

        XCTAssertEqual(allCases.count, 4, "Should have 4 settings categories")
        XCTAssertEqual(allCases[0], .general)
        XCTAssertEqual(allCases[1], .storage)
        XCTAssertEqual(allCases[2], .advanced)
        XCTAssertEqual(allCases[3], .about)
    }

    func testSettingsCategoryRawValues() {
        XCTAssertEqual(SettingsCategory.general.rawValue, "General")
        XCTAssertEqual(SettingsCategory.storage.rawValue, "Storage")
        XCTAssertEqual(SettingsCategory.advanced.rawValue, "Advanced")
        XCTAssertEqual(SettingsCategory.about.rawValue, "About")
    }

    func testSettingsCategoryIdentifiable() {
        // Verify each category has a unique identifier
        let ids = SettingsCategory.allCases.map { $0.id }
        let uniqueIds = Set(ids)

        XCTAssertEqual(ids.count, uniqueIds.count, "All category IDs should be unique")
    }

    func testSettingsCategoryIdMatchesRawValue() {
        for category in SettingsCategory.allCases {
            XCTAssertEqual(category.id, category.rawValue, "ID should match raw value for \(category)")
        }
    }

    func testSettingsCategoryIcons() {
        XCTAssertEqual(SettingsCategory.general.icon, "gear")
        XCTAssertEqual(SettingsCategory.storage.icon, "internaldrive")
        XCTAssertEqual(SettingsCategory.advanced.icon, "gearshape.2")
        XCTAssertEqual(SettingsCategory.about.icon, "info.circle")
    }

    func testSettingsCategoryIconsAreNotEmpty() {
        for category in SettingsCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "Icon should not be empty for \(category)")
        }
    }

    func testSettingsCategoryIconsAreValidSFSymbols() {
        // All icons should be valid SF Symbol names (non-empty strings)
        let expectedIcons = ["gear", "internaldrive", "gearshape.2", "info.circle"]

        for (index, category) in SettingsCategory.allCases.enumerated() {
            XCTAssertEqual(category.icon, expectedIcons[index],
                "Category \(category) should have icon \(expectedIcons[index])")
        }
    }

    // MARK: - Category Order Tests

    func testSettingsCategoryOrderIsLogical() {
        let categories = SettingsCategory.allCases

        // General should come first (most common settings)
        XCTAssertEqual(categories.first, .general, "General should be first")

        // About should come last (informational)
        XCTAssertEqual(categories.last, .about, "About should be last")
    }

    // MARK: - Equality Tests

    func testSettingsCategoryEquality() {
        XCTAssertEqual(SettingsCategory.general, SettingsCategory.general)
        XCTAssertEqual(SettingsCategory.storage, SettingsCategory.storage)
        XCTAssertEqual(SettingsCategory.advanced, SettingsCategory.advanced)
        XCTAssertEqual(SettingsCategory.about, SettingsCategory.about)

        XCTAssertNotEqual(SettingsCategory.general, SettingsCategory.storage)
        XCTAssertNotEqual(SettingsCategory.general, SettingsCategory.advanced)
        XCTAssertNotEqual(SettingsCategory.general, SettingsCategory.about)
    }

    // MARK: - Hashable Tests

    func testSettingsCategoryHashable() {
        var categorySet = Set<SettingsCategory>()

        categorySet.insert(.general)
        categorySet.insert(.storage)
        categorySet.insert(.advanced)
        categorySet.insert(.about)

        XCTAssertEqual(categorySet.count, 4, "Set should contain all 4 categories")

        // Inserting duplicates should not change count
        categorySet.insert(.general)
        XCTAssertEqual(categorySet.count, 4, "Set count should remain 4 after duplicate insert")
    }

    func testSettingsCategoryCanBeUsedAsDictionaryKey() {
        var categoryDict: [SettingsCategory: String] = [:]

        categoryDict[.general] = "General Settings"
        categoryDict[.storage] = "Storage Settings"
        categoryDict[.advanced] = "Advanced Settings"
        categoryDict[.about] = "About Info"

        XCTAssertEqual(categoryDict[.general], "General Settings")
        XCTAssertEqual(categoryDict[.storage], "Storage Settings")
        XCTAssertEqual(categoryDict[.advanced], "Advanced Settings")
        XCTAssertEqual(categoryDict[.about], "About Info")
    }
}
