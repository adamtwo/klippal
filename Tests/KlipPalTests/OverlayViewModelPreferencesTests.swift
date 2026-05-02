import XCTest
@testable import KlipPal

@MainActor
final class OverlayViewModelPreferencesTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var viewModel: OverlayViewModel!
    var tempDBPath: String!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_prefs_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

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

    func testOpenPreferencesStorageFiresCallbackWithStorageCategory() {
        var receivedCategory: SettingsCategory?
        viewModel.onOpenPreferences = { receivedCategory = $0 }

        viewModel.openPreferences(category: .storage)

        XCTAssertEqual(receivedCategory, .storage)
    }

    func testOpenPreferencesDefaultCategoryIsGeneral() {
        var receivedCategory: SettingsCategory?
        viewModel.onOpenPreferences = { receivedCategory = $0 }

        viewModel.openPreferences()

        XCTAssertEqual(receivedCategory, .general)
    }

    func testOpenPreferencesWithNoCallbackDoesNotCrash() {
        viewModel.onOpenPreferences = nil
        viewModel.openPreferences(category: .storage)
    }
}
