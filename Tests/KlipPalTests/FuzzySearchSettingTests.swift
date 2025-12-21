import XCTest
@testable import KlipPal

/// Tests for fuzzy search configuration and its effects on search behavior
final class FuzzySearchSettingTests: XCTestCase {
    var searchEngine: SearchEngine!

    override func setUp() {
        searchEngine = SearchEngine()
    }

    override func tearDown() {
        searchEngine = nil
    }

    // MARK: - Fuzzy Search Toggle Tests

    func testFuzzySearchDefaultsToEnabled() {
        // SearchEngine defaults to fuzzy enabled (true)
        let engine = SearchEngine()
        XCTAssertTrue(engine.fuzzyMatchingEnabled)
    }

    func testFuzzySearchCanBeDisabled() {
        searchEngine.fuzzyMatchingEnabled = false
        XCTAssertFalse(searchEngine.fuzzyMatchingEnabled)
    }

    func testFuzzySearchCanBeToggled() {
        searchEngine.fuzzyMatchingEnabled = true
        XCTAssertTrue(searchEngine.fuzzyMatchingEnabled)

        searchEngine.fuzzyMatchingEnabled = false
        XCTAssertFalse(searchEngine.fuzzyMatchingEnabled)

        searchEngine.fuzzyMatchingEnabled = true
        XCTAssertTrue(searchEngine.fuzzyMatchingEnabled)
    }

    // MARK: - Search Behavior with Fuzzy Disabled

    func testFuzzyDisabledDoesNotMatchSkippedCharacters() {
        searchEngine.fuzzyMatchingEnabled = false

        let item = ClipboardItem(
            content: "hello world",
            contentType: .text,
            contentHash: "test1"
        )

        // "hwd" would fuzzy match "hello world" but should not with fuzzy disabled
        let results = searchEngine.search(query: "hwd", in: [item])
        XCTAssertTrue(results.isEmpty, "Fuzzy disabled should not match skipped characters")
    }

    func testFuzzyDisabledStillMatchesSubstring() {
        searchEngine.fuzzyMatchingEnabled = false

        let item = ClipboardItem(
            content: "hello world",
            contentType: .text,
            contentHash: "test2"
        )

        let results = searchEngine.search(query: "world", in: [item])
        XCTAssertEqual(results.count, 1, "Substring match should work with fuzzy disabled")
    }

    func testFuzzyDisabledStillMatchesPrefix() {
        searchEngine.fuzzyMatchingEnabled = false

        let item = ClipboardItem(
            content: "hello world",
            contentType: .text,
            contentHash: "test3"
        )

        let results = searchEngine.search(query: "hello", in: [item])
        XCTAssertEqual(results.count, 1, "Prefix match should work with fuzzy disabled")
    }

    func testFuzzyDisabledStillMatchesExact() {
        searchEngine.fuzzyMatchingEnabled = false

        let item = ClipboardItem(
            content: "hello",
            contentType: .text,
            contentHash: "test4"
        )

        let results = searchEngine.search(query: "hello", in: [item])
        XCTAssertEqual(results.count, 1, "Exact match should work with fuzzy disabled")
    }

    // MARK: - Search Behavior with Fuzzy Enabled

    func testFuzzyEnabledMatchesSkippedCharacters() {
        searchEngine.fuzzyMatchingEnabled = true

        let item = ClipboardItem(
            content: "hello world",
            contentType: .text,
            contentHash: "test5"
        )

        // "hwd" should fuzzy match "hello world"
        let results = searchEngine.search(query: "hwd", in: [item])
        XCTAssertEqual(results.count, 1, "Fuzzy enabled should match skipped characters")
    }

    func testFuzzyEnabledMatchesAcronyms() {
        searchEngine.fuzzyMatchingEnabled = true

        let item = ClipboardItem(
            content: "quick brown fox",
            contentType: .text,
            contentHash: "test6"
        )

        let results = searchEngine.search(query: "qbf", in: [item])
        XCTAssertEqual(results.count, 1, "Fuzzy enabled should match acronyms")
    }

    // MARK: - Source App Matching Tests

    func testFuzzyDisabledDoesNotMatchSourceApp() {
        searchEngine.fuzzyMatchingEnabled = false

        let item = ClipboardItem(
            content: "some content",
            contentType: .text,
            contentHash: "test7",
            sourceApp: "Safari"
        )

        let results = searchEngine.search(query: "Safari", in: [item])
        XCTAssertTrue(results.isEmpty, "Fuzzy disabled should not match sourceApp")
    }

    func testFuzzyEnabledMatchesSourceApp() {
        searchEngine.fuzzyMatchingEnabled = true

        let item = ClipboardItem(
            content: "some content",
            contentType: .text,
            contentHash: "test8",
            sourceApp: "Safari"
        )

        let results = searchEngine.search(query: "Safari", in: [item])
        XCTAssertEqual(results.count, 1, "Fuzzy enabled should match sourceApp")
        XCTAssertEqual(results.first?.matchField, .sourceApp)
    }

    func testSourceAppMatchHasNoHighlightRanges() {
        searchEngine.fuzzyMatchingEnabled = true

        let item = ClipboardItem(
            content: "unrelated content",
            contentType: .text,
            contentHash: "test9",
            sourceApp: "TextEdit"
        )

        let results = searchEngine.search(query: "TextEdit", in: [item])
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.matchedRanges.isEmpty ?? false,
            "sourceApp match should have empty highlight ranges")
    }

    // MARK: - File URL Matching Tests

    func testFuzzyDisabledOnlyMatchesFilename() {
        searchEngine.fuzzyMatchingEnabled = false

        let item = ClipboardItem(
            content: "/Users/adam/Documents/report.pdf",
            contentType: .fileURL,
            contentHash: "test10"
        )

        // Should not match path component "adam"
        let adamResults = searchEngine.search(query: "adam", in: [item])
        XCTAssertTrue(adamResults.isEmpty, "Fuzzy disabled should not match file path")

        // Should match filename
        let reportResults = searchEngine.search(query: "report", in: [item])
        XCTAssertEqual(reportResults.count, 1, "Should match filename")
        XCTAssertEqual(reportResults.first?.matchField, .filename)
    }

    func testFuzzyEnabledMatchesFullPath() {
        searchEngine.fuzzyMatchingEnabled = true

        let item = ClipboardItem(
            content: "/Users/adam/Documents/report.pdf",
            contentType: .fileURL,
            contentHash: "test11"
        )

        // Should match path component "adam"
        let results = searchEngine.search(query: "adam", in: [item])
        XCTAssertEqual(results.count, 1, "Fuzzy enabled should match file path")
    }

    func testFilePathMatchHasNoHighlightRanges() {
        searchEngine.fuzzyMatchingEnabled = true

        let item = ClipboardItem(
            content: "/Users/adam/Documents/report.pdf",
            contentType: .fileURL,
            contentHash: "test12"
        )

        // Match on path (not filename)
        let results = searchEngine.search(query: "adam", in: [item])
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.matchedRanges.isEmpty ?? false,
            "File path match should have empty highlight ranges (not applicable to displayed filename)")
    }

    func testFilenameMatchHasHighlightRanges() {
        searchEngine.fuzzyMatchingEnabled = false

        let item = ClipboardItem(
            content: "/Users/test/Documents/report.pdf",
            contentType: .fileURL,
            contentHash: "test13"
        )

        let results = searchEngine.search(query: "report", in: [item])
        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results.first?.matchedRanges.isEmpty ?? true,
            "Filename match should have highlight ranges")
    }

    // MARK: - Match Field Tracking Tests

    func testMatchFieldTracksContentMatch() {
        searchEngine.fuzzyMatchingEnabled = false

        let item = ClipboardItem(
            content: "hello world",
            contentType: .text,
            contentHash: "test14"
        )

        let results = searchEngine.search(query: "hello", in: [item])
        XCTAssertEqual(results.first?.matchField, .content)
    }

    func testMatchFieldTracksFilenameMatch() {
        searchEngine.fuzzyMatchingEnabled = false

        let item = ClipboardItem(
            content: "/path/to/document.txt",
            contentType: .fileURL,
            contentHash: "test15"
        )

        let results = searchEngine.search(query: "document", in: [item])
        XCTAssertEqual(results.first?.matchField, .filename)
    }

    func testMatchFieldTracksSourceAppMatch() {
        searchEngine.fuzzyMatchingEnabled = true

        let item = ClipboardItem(
            content: "random content",
            contentType: .text,
            contentHash: "test16",
            sourceApp: "Xcode"
        )

        let results = searchEngine.search(query: "Xcode", in: [item])
        XCTAssertEqual(results.first?.matchField, .sourceApp)
    }

    // MARK: - Empty Query Tests

    func testEmptyQueryReturnsAllItems() {
        searchEngine.fuzzyMatchingEnabled = false

        let items = [
            ClipboardItem(content: "item1", contentType: .text, contentHash: "e1"),
            ClipboardItem(content: "item2", contentType: .text, contentHash: "e2"),
            ClipboardItem(content: "item3", contentType: .text, contentHash: "e3"),
        ]

        let results = searchEngine.search(query: "", in: items)
        XCTAssertEqual(results.count, 3, "Empty query should return all items")
    }

    func testWhitespaceQueryReturnsAllItems() {
        searchEngine.fuzzyMatchingEnabled = false

        let items = [
            ClipboardItem(content: "item1", contentType: .text, contentHash: "w1"),
            ClipboardItem(content: "item2", contentType: .text, contentHash: "w2"),
        ]

        let results = searchEngine.search(query: "   ", in: items)
        XCTAssertEqual(results.count, 2, "Whitespace query should return all items")
    }

    // MARK: - Match Type Sorting Tests

    func testExactMatchesComeBeforeFuzzyMatches() {
        searchEngine.fuzzyMatchingEnabled = true

        // Create items with timestamps
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)

        // Item that will have an exact match (substring "hello")
        let exactMatchItem = ClipboardItem(
            id: UUID(),
            content: "hello world",
            contentType: .text,
            contentHash: "exact1",
            timestamp: oneHourAgo  // Older
        )

        // Item that will have a fuzzy match (h...l...o)
        let fuzzyMatchItem = ClipboardItem(
            id: UUID(),
            content: "help layout options",  // "hlo" fuzzy matches "hello"
            contentType: .text,
            contentHash: "fuzzy1",
            timestamp: now  // Newer
        )

        let items = [fuzzyMatchItem, exactMatchItem]
        let results = searchEngine.search(query: "hello", in: items)

        XCTAssertEqual(results.count, 2, "Should find both items")
        // Even though fuzzyMatchItem is newer, exactMatchItem should come first
        XCTAssertEqual(results[0].matchType, .exact, "Exact match should come first")
        XCTAssertEqual(results[1].matchType, .fuzzy, "Fuzzy match should come second")
        XCTAssertEqual(results[0].item.content, "hello world")
    }

    func testExactMatchesSortedByTimestampNewestFirst() {
        searchEngine.fuzzyMatchingEnabled = true

        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)

        let item1 = ClipboardItem(
            id: UUID(),
            content: "hello again",
            contentType: .text,
            contentHash: "t1",
            timestamp: twoHoursAgo  // Oldest
        )
        let item2 = ClipboardItem(
            id: UUID(),
            content: "say hello there",
            contentType: .text,
            contentHash: "t2",
            timestamp: now  // Newest
        )
        let item3 = ClipboardItem(
            id: UUID(),
            content: "hello world",
            contentType: .text,
            contentHash: "t3",
            timestamp: oneHourAgo  // Middle
        )

        let items = [item1, item2, item3]
        let results = searchEngine.search(query: "hello", in: items)

        XCTAssertEqual(results.count, 3)
        // All are exact matches, should be sorted by timestamp newest first
        XCTAssertEqual(results[0].item.timestamp, now, "Newest should be first")
        XCTAssertEqual(results[1].item.timestamp, oneHourAgo, "Middle should be second")
        XCTAssertEqual(results[2].item.timestamp, twoHoursAgo, "Oldest should be last")
    }

    func testFuzzyMatchesSortedByTimestampNewestFirst() {
        searchEngine.fuzzyMatchingEnabled = true

        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)

        // Items that will only fuzzy match "abc" (a...b...c)
        let item1 = ClipboardItem(
            id: UUID(),
            content: "a_better_code",  // abc fuzzy
            contentType: .text,
            contentHash: "f1",
            timestamp: oneHourAgo  // Older
        )
        let item2 = ClipboardItem(
            id: UUID(),
            content: "another_big_cat",  // abc fuzzy
            contentType: .text,
            contentHash: "f2",
            timestamp: now  // Newer
        )

        let items = [item1, item2]
        let results = searchEngine.search(query: "abc", in: items)

        XCTAssertEqual(results.count, 2)
        // Both are fuzzy matches, should be sorted by timestamp newest first
        XCTAssertEqual(results[0].item.timestamp, now, "Newer fuzzy match should be first")
        XCTAssertEqual(results[1].item.timestamp, oneHourAgo, "Older fuzzy match should be second")
    }

    func testMatchTypeIsTrackedCorrectly() {
        searchEngine.fuzzyMatchingEnabled = true

        let item = ClipboardItem(
            content: "hello world",
            contentType: .text,
            contentHash: "mt1"
        )

        // Exact substring match
        let exactResults = searchEngine.search(query: "hello", in: [item])
        XCTAssertEqual(exactResults.first?.matchType, .exact)

        // Fuzzy match (h...w...d)
        let fuzzyResults = searchEngine.search(query: "hwd", in: [item])
        XCTAssertEqual(fuzzyResults.first?.matchType, .fuzzy)
    }
}

// MARK: - ViewModel Search Query Persistence Tests

@MainActor
final class ViewModelSearchQueryTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var viewModel: OverlayViewModel!
    var tempDBPath: String!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_vm_search_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

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

    func testSearchQueryIsPersisted() async throws {
        // Add test items
        let item = ClipboardItem(content: "test content", contentType: .text, contentHash: "persist1")
        try await storage.save(item)

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Perform search
        viewModel.search(query: "test")

        // Reload items - search should be re-applied
        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Filtered items should still reflect the search
        XCTAssertEqual(viewModel.filteredItems.count, 1)
    }

    func testLoadItemsResetsSelectionToZero() async throws {
        // Add test items
        for i in 0..<5 {
            let item = ClipboardItem(content: "item \(i)", contentType: .text, contentHash: "reset\(i)")
            try await storage.save(item)
        }

        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Change selection
        viewModel.selectedIndex = 3

        // Reload
        viewModel.loadItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.selectedIndex, 0, "Selection should reset to 0 on load")
    }
}
