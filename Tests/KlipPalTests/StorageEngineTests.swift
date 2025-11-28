import XCTest
@testable import KlipPal

final class StorageEngineTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)
    }

    override func tearDown() async throws {
        // Clean up temporary database
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    func testSaveAndFetchItem() async throws {
        // Create test item
        let item = ClipboardItem(
            content: "Test content",
            contentType: .text,
            contentHash: "abc123",
            sourceApp: "TestApp"
        )

        // Save item
        try await storage.save(item)

        // Fetch items
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Test content")
        XCTAssertEqual(items.first?.contentType, .text)
        XCTAssertEqual(items.first?.sourceApp, "TestApp")
    }

    func testDuplicateHashPrevention() async throws {
        let hash = "duplicate123"

        // Create two items with same hash
        let item1 = ClipboardItem(
            content: "First",
            contentType: .text,
            contentHash: hash
        )

        let item2 = ClipboardItem(
            content: "Second",
            contentType: .text,
            contentHash: hash
        )

        // Save both
        try await storage.save(item1)
        try await storage.save(item2)

        // Should only have one item (second replaces first)
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Second")
    }

    func testItemExists() async throws {
        let hash = "exists123"
        let item = ClipboardItem(
            content: "Test",
            contentType: .text,
            contentHash: hash
        )

        // Initially should not exist
        let existsBefore = try await storage.itemExists(withHash: hash)
        XCTAssertFalse(existsBefore)

        // Save item
        try await storage.save(item)

        // Now should exist
        let existsAfter = try await storage.itemExists(withHash: hash)
        XCTAssertTrue(existsAfter)
    }

    func testDeleteItem() async throws {
        let item = ClipboardItem(
            content: "To delete",
            contentType: .text,
            contentHash: "delete123"
        )

        // Save and verify
        try await storage.save(item)
        var count = try await storage.count()
        XCTAssertEqual(count, 1)

        // Delete
        try await storage.delete(item)

        // Verify deleted
        count = try await storage.count()
        XCTAssertEqual(count, 0)
    }

    func testDeleteOlderThan() async throws {
        // Create old item (31 days ago)
        let oldDate = Date().addingTimeInterval(-31 * 24 * 60 * 60)
        let oldItem = ClipboardItem(
            content: "Old",
            contentType: .text,
            contentHash: "old123",
            timestamp: oldDate
        )

        // Create recent item
        let recentItem = ClipboardItem(
            content: "Recent",
            contentType: .text,
            contentHash: "recent123"
        )

        // Save both
        try await storage.save(oldItem)
        try await storage.save(recentItem)

        // Delete items older than 30 days
        try await storage.deleteOlderThan(days: 30)

        // Should only have recent item
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Recent")
    }

    func testFavoriteItemsNotDeleted() async throws {
        // Create old favorite item
        let oldDate = Date().addingTimeInterval(-31 * 24 * 60 * 60)
        var favoriteItem = ClipboardItem(
            content: "Favorite",
            contentType: .text,
            contentHash: "fav123",
            timestamp: oldDate
        )
        favoriteItem.isFavorite = true

        // Save
        try await storage.save(favoriteItem)

        // Delete old items
        try await storage.deleteOlderThan(days: 30)

        // Favorite should still exist
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Favorite")
    }
}
