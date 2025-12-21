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

    // MARK: - Update Timestamp Tests

    func testUpdateTimestamp() async throws {
        // Create item with old timestamp
        let oldDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let hash = "timestamp123"
        let item = ClipboardItem(
            content: "Test content",
            contentType: .text,
            contentHash: hash,
            timestamp: oldDate
        )

        // Save item
        try await storage.save(item)

        // Verify initial timestamp
        var items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 1)
        let initialTimestamp = items.first!.timestamp

        // Wait a tiny bit to ensure timestamp difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Update timestamp
        try await storage.updateTimestamp(forHash: hash)

        // Fetch again and verify timestamp was updated
        items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 1)
        let updatedTimestamp = items.first!.timestamp

        XCTAssertGreaterThan(updatedTimestamp, initialTimestamp, "Timestamp should be updated to a newer time")
    }

    func testUpdateTimestampBringsItemToTop() async throws {
        // Create two items - older one first
        let oldDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let oldItem = ClipboardItem(
            content: "Old item",
            contentType: .text,
            contentHash: "old_hash",
            timestamp: oldDate
        )

        let newItem = ClipboardItem(
            content: "New item",
            contentType: .text,
            contentHash: "new_hash",
            timestamp: Date()
        )

        // Save both items
        try await storage.save(oldItem)
        try await storage.save(newItem)

        // Verify new item is first (most recent)
        var items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.content, "New item")

        // Update timestamp of old item
        try await storage.updateTimestamp(forHash: "old_hash")

        // Now old item should be first (its timestamp is now the most recent)
        items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.content, "Old item", "Old item should now be first after timestamp update")
    }

    func testUpdateTimestampForNonExistentHash() async throws {
        // This should not throw - just silently do nothing
        try await storage.updateTimestamp(forHash: "nonexistent_hash")

        // Verify no items were affected
        let count = try await storage.count()
        XCTAssertEqual(count, 0)
    }

    func testUpdateTimestampPreservesOtherFields() async throws {
        // Create item with all fields populated
        let hash = "preserve_fields_hash"
        let testBlobContent = Data([0x01, 0x02, 0x03, 0x04])
        var item = ClipboardItem(
            content: "Test content",
            contentType: .url,
            contentHash: hash,
            sourceApp: "Safari",
            blobContent: testBlobContent
        )
        item.isFavorite = true

        // Save item
        try await storage.save(item)

        // Update timestamp
        try await storage.updateTimestamp(forHash: hash)

        // Fetch and verify all other fields are preserved
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 1)
        let updatedItem = items.first!

        XCTAssertEqual(updatedItem.content, "Test content")
        XCTAssertEqual(updatedItem.contentType, .url)
        XCTAssertEqual(updatedItem.contentHash, hash)
        XCTAssertEqual(updatedItem.sourceApp, "Safari")
        XCTAssertEqual(updatedItem.blobContent, testBlobContent)
        XCTAssertTrue(updatedItem.isFavorite)
    }
}
