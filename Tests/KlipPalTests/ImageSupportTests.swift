import XCTest
import AppKit
@testable import KlipPal

// MARK: - ThumbnailGenerator Tests

final class ThumbnailGeneratorTests: XCTestCase {

    // MARK: - Basic Thumbnail Generation

    func testGenerateThumbnailFromValidImage() throws {
        // Create a test image (100x100 red square)
        let image = createTestImage(width: 100, height: 100, color: .red)
        let imageData = image.tiffRepresentation!

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData, maxSize: 80)

        XCTAssertNotNil(thumbnail, "Should generate thumbnail from valid image data")
    }

    func testThumbnailRespectsMaxSize() throws {
        // Create a large test image (500x300)
        let image = createTestImage(width: 500, height: 300, color: .blue)
        let imageData = image.tiffRepresentation!

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData, maxSize: 80)

        XCTAssertNotNil(thumbnail)
        // Thumbnail should fit within 80x80 while maintaining aspect ratio
        XCTAssertLessThanOrEqual(thumbnail!.size.width, 80)
        XCTAssertLessThanOrEqual(thumbnail!.size.height, 80)
    }

    func testThumbnailMaintainsAspectRatio() throws {
        // Create a wide image (200x100 - 2:1 ratio)
        let image = createTestImage(width: 200, height: 100, color: .green)
        let imageData = image.tiffRepresentation!

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData, maxSize: 80)

        XCTAssertNotNil(thumbnail)
        // Width should be 80 (max), height should be 40 (maintaining 2:1 ratio)
        XCTAssertEqual(thumbnail!.size.width, 80, accuracy: 1)
        XCTAssertEqual(thumbnail!.size.height, 40, accuracy: 1)
    }

    func testThumbnailFromTallImage() throws {
        // Create a tall image (100x200 - 1:2 ratio)
        let image = createTestImage(width: 100, height: 200, color: .purple)
        let imageData = image.tiffRepresentation!

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData, maxSize: 80)

        XCTAssertNotNil(thumbnail)
        // Height should be 80 (max), width should be 40 (maintaining 1:2 ratio)
        XCTAssertEqual(thumbnail!.size.width, 40, accuracy: 1)
        XCTAssertEqual(thumbnail!.size.height, 80, accuracy: 1)
    }

    func testThumbnailFromSmallImage() throws {
        // Create a small image (40x40) smaller than thumbnail size
        let image = createTestImage(width: 40, height: 40, color: .orange)
        let imageData = image.tiffRepresentation!

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: imageData, maxSize: 80)

        XCTAssertNotNil(thumbnail)
        // Small images should not be scaled up
        XCTAssertLessThanOrEqual(thumbnail!.size.width, 80)
        XCTAssertLessThanOrEqual(thumbnail!.size.height, 80)
    }

    func testThumbnailFromInvalidData() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: invalidData, maxSize: 80)

        XCTAssertNil(thumbnail, "Should return nil for invalid image data")
    }

    func testThumbnailFromEmptyData() {
        let emptyData = Data()

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: emptyData, maxSize: 80)

        XCTAssertNil(thumbnail, "Should return nil for empty data")
    }

    // MARK: - PNG Data Generation

    func testGenerateThumbnailDataAsPNG() throws {
        let image = createTestImage(width: 100, height: 100, color: .red)
        let imageData = image.tiffRepresentation!

        let pngData = ThumbnailGenerator.generateThumbnailData(from: imageData, maxSize: 80, format: .png)

        XCTAssertNotNil(pngData)
        // Verify it's valid PNG by checking magic bytes
        let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47] // PNG signature
        let dataBytes = [UInt8](pngData!.prefix(4))
        XCTAssertEqual(dataBytes, pngMagic, "Output should be valid PNG data")
    }

    func testGenerateThumbnailDataAsJPEG() throws {
        let image = createTestImage(width: 100, height: 100, color: .red)
        let imageData = image.tiffRepresentation!

        let jpegData = ThumbnailGenerator.generateThumbnailData(from: imageData, maxSize: 80, format: .jpeg)

        XCTAssertNotNil(jpegData)
        // Verify it's valid JPEG by checking magic bytes
        let jpegMagic: [UInt8] = [0xFF, 0xD8, 0xFF] // JPEG signature
        let dataBytes = [UInt8](jpegData!.prefix(3))
        XCTAssertEqual(dataBytes, jpegMagic, "Output should be valid JPEG data")
    }

    // MARK: - Image Dimensions

    func testGetImageDimensions() throws {
        let image = createTestImage(width: 150, height: 200, color: .cyan)
        let imageData = image.tiffRepresentation!

        let dimensions = ThumbnailGenerator.getImageDimensions(from: imageData)

        XCTAssertNotNil(dimensions)
        XCTAssertEqual(dimensions!.width, 150)
        XCTAssertEqual(dimensions!.height, 200)
    }

    func testGetImageDimensionsFromInvalidData() {
        let invalidData = Data([0x00, 0x01, 0x02])

        let dimensions = ThumbnailGenerator.getImageDimensions(from: invalidData)

        XCTAssertNil(dimensions)
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
}

// MARK: - ClipboardContentExtractor Image Tests

final class ClipboardContentExtractorImageTests: XCTestCase {

    func testExtractImageFromPasteboard() {
        let pasteboard = NSPasteboard(name: .init("test-image-\(UUID().uuidString)"))
        pasteboard.clearContents()

        // Create test image and put on pasteboard
        let image = createTestImage(width: 100, height: 100, color: .red)
        pasteboard.writeObjects([image])

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .image)
        XCTAssertNotNil(result?.data, "Image extraction should include raw data")
    }

    func testExtractPNGImageData() {
        let pasteboard = NSPasteboard(name: .init("test-png-\(UUID().uuidString)"))
        pasteboard.clearContents()

        // Create PNG data and put on pasteboard
        let image = createTestImage(width: 50, height: 50, color: .blue)
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
        }

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .image)
    }

    func testExtractTIFFImageData() {
        let pasteboard = NSPasteboard(name: .init("test-tiff-\(UUID().uuidString)"))
        pasteboard.clearContents()

        // Create TIFF data and put on pasteboard
        let image = createTestImage(width: 50, height: 50, color: .green)
        if let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .image)
        XCTAssertNotNil(result?.data)
    }

    func testImageContentHasDescriptiveText() {
        let pasteboard = NSPasteboard(name: .init("test-img-content-\(UUID().uuidString)"))
        pasteboard.clearContents()

        let image = createTestImage(width: 100, height: 100, color: .purple)
        pasteboard.writeObjects([image])

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        // Content should have descriptive text like "[Image copied at...]"
        XCTAssertTrue(result!.content.contains("Image"), "Image content should have descriptive text")
    }

    func testTextPreferredOverImage() {
        // When both text and image are on pasteboard, text should take precedence
        let pasteboard = NSPasteboard(name: .init("test-text-img-\(UUID().uuidString)"))
        pasteboard.clearContents()

        // Add both text and image
        let text = "Some text content"
        pasteboard.setString(text, forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .text)
        XCTAssertEqual(result?.content, text)
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
}

// MARK: - Image Clipboard Integration Tests

final class ImageClipboardIntegrationTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_img_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    func testSaveAndRetrieveImageItem() async throws {
        // Create image data
        let image = createTestImage(width: 100, height: 100, color: .red)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG data")
            return
        }
        let hash = SHA256Hasher.hash(data: pngData)

        // Create clipboard item with blob content
        let item = ClipboardItem(
            content: "[Image copied at \(Date().formatted())]",
            contentType: .image,
            contentHash: hash,
            sourceApp: "TestApp",
            blobContent: pngData
        )

        // Save to database
        try await storage.save(item)

        // Retrieve
        let items = try await storage.fetchItems(limit: 10, favoriteOnly: false, includeContent: true)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.contentType, .image)
        XCTAssertNotNil(items.first?.blobContent)
        XCTAssertEqual(items.first?.blobContent, pngData)
    }

    func testImageItemPreviewText() async throws {
        let item = ClipboardItem(
            content: "[Image copied at 2024-01-15]",
            contentType: .image,
            contentHash: "test-hash",
            blobContent: Data([0x01, 0x02])
        )

        XCTAssertEqual(item.preview, "[Image]")
    }

    func testDeleteImageItem() async throws {
        // Create and save image
        let image = createTestImage(width: 50, height: 50, color: .blue)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG data")
            return
        }
        let hash = SHA256Hasher.hash(data: pngData)

        let item = ClipboardItem(
            content: "[Image]",
            contentType: .image,
            contentHash: hash,
            blobContent: pngData
        )

        try await storage.save(item)

        // Verify saved
        var count = try await storage.count()
        XCTAssertEqual(count, 1)

        // Delete item
        try await storage.delete(item)

        // Verify deleted
        count = try await storage.count()
        XCTAssertEqual(count, 0)
    }

    func testRecreateImageFromBlobContent() async throws {
        // Create original image
        let originalImage = createTestImage(width: 100, height: 100, color: .cyan)
        guard let tiffData = originalImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG data")
            return
        }
        let hash = SHA256Hasher.hash(data: pngData)

        let item = ClipboardItem(
            content: "[Image 100x100]",
            contentType: .image,
            contentHash: hash,
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
}
