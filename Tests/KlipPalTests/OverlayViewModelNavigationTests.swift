import XCTest
@testable import KlipPal

@MainActor
final class OverlayViewModelNavigationTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var viewModel: OverlayViewModel!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_nav_\(UUID().uuidString).db").path
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

    // MARK: - selectNext Tests

    func testSelectNextIncrementsSelectedIndex() async throws {
        // Create test items
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

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 1)

        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 2)
    }

    func testSelectNextDoesNotExceedBounds() async throws {
        // Create test items
        let items = (0..<3).map { i in
            ClipboardItem(
                content: "Item \(i)",
                contentType: .text,
                contentHash: "hash\(i)"
            )
        }

        for item in items {
            try await storage.save(item)
        }

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Move to last item
        viewModel.selectedIndex = 2

        // Try to go beyond
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 2, "Should stay at last index")

        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 2, "Should still stay at last index")
    }

    func testSelectNextWithEmptyListDoesNothing() {
        XCTAssertEqual(viewModel.filteredItems.count, 0)
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testSelectNextTriggersScrollToSelection() async throws {
        // Create test items
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

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(viewModel.scrollToSelection, "Should be nil initially")

        viewModel.selectNext()

        XCTAssertNotNil(viewModel.scrollToSelection, "Should trigger scroll on keyboard navigation")
        XCTAssertEqual(viewModel.scrollToSelection, viewModel.filteredItems[1].id)
    }

    // MARK: - selectPrevious Tests

    func testSelectPreviousDecrementsSelectedIndex() async throws {
        // Create test items
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

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        viewModel.selectedIndex = 3

        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 2)

        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 1)
    }

    func testSelectPreviousDoesNotGoBelowZero() async throws {
        // Create test items
        let items = (0..<3).map { i in
            ClipboardItem(
                content: "Item \(i)",
                contentType: .text,
                contentHash: "hash\(i)"
            )
        }

        for item in items {
            try await storage.save(item)
        }

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 0, "Should stay at 0")

        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 0, "Should still stay at 0")
    }

    func testSelectPreviousWithEmptyListDoesNothing() {
        XCTAssertEqual(viewModel.filteredItems.count, 0)
        XCTAssertEqual(viewModel.selectedIndex, 0)

        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testSelectPreviousTriggersScrollToSelection() async throws {
        // Create test items
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

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        viewModel.selectedIndex = 3
        viewModel.scrollToSelection = nil // Reset

        viewModel.selectPrevious()

        XCTAssertNotNil(viewModel.scrollToSelection, "Should trigger scroll on keyboard navigation")
        XCTAssertEqual(viewModel.scrollToSelection, viewModel.filteredItems[2].id)
    }

    // MARK: - Mouse Click vs Keyboard Navigation

    func testDirectIndexChangeDoesNotTriggerScroll() async throws {
        // Create test items
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

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(viewModel.scrollToSelection, "Should be nil initially")

        // Simulate mouse click by directly setting selectedIndex
        viewModel.selectedIndex = 3

        XCTAssertNil(viewModel.scrollToSelection, "Direct index change should NOT trigger scroll")
    }

    // MARK: - Navigation with Search Filter

    func testKeyboardNavigationWorksWithFilteredList() async throws {
        // Create items with different content
        let item1 = ClipboardItem(content: "Apple pie", contentType: .text, contentHash: "apple1")
        let item2 = ClipboardItem(content: "Banana bread", contentType: .text, contentHash: "banana1")
        let item3 = ClipboardItem(content: "Apple sauce", contentType: .text, contentHash: "apple2")
        let item4 = ClipboardItem(content: "Cherry cake", contentType: .text, contentHash: "cherry1")

        try await storage.save(item1)
        try await storage.save(item2)
        try await storage.save(item3)
        try await storage.save(item4)

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Search for "Apple" - should filter to 2 items
        viewModel.search(query: "Apple")
        XCTAssertEqual(viewModel.filteredItems.count, 2)

        viewModel.selectedIndex = 0
        viewModel.scrollToSelection = nil

        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertNotNil(viewModel.scrollToSelection)

        // Should not go beyond filtered list bounds
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, 1, "Should stay at last filtered index")
    }

    // MARK: - Sequential Navigation

    func testSequentialNavigationUpdatesScrollToSelection() async throws {
        // Create test items
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

        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Navigate down several times
        viewModel.selectNext()
        let scroll1 = viewModel.scrollToSelection
        XCTAssertEqual(scroll1, viewModel.filteredItems[1].id)

        viewModel.selectNext()
        let scroll2 = viewModel.scrollToSelection
        XCTAssertEqual(scroll2, viewModel.filteredItems[2].id)
        XCTAssertNotEqual(scroll1, scroll2, "Scroll target should update")

        viewModel.selectPrevious()
        let scroll3 = viewModel.scrollToSelection
        XCTAssertEqual(scroll3, viewModel.filteredItems[1].id)
        XCTAssertNotEqual(scroll2, scroll3, "Scroll target should update on direction change")
    }

    // MARK: - Scroll to Top on Load

    func testLoadItemsResetsSelectedIndexToZero() async throws {
        // Create test items
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

        // First load from storage
        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Simulate user scrolling down and selecting item 3
        viewModel.selectedIndex = 3

        // Call loadItems() (simulates window re-opening) - should reset to 0
        viewModel.loadItems()

        XCTAssertEqual(viewModel.selectedIndex, 0, "Selected index should reset to 0 on loadItems")
    }

    func testLoadItemsTriggersScrollToTop() async throws {
        // Create test items
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

        // First load from storage
        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        let initialTrigger = viewModel.scrollToTopTrigger

        // Call loadItems() (simulates window re-opening)
        viewModel.loadItems()

        XCTAssertGreaterThan(viewModel.scrollToTopTrigger, initialTrigger,
            "scrollToTopTrigger should increment on loadItems")
    }

    func testScrollToTopTriggerIncrementsOnEachLoad() async throws {
        // Create test item
        let item = ClipboardItem(
            content: "Test",
            contentType: .text,
            contentHash: "hash1"
        )
        try await storage.save(item)

        // First load from storage
        viewModel.loadItemsFromStorage()
        try await Task.sleep(nanoseconds: 100_000_000)

        let trigger1 = viewModel.scrollToTopTrigger

        // Call loadItems() multiple times (simulates window re-openings)
        viewModel.loadItems()

        let trigger2 = viewModel.scrollToTopTrigger
        XCTAssertGreaterThan(trigger2, trigger1, "Trigger should increment after first load")

        viewModel.loadItems()

        let trigger3 = viewModel.scrollToTopTrigger
        XCTAssertGreaterThan(trigger3, trigger2, "Trigger should increment after second load")
    }
}
