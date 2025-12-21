import XCTest
@testable import KlipPal

@MainActor
final class OverlayOpenPreferencesTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var viewModel: OverlayViewModel!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_prefs_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Set up AppDelegate.shared for ViewModel to use
        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        AppDelegate.shared = appDelegate

        viewModel = OverlayViewModel(storage: storage)
    }

    override func tearDown() async throws {
        viewModel = nil
        storage = nil
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - openPreferences Tests

    func testOpenPreferencesCallsCallback() async throws {
        var callbackCalled = false
        var receivedCategory: SettingsCategory?

        viewModel.onOpenPreferences = { category in
            callbackCalled = true
            receivedCategory = category
        }

        viewModel.openPreferences()

        XCTAssertTrue(callbackCalled, "onOpenPreferences callback should be called")
        XCTAssertEqual(receivedCategory, .general, "Default category should be .general")
    }

    func testOpenPreferencesWithSpecificCategory() async throws {
        var receivedCategory: SettingsCategory?

        viewModel.onOpenPreferences = { category in
            receivedCategory = category
        }

        viewModel.openPreferences(category: .advanced)

        XCTAssertEqual(receivedCategory, .advanced, "Should pass the specified category")
    }

    func testOpenPreferencesWithStorageCategory() async throws {
        var receivedCategory: SettingsCategory?

        viewModel.onOpenPreferences = { category in
            receivedCategory = category
        }

        viewModel.openPreferences(category: .storage)

        XCTAssertEqual(receivedCategory, .storage, "Should pass .storage category")
    }

    func testOpenPreferencesWithAboutCategory() async throws {
        var receivedCategory: SettingsCategory?

        viewModel.onOpenPreferences = { category in
            receivedCategory = category
        }

        viewModel.openPreferences(category: .about)

        XCTAssertEqual(receivedCategory, .about, "Should pass .about category")
    }

    func testOpenPreferencesWithNoCallbackDoesNotCrash() async throws {
        // Ensure no callback is set
        viewModel.onOpenPreferences = nil

        // This should not crash
        viewModel.openPreferences()
        viewModel.openPreferences(category: .advanced)

        // If we get here, the test passed
        XCTAssertTrue(true)
    }

    func testOpenPreferencesCallbackCalledOnce() async throws {
        var callCount = 0

        viewModel.onOpenPreferences = { _ in
            callCount += 1
        }

        viewModel.openPreferences()

        XCTAssertEqual(callCount, 1, "Callback should be called exactly once")
    }

    func testMultipleOpenPreferencesCalls() async throws {
        var categories: [SettingsCategory] = []

        viewModel.onOpenPreferences = { category in
            categories.append(category)
        }

        viewModel.openPreferences(category: .general)
        viewModel.openPreferences(category: .advanced)
        viewModel.openPreferences(category: .storage)

        XCTAssertEqual(categories.count, 3, "Should have received 3 callbacks")
        XCTAssertEqual(categories[0], .general)
        XCTAssertEqual(categories[1], .advanced)
        XCTAssertEqual(categories[2], .storage)
    }

    // MARK: - Integration with closeWindow

    func testOpenPreferencesDoesNotCallCloseWindow() async throws {
        var closeWindowCalled = false
        var openPreferencesCalled = false

        viewModel.onCloseWindow = {
            closeWindowCalled = true
        }

        viewModel.onOpenPreferences = { _ in
            openPreferencesCalled = true
        }

        viewModel.openPreferences()

        XCTAssertTrue(openPreferencesCalled, "onOpenPreferences should be called")
        XCTAssertFalse(closeWindowCalled, "onCloseWindow should NOT be called by openPreferences")
    }

    func testCloseWindowDoesNotCallOpenPreferences() async throws {
        var closeWindowCalled = false
        var openPreferencesCalled = false

        viewModel.onCloseWindow = {
            closeWindowCalled = true
        }

        viewModel.onOpenPreferences = { _ in
            openPreferencesCalled = true
        }

        viewModel.closeWindow()

        XCTAssertTrue(closeWindowCalled, "onCloseWindow should be called")
        XCTAssertFalse(openPreferencesCalled, "onOpenPreferences should NOT be called by closeWindow")
    }
}
