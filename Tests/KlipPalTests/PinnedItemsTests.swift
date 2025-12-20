import XCTest
@testable import KlipPal

@MainActor
final class PinnedItemsTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var viewModel: OverlayViewModel!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_pinned_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Set up AppDelegate.shared for ViewModel to use
        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        AppDelegate.shared = appDelegate

        viewModel = OverlayViewModel(storage: storage, blobStorage: nil)
    }

    override func tearDown() async throws {
        viewModel = nil
        storage = nil
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - Toggle Favorite Tests

    func testToggleFavoriteUpdatesFavoriteStatus() async throws {
        // Create and save a non-favorite item
        let item = ClipboardItem(
            content: "Test item",
            contentType: .text,
            contentHash: "test123",
            isFavorite: false
        )
        try await storage.save(item)

        // Load items into view model
        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertFalse(viewModel.items[0].isFavorite)

        // Toggle favorite
        viewModel.toggleFavorite(viewModel.items[0])
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify item is now favorite in view model
        XCTAssertTrue(viewModel.items[0].isFavorite)

        // Verify item is favorite in storage
        let storedItems = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertTrue(storedItems[0].isFavorite)
    }

    func testToggleFavoriteCanUnpin() async throws {
        // Create and save a favorite item
        let item = ClipboardItem(
            content: "Pinned item",
            contentType: .text,
            contentHash: "pinned123",
            isFavorite: true
        )
        try await storage.save(item)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.items[0].isFavorite)

        // Toggle to unpin
        viewModel.toggleFavorite(viewModel.items[0])
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify item is no longer favorite
        XCTAssertFalse(viewModel.items[0].isFavorite)
    }

    // MARK: - Pinned Only Mode Tests

    func testShowingPinnedOnlyFiltersItems() async throws {
        // Create mix of pinned and non-pinned items
        let pinnedItem = ClipboardItem(
            content: "Pinned item",
            contentType: .text,
            contentHash: "pinned1",
            isFavorite: true
        )
        let regularItem = ClipboardItem(
            content: "Regular item",
            contentType: .text,
            contentHash: "regular1",
            isFavorite: false
        )

        try await storage.save(pinnedItem)
        try await storage.save(regularItem)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Initially shows all items
        XCTAssertEqual(viewModel.filteredItems.count, 2)

        // Switch to pinned only mode
        viewModel.setShowingPinnedOnly(true)

        // Should only show pinned item
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].content, "Pinned item")
    }

    func testSwitchingBackFromPinnedOnlyShowsAllItems() async throws {
        let pinnedItem = ClipboardItem(
            content: "Pinned",
            contentType: .text,
            contentHash: "pin1",
            isFavorite: true
        )
        let regularItem = ClipboardItem(
            content: "Regular",
            contentType: .text,
            contentHash: "reg1",
            isFavorite: false
        )

        try await storage.save(pinnedItem)
        try await storage.save(regularItem)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Switch to pinned only
        viewModel.setShowingPinnedOnly(true)
        XCTAssertEqual(viewModel.filteredItems.count, 1)

        // Switch back to all items
        viewModel.setShowingPinnedOnly(false)
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }

    func testPinnedCountReturnsCorrectNumber() async throws {
        let pinned1 = ClipboardItem(
            content: "Pinned 1",
            contentType: .text,
            contentHash: "p1",
            isFavorite: true
        )
        let pinned2 = ClipboardItem(
            content: "Pinned 2",
            contentType: .text,
            contentHash: "p2",
            isFavorite: true
        )
        let regular = ClipboardItem(
            content: "Regular",
            contentType: .text,
            contentHash: "r1",
            isFavorite: false
        )

        try await storage.save(pinned1)
        try await storage.save(pinned2)
        try await storage.save(regular)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.pinnedCount, 2)
    }

    // MARK: - Search with Pinned Items Tests

    func testSearchIncludesPinnedItemsByTimestamp() async throws {
        // Create items with different timestamps
        let now = Date()

        let oldPinned = ClipboardItem(
            id: UUID(),
            content: "Old pinned apple",
            contentType: .text,
            contentHash: "oldpin",
            timestamp: now.addingTimeInterval(-3600), // 1 hour ago
            isFavorite: true
        )
        let recentRegular = ClipboardItem(
            id: UUID(),
            content: "Recent regular apple",
            contentType: .text,
            contentHash: "recent",
            timestamp: now.addingTimeInterval(-60), // 1 minute ago
            isFavorite: false
        )
        let oldRegular = ClipboardItem(
            id: UUID(),
            content: "Old regular apple",
            contentType: .text,
            contentHash: "oldreg",
            timestamp: now.addingTimeInterval(-7200), // 2 hours ago
            isFavorite: false
        )

        try await storage.save(oldPinned)
        try await storage.save(recentRegular)
        try await storage.save(oldRegular)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Search for "apple"
        viewModel.search(query: "apple")

        // All three items should appear in search results
        XCTAssertEqual(viewModel.filteredItems.count, 3)

        // Items should be ordered by timestamp (most recent first)
        // recentRegular (1 min ago) > oldPinned (1 hour ago) > oldRegular (2 hours ago)
        XCTAssertEqual(viewModel.filteredItems[0].content, "Recent regular apple")
        XCTAssertEqual(viewModel.filteredItems[1].content, "Old pinned apple")
        XCTAssertEqual(viewModel.filteredItems[2].content, "Old regular apple")
    }

    func testSearchRespectssPinnedOnlyMode() async throws {
        let pinnedItem = ClipboardItem(
            content: "Pinned item",
            contentType: .text,
            contentHash: "pin1",
            isFavorite: true
        )
        let regularItem = ClipboardItem(
            content: "Regular item",
            contentType: .text,
            contentHash: "reg1",
            isFavorite: false
        )

        try await storage.save(pinnedItem)
        try await storage.save(regularItem)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Enable pinned only mode
        viewModel.setShowingPinnedOnly(true)
        XCTAssertEqual(viewModel.filteredItems.count, 1)

        // Search should only search within pinned items when in pinned mode
        viewModel.search(query: "item")
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems[0].content, "Pinned item")

        // Switch to history mode - search should find both
        viewModel.setShowingPinnedOnly(false)
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }

    // MARK: - Items Ordered By Timestamp Tests

    func testItemsOrderedByTimestampNotFavoriteFirst() async throws {
        let now = Date()

        // Create items with different timestamps - pinned item is older
        let oldPinnedItem = ClipboardItem(
            id: UUID(),
            content: "Old pinned",
            contentType: .text,
            contentHash: "oldpin",
            timestamp: now.addingTimeInterval(-3600), // 1 hour ago
            isFavorite: true
        )
        let recentRegularItem = ClipboardItem(
            id: UUID(),
            content: "Recent regular",
            contentType: .text,
            contentHash: "recent",
            timestamp: now.addingTimeInterval(-60), // 1 minute ago
            isFavorite: false
        )
        let oldRegularItem = ClipboardItem(
            id: UUID(),
            content: "Old regular",
            contentType: .text,
            contentHash: "oldreg",
            timestamp: now.addingTimeInterval(-7200), // 2 hours ago
            isFavorite: false
        )

        try await storage.save(oldPinnedItem)
        try await storage.save(recentRegularItem)
        try await storage.save(oldRegularItem)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Items should be ordered by timestamp, not favorites first
        // recentRegular (1 min ago) > oldPinned (1 hour ago) > oldRegular (2 hours ago)
        XCTAssertEqual(viewModel.items.count, 3)
        XCTAssertEqual(viewModel.items[0].content, "Recent regular")
        XCTAssertEqual(viewModel.items[1].content, "Old pinned")
        XCTAssertEqual(viewModel.items[2].content, "Old regular")
    }

    func testStorageFetchesItemsByTimestamp() async throws {
        let now = Date()

        let pinnedOld = ClipboardItem(
            id: UUID(),
            content: "Pinned old",
            contentType: .text,
            contentHash: "pold",
            timestamp: now.addingTimeInterval(-1000),
            isFavorite: true
        )
        let regularNew = ClipboardItem(
            id: UUID(),
            content: "Regular new",
            contentType: .text,
            contentHash: "rnew",
            timestamp: now,
            isFavorite: false
        )

        try await storage.save(pinnedOld)
        try await storage.save(regularNew)

        // Fetch all items - should be ordered by timestamp
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].content, "Regular new") // Most recent first
        XCTAssertEqual(items[1].content, "Pinned old")
    }

    // MARK: - Toggle Favorite Updates Filtered Items Tests

    func testToggleFavoriteUpdatesFilteredItems() async throws {
        let item = ClipboardItem(
            content: "Test item",
            contentType: .text,
            contentHash: "test1",
            isFavorite: false
        )

        try await storage.save(item)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Enable pinned only mode - should be empty
        viewModel.setShowingPinnedOnly(true)
        XCTAssertEqual(viewModel.filteredItems.count, 0)

        // Go back to all items and pin the item
        viewModel.setShowingPinnedOnly(false)
        viewModel.toggleFavorite(viewModel.items[0])
        try await Task.sleep(nanoseconds: 100_000_000)

        // Now pinned only mode should show the item
        viewModel.setShowingPinnedOnly(true)
        XCTAssertEqual(viewModel.filteredItems.count, 1)
    }
}
