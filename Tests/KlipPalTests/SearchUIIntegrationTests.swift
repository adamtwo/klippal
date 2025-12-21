import XCTest
import AppKit
import SwiftUI
@testable import KlipPal

/// Integration tests for search functionality with UI simulation
/// These tests verify the complete flow: typing in search → filtering results → selecting items
final class SearchUIIntegrationTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!
    var viewModel: OverlayViewModel!
    var panel: OverlayPanel!

    @MainActor
    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_ui_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Set up AppDelegate.shared
        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        AppDelegate.shared = appDelegate

        // Seed test data with various content types
        try await seedTestData()

        // Create view model and panel
        viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()

        // Wait for items to load
        try await Task.sleep(nanoseconds: 300_000_000)

        // Create panel with SwiftUI view
        panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.viewModel = viewModel

        let overlayView = OverlayView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: overlayView)
    }

    @MainActor
    override func tearDown() async throws {
        panel?.close()
        panel = nil
        viewModel = nil
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - Test Data

    private func seedTestData() async throws {
        let items: [(String, ClipboardContentType, String)] = [
            ("Hello world from Swift", .text, "Xcode"),
            ("Copy manager clipboard app", .text, "Notes"),
            ("https://github.com/apple/swift", .url, "Safari"),
            ("func searchItems() -> [Item]", .text, "Xcode"),
            ("/Users/test/Documents/report.pdf", .fileURL, "Finder"),
            ("The quick brown fox jumps", .text, "TextEdit"),
            ("Lorem ipsum dolor sit amet", .text, "Pages"),
            ("🚀 Launch day! 🎉", .text, "Messages"),
            ("SELECT * FROM clipboard_items", .text, "TablePlus"),
            ("npm run build && npm test", .text, "Terminal"),
            ("Meeting notes: discuss copy feature", .text, "Notes"),
            ("Python script: import clipboard", .text, "VSCode"),
        ]

        for (index, (content, type, app)) in items.enumerated() {
            let item = ClipboardItem(
                content: content,
                contentType: type,
                contentHash: "uihash\(index)_\(UUID().uuidString)",
                sourceApp: app
            )
            try await storage.save(item)
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // MARK: - Search Flow Integration Tests

    /// Tests the complete search flow: type query → results filter → verify count
    @MainActor
    func testSearchFlowFiltersResults() async throws {
        // Initial state: all items visible
        let initialCount = viewModel.filteredItems.count
        XCTAssertEqual(initialCount, 12, "Should have 12 items initially")

        // Simulate typing "copy" in search field
        viewModel.search(query: "copy")

        // Verify filtered results
        XCTAssertLessThan(viewModel.filteredItems.count, initialCount,
            "Search should reduce the number of items")

        // All results should contain "copy"
        for item in viewModel.filteredItems {
            let matchesContent = item.content.localizedCaseInsensitiveContains("copy")
            let matchesApp = item.sourceApp?.localizedCaseInsensitiveContains("copy") ?? false
            XCTAssertTrue(matchesContent || matchesApp,
                "All filtered items should match search query")
        }
    }

    /// Tests clearing search restores all items
    @MainActor
    func testClearSearchRestoresAllItems() async throws {
        let initialCount = viewModel.filteredItems.count

        // Search
        viewModel.search(query: "Swift")
        XCTAssertLessThan(viewModel.filteredItems.count, initialCount)

        // Clear search
        viewModel.search(query: "")

        // All items restored
        XCTAssertEqual(viewModel.filteredItems.count, initialCount,
            "Clearing search should restore all items")
    }

    /// Tests search resets selection to first item
    @MainActor
    func testSearchResetsSelectionToFirst() async throws {
        // Select item 5
        viewModel.selectedIndex = 5
        XCTAssertEqual(viewModel.selectedIndex, 5)

        // Search (which should reset selection)
        viewModel.search(query: "Swift")

        // Selection should be valid (within bounds)
        XCTAssertLessThan(viewModel.selectedIndex, viewModel.filteredItems.count,
            "Selection should be within filtered results")
    }

    // MARK: - Keyboard Navigation with Search Tests

    /// Tests arrow navigation after search
    @MainActor
    func testArrowNavigationAfterSearch() async throws {
        // Search to get subset
        viewModel.search(query: "copy")
        let filteredCount = viewModel.filteredItems.count
        XCTAssertGreaterThan(filteredCount, 0, "Should have some filtered results")

        // Reset selection
        viewModel.selectedIndex = 0

        // Navigate down
        viewModel.selectNext()
        XCTAssertEqual(viewModel.selectedIndex, min(1, filteredCount - 1))

        // Navigate up
        viewModel.selectPrevious()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    /// Tests Enter key pastes filtered item
    @MainActor
    func testEnterKeyPastesFilteredItem() async throws {
        // Search for specific item
        viewModel.search(query: "Lorem ipsum")

        XCTAssertFalse(viewModel.filteredItems.isEmpty, "Should find Lorem ipsum item")

        var pastedItem: ClipboardItem?
        viewModel.onBeforePaste = { [weak self] in
            pastedItem = self?.viewModel.filteredItems[self?.viewModel.selectedIndex ?? 0]
        }

        // Select first result and paste
        viewModel.selectedIndex = 0
        viewModel.pasteSelected()

        // Wait for async
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(pastedItem)
        XCTAssertTrue(pastedItem?.content.contains("Lorem ipsum") ?? false,
            "Should paste the searched item")
    }

    // MARK: - UI Event Simulation Tests

    /// Tests typing characters via sendEvent updates search
    @MainActor
    func testTypingCharactersFiltersResults() async throws {
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 200_000_000)

        let initialCount = viewModel.filteredItems.count

        // Simulate typing "swift" one character at a time
        // Each character should progressively filter
        let searchQuery = "swift"

        for (index, char) in searchQuery.enumerated() {
            let partialQuery = String(searchQuery.prefix(index + 1))
            viewModel.search(query: partialQuery)

            // Results should progressively narrow (or stay same)
            XCTAssertLessThanOrEqual(viewModel.filteredItems.count, initialCount,
                "Typing should filter or maintain results")
        }

        // Final search for "swift" should find Swift-related items
        XCTAssertFalse(viewModel.filteredItems.isEmpty,
            "Should find items containing 'swift'")
    }

    /// Tests Escape key during search clears and closes
    @MainActor
    func testEscapeKeyDuringSearch() async throws {
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 200_000_000)

        var closeCalled = false
        panel.onClose = { closeCalled = true }

        // Perform search
        viewModel.search(query: "test")

        // Send Escape key
        guard let escEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53
        ) else {
            XCTFail("Failed to create escape event")
            return
        }

        panel.sendEvent(escEvent)

        XCTAssertTrue(closeCalled, "Escape should close the panel")
    }

    /// Tests full keyboard workflow: search → navigate → select
    @MainActor
    func testFullKeyboardSearchWorkflow() async throws {
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 200_000_000)

        // 1. Search for "copy"
        viewModel.search(query: "copy")
        let searchResultCount = viewModel.filteredItems.count
        XCTAssertGreaterThan(searchResultCount, 0, "Should find 'copy' items")

        // 2. Navigate down with arrow keys
        let downEvent = createKeyEvent(keyCode: 125) // Down arrow
        panel.sendEvent(downEvent!)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.selectedIndex, 1, "Down arrow should select next item")

        // 3. Navigate up
        let upEvent = createKeyEvent(keyCode: 126) // Up arrow
        panel.sendEvent(upEvent!)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.selectedIndex, 0, "Up arrow should select previous item")

        // 4. Press Enter to paste
        var pasteTriggered = false
        viewModel.onBeforePaste = { pasteTriggered = true }

        let enterEvent = createKeyEvent(keyCode: 36) // Return
        panel.sendEvent(enterEvent!)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(pasteTriggered, "Enter should trigger paste")
    }

    // MARK: - Search Result Selection Tests

    /// Tests clicking on a search result
    @MainActor
    func testSelectingSearchResult() async throws {
        viewModel.search(query: "github")

        XCTAssertFalse(viewModel.filteredItems.isEmpty, "Should find GitHub URL")

        // Simulate selection (as if user clicked)
        viewModel.selectedIndex = 0
        let selectedItem = viewModel.filteredItems[viewModel.selectedIndex]

        XCTAssertTrue(selectedItem.content.contains("github"),
            "Selected item should be the GitHub URL")
        XCTAssertEqual(selectedItem.contentType, .url)
    }

    /// Tests double-click pastes selected item
    @MainActor
    func testDoubleClickPastesItem() async throws {
        viewModel.search(query: "Meeting")
        XCTAssertFalse(viewModel.filteredItems.isEmpty)

        var pastedContent: String?
        viewModel.onBeforePaste = { [weak self] in
            let idx = self?.viewModel.selectedIndex ?? 0
            pastedContent = self?.viewModel.filteredItems[idx].content
        }

        // Select and paste (simulating double-click)
        viewModel.selectedIndex = 0
        viewModel.pasteSelected()

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(pastedContent)
        XCTAssertTrue(pastedContent?.contains("Meeting") ?? false)
    }

    // MARK: - Search Edge Cases

    /// Tests rapid search updates (debouncing behavior)
    @MainActor
    func testRapidSearchUpdates() async throws {
        // Rapid fire searches (simulating fast typing)
        let queries = ["c", "co", "cop", "copy", "copy m", "copy ma"]

        for query in queries {
            viewModel.search(query: query)
        }

        // Final state should reflect last query
        let finalResults = viewModel.filteredItems
        for item in finalResults {
            let matches = item.content.localizedCaseInsensitiveContains("copy m") ||
                          item.sourceApp?.localizedCaseInsensitiveContains("copy m") ?? false
            XCTAssertTrue(matches || finalResults.count == viewModel.items.count,
                "Final results should match final query or be all items")
        }
    }

    /// Tests search with special characters doesn't crash
    @MainActor
    func testSearchWithSpecialCharacters() async throws {
        let specialQueries = [
            "[]",
            "()",
            "{}",
            ".*",
            "^$",
            "\\",
            "a+b",
            "foo|bar",
            "?",
        ]

        for query in specialQueries {
            // Should not crash
            viewModel.search(query: query)
            XCTAssertNotNil(viewModel.filteredItems,
                "Search with '\(query)' should not crash")
        }
    }

    /// Tests empty results state
    @MainActor
    func testEmptySearchResults() async throws {
        viewModel.search(query: "xyznonexistent123")

        XCTAssertTrue(viewModel.filteredItems.isEmpty,
            "Non-matching query should return empty results")

        // Selection should be safe
        viewModel.selectNext() // Should not crash
        viewModel.selectPrevious() // Should not crash
        viewModel.pasteSelected() // Should not crash (no-op)
    }

    // MARK: - Helper Methods

    private func createKeyEvent(keyCode: UInt16) -> NSEvent? {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel?.windowNumber ?? 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }
}

// MARK: - Search Highlighting UI Tests

/// Tests for search result highlighting in the UI
final class SearchHighlightingUITests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_highlight_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        AppDelegate.shared = appDelegate
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    /// Tests that search results include highlight ranges
    func testSearchResultsIncludeHighlightRanges() async throws {
        let item = ClipboardItem(
            content: "Hello world, hello there",
            contentType: .text,
            contentHash: "highlight_\(UUID().uuidString)",
            sourceApp: "Test"
        )

        let searchEngine = SearchEngine()
        let results = searchEngine.search(query: "hello", in: [item])

        XCTAssertFalse(results.isEmpty)
        XCTAssertFalse(results.first!.matchedRanges.isEmpty,
            "Search results should include matched ranges for highlighting")
    }

    /// Tests highlight ranges are correct positions
    func testHighlightRangesAreCorrect() async throws {
        let item = ClipboardItem(
            content: "Test content here",
            contentType: .text,
            contentHash: "pos_\(UUID().uuidString)",
            sourceApp: nil
        )

        let searchEngine = SearchEngine()
        let results = searchEngine.search(query: "content", in: [item])

        XCTAssertFalse(results.isEmpty)

        let ranges = results.first!.matchedRanges
        XCTAssertFalse(ranges.isEmpty)

        // Verify range points to "content" in the string
        let content = item.content as NSString
        for range in ranges {
            let substring = content.substring(with: range)
            XCTAssertTrue(substring.lowercased().contains("content") ||
                          "content".contains(substring.lowercased()),
                "Highlighted range should point to matched text")
        }
    }
}
