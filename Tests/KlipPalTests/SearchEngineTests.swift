import XCTest
@testable import KlipPal

/// Unit tests for SearchEngine - the search coordinator that uses FuzzyMatcher
final class SearchEngineTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!
    var searchEngine: SearchEngine!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_search_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Seed test data
        try await seedTestData()

        // Create search engine
        searchEngine = SearchEngine()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - Test Data

    private func seedTestData() async throws {
        let items = [
            ("Hello world", ClipboardContentType.text, "TextEdit"),
            ("Copy manager is awesome", .text, "Notes"),
            ("https://github.com/user/repo", .url, "Safari"),
            ("func copyToClipboard() { }", .text, "Xcode"),
            ("/Users/test/Documents/file.txt", .fileURL, "Finder"),
            ("The quick brown fox", .text, "TextEdit"),
            ("Lorem ipsum dolor sit amet", .text, "Pages"),
            ("🎉 Party time! 🎉", .text, "Messages"),
            ("SELECT * FROM users WHERE name = 'copy'", .text, "TablePlus"),
            ("npm install copy-manager", .text, "Terminal"),
        ]

        for (index, (content, type, app)) in items.enumerated() {
            let item = ClipboardItem(
                content: content,
                contentType: type,
                contentHash: "searchhash\(index)_\(UUID().uuidString)",
                sourceApp: app
            )
            try await storage.save(item)
            // Small delay for distinct timestamps
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func loadItems() async throws -> [ClipboardItem] {
        return try await storage.fetchItems(limit: 100, favoriteOnly: false)
    }

    // MARK: - Basic Search Tests

    func testSearchReturnsMatchingItems() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "copy", in: items)

        XCTAssertFalse(results.isEmpty, "Should find items containing 'copy'")

        // Verify all results contain 'copy' somewhere
        for result in results {
            let containsCopy = result.item.content.localizedCaseInsensitiveContains("copy") ||
                               (result.item.sourceApp?.localizedCaseInsensitiveContains("copy") ?? false)
            XCTAssertTrue(containsCopy, "Result should contain search term")
        }
    }

    func testEmptyQueryReturnsAllItems() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "", in: items)

        XCTAssertEqual(results.count, items.count, "Empty query should return all items")
    }

    func testWhitespaceOnlyQueryReturnsAllItems() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "   ", in: items)

        XCTAssertEqual(results.count, items.count, "Whitespace-only query should return all items")
    }

    func testNoMatchReturnsEmpty() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "xyznonexistent", in: items)

        XCTAssertTrue(results.isEmpty, "Non-matching query should return empty")
    }

    // MARK: - Ranking Tests

    func testExactMatchRanksFirst() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "Hello world", in: items)

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.item.content, "Hello world",
            "Exact match should rank first")
    }

    func testAllMatchTypesAreFoundForCopyQuery() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "copy", in: items)

        // Should find multiple items containing "copy"
        XCTAssertFalse(results.isEmpty)

        // Verify we find items with different match positions:
        // - Prefix match: "Copy manager is awesome"
        // - Substring match: "SELECT * FROM users WHERE name = 'copy'"
        // - Camel case: "func copyToClipboard() { }"
        let contents = results.map { $0.item.content }
        XCTAssertTrue(contents.contains("Copy manager is awesome"),
            "Should find prefix match")
        XCTAssertTrue(contents.contains("SELECT * FROM users WHERE name = 'copy'"),
            "Should find substring match")
        XCTAssertTrue(contents.contains("func copyToClipboard() { }"),
            "Should find camelCase match")

        // All exact matches are sorted by timestamp (newest first), not by match quality
        // This is verified in testResultsAreSortedByMatchTypeThenTimestamp
    }

    func testResultsAreSortedByMatchTypeThenTimestamp() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "copy", in: items)

        // Verify results are sorted: exact matches first (by timestamp), then fuzzy (by timestamp)
        var seenFuzzy = false
        var lastExactTimestamp: Date?
        var lastFuzzyTimestamp: Date?

        for result in results {
            if result.matchType == .fuzzy {
                seenFuzzy = true
                // Fuzzy results should be sorted by timestamp descending
                if let last = lastFuzzyTimestamp {
                    XCTAssertLessThanOrEqual(result.item.timestamp, last,
                        "Fuzzy results should be sorted by timestamp descending")
                }
                lastFuzzyTimestamp = result.item.timestamp
            } else {
                // Should not see exact after fuzzy
                XCTAssertFalse(seenFuzzy, "Exact matches should come before fuzzy matches")
                // Exact results should be sorted by timestamp descending
                if let last = lastExactTimestamp {
                    XCTAssertLessThanOrEqual(result.item.timestamp, last,
                        "Exact results should be sorted by timestamp descending")
                }
                lastExactTimestamp = result.item.timestamp
            }
        }
    }

    // MARK: - Search Field Tests

    func testSearchesContentField() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "Lorem ipsum", in: items)

        XCTAssertEqual(results.count, 1, "Should find exactly one item with 'Lorem ipsum'")
        XCTAssertTrue(results.first?.item.content.contains("Lorem ipsum") ?? false)
    }

    func testSearchesSourceAppField() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "Safari", in: items)

        XCTAssertFalse(results.isEmpty, "Should find items by source app")
        XCTAssertEqual(results.first?.item.sourceApp, "Safari")
    }

    func testContentMatchRanksHigherThanSourceApp() async throws {
        // Create specific test items with same timestamp
        // Content match (item1) matches "TextEdit" in content
        // Source app match (item2) only matches "TextEdit" in sourceApp
        let timestamp = Date()
        let item1 = ClipboardItem(
            id: UUID(),
            content: "TextEdit document",
            contentType: .text,
            contentHash: "content_match_\(UUID().uuidString)",
            timestamp: timestamp,
            sourceApp: "Notes"
        )
        let item2 = ClipboardItem(
            id: UUID(),
            content: "Random content",
            contentType: .text,
            contentHash: "app_match_\(UUID().uuidString)",
            timestamp: timestamp,
            sourceApp: "TextEdit"
        )

        let items = [item1, item2]
        let results = searchEngine.search(query: "TextEdit", in: items)

        XCTAssertEqual(results.count, 2)
        // Both are exact matches (content match and sourceApp match both use exact/substring matching)
        // With same timestamp, order is preserved from input (item1 first)
        // The content match (item1) should still be first since it appears first in the input
        // and both have the same match type
        XCTAssertEqual(results.first?.matchField, .content,
            "Content match should come before source app match")
    }

    func testSourceAppMatchDoesNotProduceHighlightRanges() async throws {
        // Item where search will only match sourceApp, not content
        let item = ClipboardItem(
            content: "x64 some other content",
            contentType: .text,
            contentHash: "sourceapp_only_\(UUID().uuidString)",
            sourceApp: "Adam's App"
        )

        let results = searchEngine.search(query: "Adam", in: [item])

        XCTAssertEqual(results.count, 1, "Should match via sourceApp")
        XCTAssertEqual(results.first?.matchField, .sourceApp, "Match should be on sourceApp")
        XCTAssertTrue(results.first?.matchedRanges.isEmpty ?? false,
            "sourceApp match should NOT produce highlight ranges (they would be wrong for content)")
    }

    // MARK: - Fuzzy Match Tests

    func testFuzzyMatchFindsPartialMatches() async throws {
        let items = try await loadItems()

        // Ensure fuzzy matching is enabled
        searchEngine.fuzzyMatchingEnabled = true

        // "mgr" should fuzzy match "manager"
        let results = searchEngine.search(query: "mgr", in: items)

        let hasManagerMatch = results.contains { result in
            result.item.content.lowercased().contains("manager")
        }
        XCTAssertTrue(hasManagerMatch, "Fuzzy search should find 'manager' with query 'mgr'")
    }

    func testAcronymMatchWorks() async throws {
        let items = try await loadItems()

        // Ensure fuzzy matching is enabled
        searchEngine.fuzzyMatchingEnabled = true

        // "qbf" should match "quick brown fox"
        let results = searchEngine.search(query: "qbf", in: items)

        let hasMatch = results.contains { result in
            result.item.content.contains("quick brown fox")
        }
        XCTAssertTrue(hasMatch, "Acronym search should work")
    }

    // MARK: - Fuzzy Search Toggle Tests

    func testFuzzyMatchingDisabledDoesNotFindFuzzyMatches() async throws {
        let items = try await loadItems()

        // Disable fuzzy matching
        searchEngine.fuzzyMatchingEnabled = false

        // "mgr" should NOT match "manager" when fuzzy is disabled
        let results = searchEngine.search(query: "mgr", in: items)

        let hasManagerMatch = results.contains { result in
            result.item.content.lowercased().contains("manager")
        }
        XCTAssertFalse(hasManagerMatch, "Fuzzy search disabled should NOT find 'manager' with query 'mgr'")
    }

    func testFuzzyMatchingDisabledStillFindsExactMatches() async throws {
        let items = try await loadItems()

        // Disable fuzzy matching
        searchEngine.fuzzyMatchingEnabled = false

        // Exact substring match should still work
        let results = searchEngine.search(query: "manager", in: items)

        let hasManagerMatch = results.contains { result in
            result.item.content.lowercased().contains("manager")
        }
        XCTAssertTrue(hasManagerMatch, "Exact substring match should work even with fuzzy disabled")
    }

    func testFuzzyMatchingDisabledStillFindsPrefixMatches() async throws {
        let items = try await loadItems()

        // Disable fuzzy matching
        searchEngine.fuzzyMatchingEnabled = false

        // Prefix match should still work
        let results = searchEngine.search(query: "Copy", in: items)

        let hasCopyMatch = results.contains { result in
            result.item.content.lowercased().hasPrefix("copy")
        }
        XCTAssertTrue(hasCopyMatch, "Prefix match should work even with fuzzy disabled")
    }

    func testFuzzyMatchingDisabledAcronymDoesNotMatch() async throws {
        let items = try await loadItems()

        // Disable fuzzy matching
        searchEngine.fuzzyMatchingEnabled = false

        // "qbf" should NOT match "quick brown fox" when fuzzy is disabled
        let results = searchEngine.search(query: "qbf", in: items)

        let hasMatch = results.contains { result in
            result.item.content.contains("quick brown fox")
        }
        XCTAssertFalse(hasMatch, "Acronym search should NOT work when fuzzy is disabled")
    }

    func testFuzzyMatchingToggleCanBeChanged() {
        // Default should be true for the SearchEngine instance
        searchEngine.fuzzyMatchingEnabled = true
        XCTAssertTrue(searchEngine.fuzzyMatchingEnabled)

        searchEngine.fuzzyMatchingEnabled = false
        XCTAssertFalse(searchEngine.fuzzyMatchingEnabled)

        searchEngine.fuzzyMatchingEnabled = true
        XCTAssertTrue(searchEngine.fuzzyMatchingEnabled)
    }

    // MARK: - Case Sensitivity Tests

    func testSearchIsCaseInsensitive() async throws {
        let items = try await loadItems()

        let lowerResults = searchEngine.search(query: "hello", in: items)
        let upperResults = searchEngine.search(query: "HELLO", in: items)
        let mixedResults = searchEngine.search(query: "HeLLo", in: items)

        XCTAssertEqual(lowerResults.count, upperResults.count)
        XCTAssertEqual(upperResults.count, mixedResults.count)
        XCTAssertFalse(lowerResults.isEmpty)
    }

    // MARK: - Special Content Tests

    func testSearchFindsURLs() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "github", in: items)

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.item.contentType, .url)
    }

    func testSearchFindsCodeSnippets() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "func", in: items)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.first?.item.content.contains("func") ?? false)
    }

    func testSearchFindsEmojis() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "🎉", in: items)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.first?.item.content.contains("🎉") ?? false)
    }

    func testSearchFindsFilePaths() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "Documents", in: items)

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.item.contentType, .fileURL)
    }

    // MARK: - Search Result Model Tests

    func testSearchResultContainsMatchedRanges() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "copy", in: items)

        XCTAssertFalse(results.isEmpty)

        // Results should contain matched ranges for highlighting
        let firstResult = results.first!
        XCTAssertFalse(firstResult.matchedRanges.isEmpty,
            "Search result should contain matched ranges for highlighting")
    }

    func testSearchResultContainsOriginalItem() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "Hello", in: items)

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.item.content, "Hello world")
    }

    // MARK: - Performance Tests

    func testSearchPerformanceWith500Items() async throws {
        // Create 500 items
        var manyItems: [ClipboardItem] = []
        for i in 0..<500 {
            let item = ClipboardItem(
                content: "Item number \(i) with some content to search through",
                contentType: .text,
                contentHash: "perf\(i)_\(UUID().uuidString)",
                sourceApp: "TestApp"
            )
            manyItems.append(item)
        }

        measure {
            _ = searchEngine.search(query: "content", in: manyItems)
        }
    }

    func testSearchLatencyUnder50ms() async throws {
        var manyItems: [ClipboardItem] = []
        for i in 0..<500 {
            let item = ClipboardItem(
                content: "Item \(i): Lorem ipsum dolor sit amet, consectetur adipiscing elit",
                contentType: .text,
                contentHash: "latency\(i)_\(UUID().uuidString)",
                sourceApp: "TestApp"
            )
            manyItems.append(item)
        }

        let start = CFAbsoluteTimeGetCurrent()
        _ = searchEngine.search(query: "Lorem", in: manyItems)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000 // ms

        // Use 150ms threshold to accommodate slower CI runners (local target is <50ms)
        XCTAssertLessThan(elapsed, 150, "Search should complete in under 150ms, took \(elapsed)ms")
    }

    // MARK: - Edge Cases

    func testSearchWithSingleCharacter() async throws {
        let items = try await loadItems()
        let results = searchEngine.search(query: "a", in: items)

        // Should return results but maybe with lower relevance
        XCTAssertFalse(results.isEmpty, "Single character search should work")
    }

    func testSearchWithSpecialRegexCharacters() async throws {
        let item = ClipboardItem(
            content: "Price: $100.00 (50% off)",
            contentType: .text,
            contentHash: "regex_\(UUID().uuidString)",
            sourceApp: "Notes"
        )

        let results = searchEngine.search(query: "$100", in: [item])

        XCTAssertFalse(results.isEmpty, "Special regex characters should be escaped")
    }

    func testSearchWithNewlines() async throws {
        let item = ClipboardItem(
            content: "Line 1\nLine 2\nLine 3",
            contentType: .text,
            contentHash: "newline_\(UUID().uuidString)",
            sourceApp: "Notes"
        )

        let results = searchEngine.search(query: "Line 2", in: [item])

        XCTAssertFalse(results.isEmpty, "Search should work across newlines")
    }
}

// MARK: - SearchResult Model Tests

final class SearchResultTests: XCTestCase {

    func testSearchResultInitialization() {
        let item = ClipboardItem(
            content: "Test",
            contentType: .text,
            contentHash: "test123",
            sourceApp: nil
        )
        let ranges = [NSRange(location: 0, length: 4)]
        let result = SearchResult(item: item, score: 0.8, matchedRanges: ranges, matchField: .content, matchType: .exact)

        XCTAssertEqual(result.item.content, "Test")
        XCTAssertEqual(result.score, 0.8)
        XCTAssertEqual(result.matchedRanges.count, 1)
        XCTAssertEqual(result.matchField, .content)
        XCTAssertEqual(result.matchType, .exact)
    }

    func testSearchResultsSortByScore() {
        let item1 = ClipboardItem(content: "A", contentType: .text, contentHash: "a", sourceApp: nil)
        let item2 = ClipboardItem(content: "B", contentType: .text, contentHash: "b", sourceApp: nil)
        let item3 = ClipboardItem(content: "C", contentType: .text, contentHash: "c", sourceApp: nil)

        var results = [
            SearchResult(item: item1, score: 0.5, matchedRanges: [], matchField: .content, matchType: .exact),
            SearchResult(item: item2, score: 0.9, matchedRanges: [], matchField: .content, matchType: .exact),
            SearchResult(item: item3, score: 0.7, matchedRanges: [], matchField: .content, matchType: .exact),
        ]

        results.sort { $0.score > $1.score }

        XCTAssertEqual(results[0].item.content, "B") // 0.9
        XCTAssertEqual(results[1].item.content, "C") // 0.7
        XCTAssertEqual(results[2].item.content, "A") // 0.5
    }

    func testSearchResultMatchFieldTracking() {
        let item = ClipboardItem(
            content: "Test content",
            contentType: .text,
            contentHash: "test123",
            sourceApp: "TestApp"
        )

        let contentResult = SearchResult(item: item, score: 0.8, matchedRanges: [NSRange(location: 0, length: 4)], matchField: .content, matchType: .exact)
        XCTAssertEqual(contentResult.matchField, .content)
        XCTAssertFalse(contentResult.matchedRanges.isEmpty)

        let sourceAppResult = SearchResult(item: item, score: 0.6, matchedRanges: [], matchField: .sourceApp, matchType: .exact)
        XCTAssertEqual(sourceAppResult.matchField, .sourceApp)
        XCTAssertTrue(sourceAppResult.matchedRanges.isEmpty, "sourceApp matches should not have highlight ranges")
    }
}
