import XCTest
@testable import KlipPal

@MainActor
final class OverlayViewModelClearHistoryTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var viewModel: OverlayViewModel!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_clear_\(UUID().uuidString).db").path
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

    // MARK: - Clear History Notification Tests

    func testClearHistoryNotificationClearsItems() async throws {
        // Create and save test items
        let item1 = ClipboardItem(
            content: "Item 1",
            contentType: .text,
            contentHash: "hash1"
        )
        let item2 = ClipboardItem(
            content: "Item 2",
            contentType: .text,
            contentHash: "hash2"
        )

        try await storage.save(item1)
        try await storage.save(item2)

        // Load items into view model
        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.filteredItems.count, 2)

        // Post clear history notification
        NotificationCenter.default.post(name: .clipboardHistoryCleared, object: nil)

        // Wait for notification to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify items are cleared
        XCTAssertEqual(viewModel.items.count, 0)
        XCTAssertEqual(viewModel.filteredItems.count, 0)
    }

    func testClearHistoryNotificationClearsSearchResults() async throws {
        // Create and save test items
        let item1 = ClipboardItem(
            content: "Apple pie",
            contentType: .text,
            contentHash: "apple123"
        )
        let item2 = ClipboardItem(
            content: "Apple sauce",
            contentType: .text,
            contentHash: "sauce123"
        )

        try await storage.save(item1)
        try await storage.save(item2)

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Perform a search
        viewModel.search(query: "Apple")
        XCTAssertEqual(viewModel.filteredItems.count, 2)

        // Post clear history notification
        NotificationCenter.default.post(name: .clipboardHistoryCleared, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify search results are cleared
        XCTAssertEqual(viewModel.filteredItems.count, 0)
    }

    func testClearHistoryNotificationResetsSelectedIndex() async throws {
        // Create and save test items
        for i in 0..<5 {
            let item = ClipboardItem(
                content: "Item \(i)",
                contentType: .text,
                contentHash: "hash\(i)"
            )
            try await storage.save(item)
        }

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Select an item
        viewModel.selectedIndex = 3
        XCTAssertEqual(viewModel.selectedIndex, 3)

        // Post clear history notification
        NotificationCenter.default.post(name: .clipboardHistoryCleared, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify selected index is reset
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testClearHistoryNotificationClearsThumbnailCache() async throws {
        // Create an image item with a thumbnail
        let imageData = createTestImageData()
        let item = ClipboardItem(
            content: "Image 100x100",
            contentType: .image,
            contentHash: "imagehash123",
            blobContent: imageData
        )

        try await storage.save(item)

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms for thumbnail generation

        // Verify thumbnail was cached
        XCTAssertFalse(viewModel.thumbnailCache.isEmpty)

        // Post clear history notification
        NotificationCenter.default.post(name: .clipboardHistoryCleared, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify thumbnail cache is cleared
        XCTAssertTrue(viewModel.thumbnailCache.isEmpty)
    }

    func testClearHistoryNotificationClearsFullImageCache() async throws {
        // Create an image item
        let imageData = createTestImageData()
        let item = ClipboardItem(
            content: "Image 100x100",
            contentType: .image,
            contentHash: "imagehash456",
            blobContent: imageData
        )

        try await storage.save(item)

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Load full image to populate cache
        _ = await viewModel.loadFullImage(for: item)
        XCTAssertFalse(viewModel.fullImageCache.isEmpty)

        // Post clear history notification
        NotificationCenter.default.post(name: .clipboardHistoryCleared, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify full image cache is cleared
        XCTAssertTrue(viewModel.fullImageCache.isEmpty)
    }

    func testClearHistoryNotificationWithEmptyViewModel() async throws {
        // Verify view model starts empty
        XCTAssertEqual(viewModel.items.count, 0)
        XCTAssertEqual(viewModel.filteredItems.count, 0)

        // Post clear history notification (should not crash)
        NotificationCenter.default.post(name: .clipboardHistoryCleared, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify still empty
        XCTAssertEqual(viewModel.items.count, 0)
        XCTAssertEqual(viewModel.filteredItems.count, 0)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testClearHistoryNotificationClearsPinnedItems() async throws {
        // Create and save a pinned item
        var item = ClipboardItem(
            content: "Pinned item",
            contentType: .text,
            contentHash: "pinned123"
        )
        item.isFavorite = true

        try await storage.save(item)

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Set to show pinned only
        viewModel.setShowingPinnedOnly(true)
        XCTAssertEqual(viewModel.filteredItems.count, 1)

        // Post clear history notification
        NotificationCenter.default.post(name: .clipboardHistoryCleared, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify pinned items are cleared
        XCTAssertEqual(viewModel.items.count, 0)
        XCTAssertEqual(viewModel.filteredItems.count, 0)
        XCTAssertEqual(viewModel.pinnedCount, 0)
    }

    // MARK: - Helper Methods

    private func createTestImageData() -> Data {
        // Create a simple 10x10 PNG image
        let size = CGSize(width: 10, height: 10)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return pngData
    }
}
