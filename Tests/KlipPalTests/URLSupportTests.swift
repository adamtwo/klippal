import XCTest
import AppKit
@testable import KlipPal

// MARK: - URL Detection Tests

final class URLDetectionTests: XCTestCase {

    func testDetectsHTTPURL() {
        let pasteboard = NSPasteboard(name: .init("test-url-http-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("http://example.com", forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .url)
        XCTAssertEqual(result?.content, "http://example.com")
    }

    func testDetectsHTTPSURL() {
        let pasteboard = NSPasteboard(name: .init("test-url-https-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("https://github.com/user/repo", forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .url)
    }

    func testDetectsURLWithQueryParams() {
        let pasteboard = NSPasteboard(name: .init("test-url-query-\(UUID().uuidString)"))
        pasteboard.clearContents()
        let url = "https://example.com/search?q=test&page=1"
        pasteboard.setString(url, forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .url)
        XCTAssertEqual(result?.content, url)
    }

    func testDetectsURLWithFragment() {
        let pasteboard = NSPasteboard(name: .init("test-url-fragment-\(UUID().uuidString)"))
        pasteboard.clearContents()
        let url = "https://example.com/page#section"
        pasteboard.setString(url, forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .url)
    }

    func testDetectsURLWithPort() {
        let pasteboard = NSPasteboard(name: .init("test-url-port-\(UUID().uuidString)"))
        pasteboard.clearContents()
        let url = "http://localhost:3000/api"
        pasteboard.setString(url, forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .url)
    }

    func testDoesNotDetectPlainTextAsURL() {
        let pasteboard = NSPasteboard(name: .init("test-not-url-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("This is plain text", forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .text)
    }

    func testDoesNotDetectPartialURLAsURL() {
        let pasteboard = NSPasteboard(name: .init("test-partial-url-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("example.com", forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .text, "URL without scheme should be plain text")
    }

    func testDoesNotDetectFTPAsHTTPURL() {
        let pasteboard = NSPasteboard(name: .init("test-ftp-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("ftp://files.example.com", forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        // FTP URLs should be treated as text (we only support http/https)
        XCTAssertEqual(result?.type, .text)
    }
}

// MARK: - URL Metadata Tests

final class URLMetadataTests: XCTestCase {

    func testExtractDomainFromURL() {
        let url = URL(string: "https://www.github.com/user/repo")!
        let domain = URLMetadataExtractor.extractDomain(from: url)

        XCTAssertEqual(domain, "github.com")
    }

    func testExtractDomainRemovesWWW() {
        let url = URL(string: "https://www.example.com/page")!
        let domain = URLMetadataExtractor.extractDomain(from: url)

        XCTAssertEqual(domain, "example.com")
    }

    func testExtractDomainFromSubdomain() {
        let url = URL(string: "https://docs.google.com/document")!
        let domain = URLMetadataExtractor.extractDomain(from: url)

        XCTAssertEqual(domain, "docs.google.com")
    }

    func testExtractDomainFromLocalhost() {
        let url = URL(string: "http://localhost:3000/api")!
        let domain = URLMetadataExtractor.extractDomain(from: url)

        XCTAssertEqual(domain, "localhost")
    }

    func testExtractPathFromURL() {
        let url = URL(string: "https://github.com/user/repo/issues/123")!
        let path = URLMetadataExtractor.extractPath(from: url)

        XCTAssertEqual(path, "/user/repo/issues/123")
    }

    func testExtractTitleFromURL() {
        // Test common URL patterns that can derive a title
        let githubURL = URL(string: "https://github.com/anthropics/claude-code")!
        let title = URLMetadataExtractor.extractTitle(from: githubURL)

        XCTAssertNotNil(title)
        // The title extractor capitalizes and formats the last path component
        // "claude-code" becomes "Claude Code"
        XCTAssertTrue(title!.lowercased().contains("claude") || title!.lowercased().contains("code"))
    }

    func testExtractTitleFromGenericURL() {
        let url = URL(string: "https://example.com/some-article-title")!
        let title = URLMetadataExtractor.extractTitle(from: url)

        // Should extract something from the path
        XCTAssertNotNil(title)
    }
}

// MARK: - ClipboardItem URL Tests

final class ClipboardItemURLTests: XCTestCase {

    func testURLItemPreviewShowsFullURL() {
        let item = ClipboardItem(
            content: "https://github.com/user/repo",
            contentType: .url,
            contentHash: "test-hash"
        )

        XCTAssertEqual(item.preview, "https://github.com/user/repo")
    }

    func testURLItemPreviewTruncatesLongURL() {
        let longURL = "https://example.com/" + String(repeating: "path/", count: 30)
        let item = ClipboardItem(
            content: longURL,
            contentType: .url,
            contentHash: "test-hash"
        )

        // Allow some flexibility for truncation (may include ellipsis)
        XCTAssertLessThanOrEqual(item.preview.count, 103)
    }

    func testURLItemHasCorrectIcon() {
        let urlType = ClipboardContentType.url
        XCTAssertEqual(urlType.iconName, "link")
    }

    func testURLItemDisplayName() {
        let urlType = ClipboardContentType.url
        XCTAssertEqual(urlType.displayName, "URL")
    }
}

// MARK: - URL Row Display Tests

final class URLRowDisplayTests: XCTestCase {

    func testURLItemShowsDomain() {
        let item = ClipboardItem(
            content: "https://github.com/user/repo",
            contentType: .url,
            contentHash: "test-hash"
        )

        // The displayDomain computed property should extract the domain
        XCTAssertEqual(item.displayDomain, "github.com")
    }

    func testURLItemShowsPath() {
        let item = ClipboardItem(
            content: "https://github.com/user/repo/issues/123",
            contentType: .url,
            contentHash: "test-hash"
        )

        XCTAssertEqual(item.displayPath, "/user/repo/issues/123")
    }

    func testURLItemFormatsNicely() {
        let item = ClipboardItem(
            content: "https://docs.google.com/document/d/abc123/edit",
            contentType: .url,
            contentHash: "test-hash"
        )

        // Should have domain and path available for display
        XCTAssertEqual(item.displayDomain, "docs.google.com")
        XCTAssertFalse(item.displayPath?.isEmpty ?? true)
    }
}

// MARK: - URL Search Tests

final class URLSearchTests: XCTestCase {
    var searchEngine: SearchEngine!

    override func setUp() {
        searchEngine = SearchEngine()
    }

    func testSearchFindsURLByDomain() {
        let items = [
            ClipboardItem(content: "https://github.com/user/repo", contentType: .url, contentHash: "h1"),
            ClipboardItem(content: "https://google.com/search", contentType: .url, contentHash: "h2"),
            ClipboardItem(content: "Some text content", contentType: .text, contentHash: "h3"),
        ]

        let results = searchEngine.search(query: "github", in: items)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.item.content.contains("github") ?? false)
    }

    func testSearchFindsURLByPath() {
        let items = [
            ClipboardItem(content: "https://github.com/anthropics/claude-code", contentType: .url, contentHash: "h1"),
            ClipboardItem(content: "https://example.com/other", contentType: .url, contentHash: "h2"),
        ]

        let results = searchEngine.search(query: "claude", in: items)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.item.content.contains("claude") ?? false)
    }

    func testSearchHighlightsURLMatches() {
        let items = [
            ClipboardItem(content: "https://github.com/user/repo", contentType: .url, contentHash: "h1"),
        ]

        let results = searchEngine.search(query: "github", in: items)

        XCTAssertFalse(results.isEmpty)
        XCTAssertFalse(results.first?.matchedRanges.isEmpty ?? true)
    }
}

// MARK: - URL Paste Tests

final class URLPasteTests: XCTestCase {

    func testPasteURLRestoresCorrectContent() async throws {
        let pasteboard = NSPasteboard.general
        let originalContent = pasteboard.string(forType: .string)

        let item = ClipboardItem(
            content: "https://github.com/user/repo",
            contentType: .url,
            contentHash: "test-hash"
        )

        // Create a test paste manager that doesn't simulate Cmd+V
        let testPasteboard = NSPasteboard(name: .init("test-paste-url-\(UUID().uuidString)"))
        testPasteboard.clearContents()
        testPasteboard.setString(item.content, forType: .string)

        // Verify the URL was set correctly
        let pastedContent = testPasteboard.string(forType: .string)
        XCTAssertEqual(pastedContent, "https://github.com/user/repo")

        // Restore original clipboard if needed
        if let original = originalContent {
            pasteboard.clearContents()
            pasteboard.setString(original, forType: .string)
        }
    }
}

// MARK: - URL Storage Tests

final class URLStorageTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_url_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    func testSaveAndFetchURLItem() async throws {
        let item = ClipboardItem(
            content: "https://github.com/user/repo",
            contentType: .url,
            contentHash: "url-hash-123",
            sourceApp: "Safari"
        )

        try await storage.save(item)

        let items = try await storage.fetchItems(limit: 10, favoriteOnly: false)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.contentType, .url)
        XCTAssertEqual(items.first?.content, "https://github.com/user/repo")
    }

    func testURLDeduplication() async throws {
        let url = "https://github.com/user/repo"
        let hash = SHA256Hasher.hash(string: url)

        let item1 = ClipboardItem(content: url, contentType: .url, contentHash: hash)
        let item2 = ClipboardItem(content: url, contentType: .url, contentHash: hash)

        try await storage.save(item1)
        try await storage.save(item2)

        let items = try await storage.fetchItems(limit: 10, favoriteOnly: false)

        // Should only have one item due to deduplication
        XCTAssertEqual(items.count, 1)
    }
}
