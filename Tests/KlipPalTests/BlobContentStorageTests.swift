import XCTest
import AppKit
@testable import KlipPal

/// Tests for storing blob content directly in the database
final class BlobContentStorageTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_blob_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - Tests for blob_content column

    func testSaveAndFetchImageWithBlobContent() async throws {
        // Create test image data
        let imageData = createTestImageData(width: 100, height: 100, color: .red)

        // Create clipboard item with blob content
        let item = ClipboardItem(
            content: "[Image 100x100]",
            contentType: .image,
            contentHash: "image_hash_123",
            sourceApp: "TestApp",
            blobContent: imageData
        )

        // Save item
        try await storage.save(item)

        // Fetch items
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false, includeContent: true)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.contentType, .image)
        XCTAssertNotNil(items.first?.blobContent, "Blob content should be retrieved")
        XCTAssertEqual(items.first?.blobContent, imageData, "Blob content should match original")
    }

    func testSaveItemWithNoBlobContent() async throws {
        // Create text item without blob content
        let item = ClipboardItem(
            content: "Just text",
            contentType: .text,
            contentHash: "text_hash_123"
        )

        try await storage.save(item)

        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false, includeContent: true)

        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items.first?.blobContent, "Text items should have nil blob content")
    }

    func testUpdateItemPreservesBlobContent() async throws {
        // Create image item
        let imageData = createTestImageData(width: 50, height: 50, color: .blue)
        var item = ClipboardItem(
            content: "[Image 50x50]",
            contentType: .image,
            contentHash: "update_test_hash",
            blobContent: imageData
        )

        // Save initial item
        try await storage.save(item)

        // Update favorite status
        item.isFavorite = true
        try await storage.save(item)

        // Fetch and verify
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false, includeContent: true)
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.first!.isFavorite)
        XCTAssertEqual(items.first?.blobContent, imageData, "Blob content should be preserved after update")
    }

    func testLargeImageBlobContent() async throws {
        // Create a larger image (500x500)
        let imageData = createTestImageData(width: 500, height: 500, color: .green)

        let item = ClipboardItem(
            content: "[Image 500x500]",
            contentType: .image,
            contentHash: "large_image_hash",
            blobContent: imageData
        )

        try await storage.save(item)

        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false, includeContent: true)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.blobContent?.count, imageData.count)
    }

    func testFetchItemByIdWithBlobContent() async throws {
        let imageData = createTestImageData(width: 80, height: 80, color: .purple)
        let item = ClipboardItem(
            content: "[Image 80x80]",
            contentType: .image,
            contentHash: "fetch_by_id_hash",
            blobContent: imageData
        )

        try await storage.save(item)

        let fetchedItem = try await storage.fetchItem(byId: item.id)

        XCTAssertNotNil(fetchedItem)
        XCTAssertEqual(fetchedItem?.blobContent, imageData)
    }

    func testDeleteItemRemovesBlobContent() async throws {
        let imageData = createTestImageData(width: 60, height: 60, color: .orange)
        let item = ClipboardItem(
            content: "[Image 60x60]",
            contentType: .image,
            contentHash: "delete_blob_hash",
            blobContent: imageData
        )

        try await storage.save(item)

        // Verify saved
        var count = try await storage.count()
        XCTAssertEqual(count, 1)

        // Delete
        try await storage.delete(item)

        // Verify deleted
        count = try await storage.count()
        XCTAssertEqual(count, 0)
    }

    func testCanRecreateImageFromBlobContent() async throws {
        // Create original image
        let originalImage = createTestImage(width: 100, height: 100, color: .cyan)
        guard let tiffData = originalImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG data")
            return
        }

        let item = ClipboardItem(
            content: "[Image 100x100]",
            contentType: .image,
            contentHash: "recreate_hash",
            blobContent: pngData
        )

        try await storage.save(item)

        // Fetch and recreate image
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false, includeContent: true)
        guard let blobContent = items.first?.blobContent else {
            XCTFail("No blob content returned")
            return
        }

        let recreatedImage = NSImage(data: blobContent)
        XCTAssertNotNil(recreatedImage, "Should be able to recreate NSImage from blob content")
    }

    // MARK: - Helper Methods

    private func createTestImage(width: Int, height: Int, color: NSColor) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)

        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        return image
    }

    private func createTestImageData(width: Int, height: Int, color: NSColor) -> Data {
        let image = createTestImage(width: width, height: height, color: color)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Failed to create test image data")
        }
        return pngData
    }
}
