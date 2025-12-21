import XCTest
@testable import KlipPal

@MainActor
final class ImagePreviewTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var viewModel: OverlayViewModel!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_preview_\(UUID().uuidString).db").path
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

    func testLoadFullImageReturnsImageForValidItem() async throws {
        // Create a test image (100x100 red square)
        let testImage = createTestImage(width: 100, height: 100, color: .red)
        guard let imageData = testImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create test image data")
            return
        }

        // Create clipboard item with blob content
        let contentHash = "testimage123"
        let item = ClipboardItem(
            content: "100x100 PNG",
            contentType: .image,
            contentHash: contentHash,
            blobContent: pngData
        )
        try await storage.save(item)

        // Load full image
        let loadedImage = await viewModel.loadFullImage(for: item)

        XCTAssertNotNil(loadedImage, "Full image should be loaded")
        XCTAssertEqual(Int(loadedImage!.size.width), 100)
        XCTAssertEqual(Int(loadedImage!.size.height), 100)
    }

    func testLoadFullImageReturnsNilForNonImageItem() async throws {
        let textItem = ClipboardItem(
            content: "Just some text",
            contentType: .text,
            contentHash: "text123"
        )
        try await storage.save(textItem)

        let loadedImage = await viewModel.loadFullImage(for: textItem)

        XCTAssertNil(loadedImage, "Should return nil for non-image items")
    }

    func testLoadFullImageReturnsNilForMissingBlob() async throws {
        // Create item with no blob content
        let item = ClipboardItem(
            content: "100x100 PNG",
            contentType: .image,
            contentHash: "missing123",
            blobContent: nil
        )
        try await storage.save(item)

        let loadedImage = await viewModel.loadFullImage(for: item)

        XCTAssertNil(loadedImage, "Should return nil when blob content is missing")
    }

    func testFullImageCacheStoresLoadedImage() async throws {
        // Create a test image
        let testImage = createTestImage(width: 50, height: 50, color: .blue)
        guard let imageData = testImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create test image data")
            return
        }

        let contentHash = "cachedimage123"
        let item = ClipboardItem(
            content: "50x50 PNG",
            contentType: .image,
            contentHash: contentHash,
            blobContent: pngData
        )
        try await storage.save(item)

        // First load
        let image1 = await viewModel.loadFullImage(for: item)
        XCTAssertNotNil(image1)

        // Check cache
        XCTAssertNotNil(viewModel.fullImageCache[contentHash], "Image should be cached after loading")

        // Second load should return cached image
        let image2 = await viewModel.loadFullImage(for: item)
        XCTAssertNotNil(image2)
    }

    // MARK: - Helper Methods

    private func createTestImage(width: Int, height: Int, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }
}
