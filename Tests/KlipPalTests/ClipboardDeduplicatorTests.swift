import XCTest
@testable import KlipPal

/// Tests for ClipboardDeduplicator - handles detection of duplicate clipboard items
final class ClipboardDeduplicatorTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var deduplicator: ClipboardDeduplicator!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_dedup_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)
        deduplicator = ClipboardDeduplicator(storage: storage)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - Text Content Tests

    func testShouldSaveNewTextContent() async throws {
        let content = "Hello, World!"

        let hash = await deduplicator.shouldSave(content: content)

        XCTAssertNotNil(hash, "Should return hash for new content")
        XCTAssertFalse(hash!.isEmpty, "Hash should not be empty")
    }

    func testShouldNotSaveDuplicateTextContent() async throws {
        let content = "Duplicate content"

        // First, get the hash and save an item with it
        let hash = await deduplicator.shouldSave(content: content)
        XCTAssertNotNil(hash)

        // Save the item to storage
        let item = ClipboardItem(
            content: content,
            contentType: .text,
            contentHash: hash!
        )
        try await storage.save(item)

        // Now try to save the same content again
        let duplicateHash = await deduplicator.shouldSave(content: content)

        XCTAssertNil(duplicateHash, "Should return nil for duplicate content")
    }

    func testDifferentContentReturnsDifferentHash() async throws {
        let content1 = "First content"
        let content2 = "Second content"

        let hash1 = await deduplicator.shouldSave(content: content1)
        let hash2 = await deduplicator.shouldSave(content: content2)

        XCTAssertNotNil(hash1)
        XCTAssertNotNil(hash2)
        XCTAssertNotEqual(hash1, hash2, "Different content should produce different hashes")
    }

    func testSameContentReturnsSameHash() async throws {
        let content = "Same content"

        let hash1 = await deduplicator.shouldSave(content: content)
        let hash2 = await deduplicator.shouldSave(content: content)

        // Note: Both return non-nil because nothing is in storage yet
        XCTAssertNotNil(hash1)
        XCTAssertNotNil(hash2)
        XCTAssertEqual(hash1, hash2, "Same content should produce same hash")
    }

    // MARK: - Image Data Tests

    func testShouldSaveNewImageData() async throws {
        let imageData = createTestImageData()

        let hash = await deduplicator.shouldSave(content: "", imageData: imageData)

        XCTAssertNotNil(hash, "Should return hash for new image data")
        XCTAssertFalse(hash!.isEmpty, "Hash should not be empty")
    }

    func testShouldNotSaveDuplicateImageData() async throws {
        let imageData = createTestImageData()

        // First, get the hash and save an item with it
        let hash = await deduplicator.shouldSave(content: "", imageData: imageData)
        XCTAssertNotNil(hash)

        // Save the item to storage
        let item = ClipboardItem(
            content: "[Image]",
            contentType: .image,
            contentHash: hash!
        )
        try await storage.save(item)

        // Now try to save the same image again
        let duplicateHash = await deduplicator.shouldSave(content: "", imageData: imageData)

        XCTAssertNil(duplicateHash, "Should return nil for duplicate image data")
    }

    func testDifferentImageDataReturnsDifferentHash() async throws {
        let imageData1 = createTestImageData(seed: 1)
        let imageData2 = createTestImageData(seed: 2)

        let hash1 = await deduplicator.shouldSave(content: "", imageData: imageData1)
        let hash2 = await deduplicator.shouldSave(content: "", imageData: imageData2)

        XCTAssertNotNil(hash1)
        XCTAssertNotNil(hash2)
        XCTAssertNotEqual(hash1, hash2, "Different images should produce different hashes")
    }

    // MARK: - Edge Cases

    func testEmptyContentReturnsHash() async throws {
        let hash = await deduplicator.shouldSave(content: "")

        XCTAssertNotNil(hash, "Empty content should still return a hash")
    }

    func testWhitespaceContentReturnsHash() async throws {
        let hash = await deduplicator.shouldSave(content: "   ")

        XCTAssertNotNil(hash, "Whitespace content should return a hash")
    }

    func testWhitespaceIsDifferentFromEmpty() async throws {
        let emptyHash = await deduplicator.shouldSave(content: "")
        let whitespaceHash = await deduplicator.shouldSave(content: "   ")

        XCTAssertNotNil(emptyHash)
        XCTAssertNotNil(whitespaceHash)
        XCTAssertNotEqual(emptyHash, whitespaceHash, "Empty and whitespace should have different hashes")
    }

    func testVeryLongContentReturnsHash() async throws {
        let longContent = String(repeating: "a", count: 100_000)

        let hash = await deduplicator.shouldSave(content: longContent)

        XCTAssertNotNil(hash, "Long content should return a hash")
        XCTAssertEqual(hash!.count, 64, "SHA256 hash should be 64 characters")
    }

    func testUnicodeContentReturnsHash() async throws {
        let unicodeContent = "Hello 👋 World 🌍 日本語 中文"

        let hash = await deduplicator.shouldSave(content: unicodeContent)

        XCTAssertNotNil(hash, "Unicode content should return a hash")
    }

    func testNewlineContentReturnsHash() async throws {
        let multilineContent = "Line 1\nLine 2\nLine 3"

        let hash = await deduplicator.shouldSave(content: multilineContent)

        XCTAssertNotNil(hash, "Multiline content should return a hash")
    }

    // MARK: - Performance Tests

    func testDeduplicationPerformance() async throws {
        // Pre-populate storage with 100 items
        for i in 0..<100 {
            let item = ClipboardItem(
                content: "Content \(i)",
                contentType: .text,
                contentHash: SHA256Hasher.hash(string: "Content \(i)")
            )
            try await storage.save(item)
        }

        // Measure deduplication check time
        let start = CFAbsoluteTimeGetCurrent()

        for _ in 0..<100 {
            _ = await deduplicator.shouldSave(content: "New unique content \(UUID())")
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000 // ms

        // Should complete 100 checks in reasonable time
        XCTAssertLessThan(elapsed, 1000, "100 deduplication checks should complete in under 1 second, took \(elapsed)ms")
    }

    // MARK: - Helper Methods

    private func createTestImageData(seed: Int = 0) -> Data {
        // Create simple pseudo-random data that varies by seed
        var data = Data()
        for i in 0..<1000 {
            data.append(UInt8((i + seed * 100) % 256))
        }
        return data
    }
}

// MARK: - Integration Tests

final class ClipboardDeduplicatorIntegrationTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var deduplicator: ClipboardDeduplicator!
    var tempDBPath: String!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_dedup_int_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)
        deduplicator = ClipboardDeduplicator(storage: storage)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    func testFullDeduplicationWorkflow() async throws {
        // Simulate clipboard monitoring workflow
        let content1 = "First clipboard content"
        let content2 = "Second clipboard content"

        // First copy - should be saved
        if let hash1 = await deduplicator.shouldSave(content: content1) {
            let item1 = ClipboardItem(
                content: content1,
                contentType: .text,
                contentHash: hash1
            )
            try await storage.save(item1)
        }

        // Different content - should be saved
        if let hash2 = await deduplicator.shouldSave(content: content2) {
            let item2 = ClipboardItem(
                content: content2,
                contentType: .text,
                contentHash: hash2
            )
            try await storage.save(item2)
        }

        // Duplicate of first - should NOT be saved
        let duplicateHash = await deduplicator.shouldSave(content: content1)
        XCTAssertNil(duplicateHash, "Duplicate content should not be saved")

        // Verify storage has exactly 2 items
        let count = try await storage.count()
        XCTAssertEqual(count, 2, "Should have exactly 2 items in storage")
    }

    func testDeduplicationAfterDelete() async throws {
        let content = "Deletable content"

        // Save item
        let hash = await deduplicator.shouldSave(content: content)
        XCTAssertNotNil(hash)

        let item = ClipboardItem(
            content: content,
            contentType: .text,
            contentHash: hash!
        )
        try await storage.save(item)

        // Delete item
        try await storage.delete(item)

        // Same content should now be saveable again
        let newHash = await deduplicator.shouldSave(content: content)
        XCTAssertNotNil(newHash, "Content should be saveable after original was deleted")
        XCTAssertEqual(hash, newHash, "Hash should be the same for same content")
    }

    func testDeduplicationWithMixedContentTypes() async throws {
        let textContent = "Some text"
        let imageData = Data([0x01, 0x02, 0x03, 0x04])

        // Save text
        if let textHash = await deduplicator.shouldSave(content: textContent) {
            let textItem = ClipboardItem(
                content: textContent,
                contentType: .text,
                contentHash: textHash
            )
            try await storage.save(textItem)
        }

        // Save image with different hash
        if let imageHash = await deduplicator.shouldSave(content: "", imageData: imageData) {
            let imageItem = ClipboardItem(
                content: "[Image]",
                contentType: .image,
                contentHash: imageHash
            )
            try await storage.save(imageItem)
        }

        // Both duplicates should be detected
        let textDuplicate = await deduplicator.shouldSave(content: textContent)
        let imageDuplicate = await deduplicator.shouldSave(content: "", imageData: imageData)

        XCTAssertNil(textDuplicate, "Text duplicate should be detected")
        XCTAssertNil(imageDuplicate, "Image duplicate should be detected")

        let count = try await storage.count()
        XCTAssertEqual(count, 2, "Should have exactly 2 items")
    }

    func testCheckContentReturnsNewForNewContent() async throws {
        let content = "Brand new content"

        let result = await deduplicator.checkContent(content: content)

        if case .newContent(let hash) = result {
            XCTAssertFalse(hash.isEmpty, "Hash should not be empty")
        } else {
            XCTFail("Should return newContent for new content")
        }
    }

    func testCheckContentReturnsDuplicateForExistingContent() async throws {
        let content = "Existing content"

        // First, save the content
        let firstResult = await deduplicator.checkContent(content: content)
        guard case .newContent(let hash) = firstResult else {
            XCTFail("First check should return newContent")
            return
        }

        let item = ClipboardItem(
            content: content,
            contentType: .text,
            contentHash: hash
        )
        try await storage.save(item)

        // Now check again - should return duplicate
        let secondResult = await deduplicator.checkContent(content: content)

        if case .duplicate(let duplicateHash) = secondResult {
            XCTAssertEqual(duplicateHash, hash, "Duplicate hash should match original")
        } else {
            XCTFail("Should return duplicate for existing content")
        }
    }

    func testUpdateTimestampBringsItemToTop() async throws {
        // Save two items with different timestamps
        let oldContent = "Old content"
        let newContent = "New content"

        // Save old content first
        let oldHash = SHA256Hasher.hash(string: oldContent)
        let oldItem = ClipboardItem(
            id: UUID(),
            content: oldContent,
            contentType: .text,
            contentHash: oldHash,
            timestamp: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        try await storage.save(oldItem)

        // Save new content
        let newHash = SHA256Hasher.hash(string: newContent)
        let newItem = ClipboardItem(
            id: UUID(),
            content: newContent,
            contentType: .text,
            contentHash: newHash,
            timestamp: Date()
        )
        try await storage.save(newItem)

        // Verify new content is first
        var items = try await storage.fetchItems(limit: 10, favoriteOnly: false)
        XCTAssertEqual(items.first?.content, newContent, "New content should be first initially")

        // Update timestamp for old content (simulating re-copy)
        try await storage.updateTimestamp(forHash: oldHash)

        // Now old content should be first (since its timestamp was just updated)
        items = try await storage.fetchItems(limit: 10, favoriteOnly: false)
        XCTAssertEqual(items.first?.content, oldContent, "Old content should be first after timestamp update")
    }
}
