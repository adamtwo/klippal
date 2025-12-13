import XCTest
@testable import KlipPal

@MainActor
final class ImagePreviewTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var blobStorage: BlobStorageManager!
    var viewModel: OverlayViewModel!
    var tempDBPath: String!
    var tempBlobDir: URL!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_preview_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Create temporary blob storage
        tempBlobDir = tempDir.appendingPathComponent("blobs_\(UUID().uuidString)")
        blobStorage = try BlobStorageManager(blobDirectory: tempBlobDir)

        // Set up AppDelegate.shared for ViewModel to use
        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        appDelegate.blobStorage = blobStorage
        AppDelegate.shared = appDelegate

        viewModel = OverlayViewModel(storage: storage, blobStorage: blobStorage)
    }

    override func tearDown() async throws {
        viewModel = nil
        storage = nil
        blobStorage = nil
        try? FileManager.default.removeItem(atPath: tempDBPath)
        try? FileManager.default.removeItem(at: tempBlobDir)
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

        // Save the image blob
        let contentHash = "testimage123"
        let relativePath = try await blobStorage.save(imageData: pngData, hash: contentHash)

        // Create clipboard item pointing to the blob
        let item = ClipboardItem(
            content: "100×100 PNG",
            contentType: .image,
            contentHash: contentHash,
            blobPath: relativePath
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
        // Create item pointing to non-existent blob
        let item = ClipboardItem(
            content: "100×100 PNG",
            contentType: .image,
            contentHash: "missing123",
            blobPath: "missing/path.png"
        )
        try await storage.save(item)

        let loadedImage = await viewModel.loadFullImage(for: item)

        XCTAssertNil(loadedImage, "Should return nil when blob is missing")
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
        let relativePath = try await blobStorage.save(imageData: pngData, hash: contentHash)

        let item = ClipboardItem(
            content: "50×50 PNG",
            contentType: .image,
            contentHash: contentHash,
            blobPath: relativePath
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
