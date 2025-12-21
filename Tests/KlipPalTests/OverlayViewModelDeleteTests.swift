import XCTest
@testable import KlipPal

@MainActor
final class OverlayViewModelDeleteTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var viewModel: OverlayViewModel!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_delete_\(UUID().uuidString).db").path
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

    func testDeleteItemRemovesFromStorage() async throws {
        // Create and save test items
        let item1 = ClipboardItem(
            content: "Item to keep",
            contentType: .text,
            contentHash: "keep123"
        )
        let item2 = ClipboardItem(
            content: "Item to delete",
            contentType: .text,
            contentHash: "delete123"
        )

        try await storage.save(item1)
        try await storage.save(item2)

        // Load items into view model
        viewModel.loadItems()

        // Wait for async load
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.filteredItems.count, 2)

        // Delete item2
        viewModel.deleteItem(item2)

        // Wait for async delete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify item is removed from view model
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.items.first?.content, "Item to keep")

        // Verify item is removed from storage
        let storedItems = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(storedItems.count, 1)
        XCTAssertEqual(storedItems.first?.content, "Item to keep")
    }

    func testDeleteItemAdjustsSelectedIndex() async throws {
        // Create and save multiple items
        let items = (0..<5).map { i in
            ClipboardItem(
                content: "Item \(i)",
                contentType: .text,
                contentHash: "hash\(i)"
            )
        }

        for item in items {
            try await storage.save(item)
        }

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Set selected index to last item
        viewModel.selectedIndex = 4

        // Delete the last item
        if let lastItem = viewModel.filteredItems.last {
            viewModel.deleteItem(lastItem)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        // Selected index should be adjusted to stay in bounds
        XCTAssertEqual(viewModel.filteredItems.count, 4)
        XCTAssertLessThan(viewModel.selectedIndex, viewModel.filteredItems.count)
    }

    func testDeleteItemFromFilteredList() async throws {
        // Create items with different content
        let item1 = ClipboardItem(
            content: "Apple pie",
            contentType: .text,
            contentHash: "apple123"
        )
        let item2 = ClipboardItem(
            content: "Banana bread",
            contentType: .text,
            contentHash: "banana123"
        )
        let item3 = ClipboardItem(
            content: "Apple sauce",
            contentType: .text,
            contentHash: "sauce123"
        )

        try await storage.save(item1)
        try await storage.save(item2)
        try await storage.save(item3)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Search for "Apple"
        viewModel.search(query: "Apple")

        // Should have 2 items in filtered list
        XCTAssertEqual(viewModel.filteredItems.count, 2)

        // Delete one of the filtered items
        if let appleItem = viewModel.filteredItems.first(where: { $0.content == "Apple pie" }) {
            viewModel.deleteItem(appleItem)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify deletion from both items and filteredItems
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertFalse(viewModel.items.contains { $0.content == "Apple pie" })
    }

    func testDeleteAllItemsResetsSelectedIndex() async throws {
        let item = ClipboardItem(
            content: "Only item",
            contentType: .text,
            contentHash: "only123"
        )

        try await storage.save(item)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        viewModel.selectedIndex = 0
        viewModel.deleteItem(item)

        try await Task.sleep(nanoseconds: 100_000_000)

        // With no items, selected index should be 0
        XCTAssertEqual(viewModel.filteredItems.count, 0)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }
}
