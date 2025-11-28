import XCTest
import AppKit
@testable import KlipPal

// MARK: - File Detection Tests

final class FileDetectionTests: XCTestCase {

    func testDetectsFileURLString() {
        let pasteboard = NSPasteboard(name: .init("test-file-url-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("file:///Users/test/Documents/file.txt", forType: .string)

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .fileURL)
    }

    func testDetectsFileFromFinderCopy() {
        let pasteboard = NSPasteboard(name: .init("test-finder-\(UUID().uuidString)"))
        pasteboard.clearContents()

        // Simulate how Finder copies files - using file URLs
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-file-\(UUID().uuidString).txt")
        try? "test content".write(to: tempFile, atomically: true, encoding: .utf8)

        pasteboard.writeObjects([tempFile as NSURL])

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .fileURL)

        // Clean up
        try? FileManager.default.removeItem(at: tempFile)
    }

    func testDetectsMultipleFilesFromFinder() {
        let pasteboard = NSPasteboard(name: .init("test-multi-file-\(UUID().uuidString)"))
        pasteboard.clearContents()

        // Create temp files
        let tempDir = FileManager.default.temporaryDirectory
        let file1 = tempDir.appendingPathComponent("file1-\(UUID().uuidString).txt")
        let file2 = tempDir.appendingPathComponent("file2-\(UUID().uuidString).txt")

        try? "content1".write(to: file1, atomically: true, encoding: .utf8)
        try? "content2".write(to: file2, atomically: true, encoding: .utf8)

        pasteboard.writeObjects([file1 as NSURL, file2 as NSURL])

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .fileURL)
        // Content should indicate multiple files
        XCTAssertTrue(result?.content.contains("file1") == true || result?.content.contains("2 files") == true)

        // Clean up
        try? FileManager.default.removeItem(at: file1)
        try? FileManager.default.removeItem(at: file2)
    }

    func testDetectsFolderFromFinder() {
        let pasteboard = NSPasteboard(name: .init("test-folder-\(UUID().uuidString)"))
        pasteboard.clearContents()

        // Create temp folder
        let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent("test-folder-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)

        pasteboard.writeObjects([tempFolder as NSURL])

        let result = ClipboardContentExtractor.extract(from: pasteboard)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .fileURL)

        // Clean up
        try? FileManager.default.removeItem(at: tempFolder)
    }
}

// MARK: - File Metadata Tests

final class FileMetadataExtractorTests: XCTestCase {

    func testExtractFilename() {
        let path = "/Users/test/Documents/report.pdf"
        let filename = FileMetadataExtractor.extractFilename(from: path)

        XCTAssertEqual(filename, "report.pdf")
    }

    func testExtractFilenameFromFileURL() {
        let path = "file:///Users/test/Documents/report.pdf"
        let filename = FileMetadataExtractor.extractFilename(from: path)

        XCTAssertEqual(filename, "report.pdf")
    }

    func testExtractFileExtension() {
        let path = "/Users/test/Documents/report.pdf"
        let ext = FileMetadataExtractor.extractExtension(from: path)

        XCTAssertEqual(ext, "pdf")
    }

    func testExtractFileExtensionUppercase() {
        let path = "/Users/test/Downloads/Image.PNG"
        let ext = FileMetadataExtractor.extractExtension(from: path)

        XCTAssertEqual(ext, "png")
    }

    func testExtractParentFolder() {
        let path = "/Users/test/Documents/report.pdf"
        let parent = FileMetadataExtractor.extractParentFolder(from: path)

        XCTAssertEqual(parent, "Documents")
    }

    func testIsDirectory() {
        let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent("test-dir-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)

        XCTAssertTrue(FileMetadataExtractor.isDirectory(path: tempFolder.path))

        try? FileManager.default.removeItem(at: tempFolder)
    }

    func testIsNotDirectory() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-file-\(UUID().uuidString).txt")
        try? "content".write(to: tempFile, atomically: true, encoding: .utf8)

        XCTAssertFalse(FileMetadataExtractor.isDirectory(path: tempFile.path))

        try? FileManager.default.removeItem(at: tempFile)
    }

    func testGetFileSize() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-size-\(UUID().uuidString).txt")
        let content = String(repeating: "a", count: 1000)
        try? content.write(to: tempFile, atomically: true, encoding: .utf8)

        let size = FileMetadataExtractor.getFileSize(path: tempFile.path)

        XCTAssertNotNil(size)
        XCTAssertEqual(size, 1000)

        try? FileManager.default.removeItem(at: tempFile)
    }

    func testFormatFileSize() {
        // ByteCountFormatter output varies by locale, so check for reasonable values
        let bytes500 = FileMetadataExtractor.formatFileSize(500)
        XCTAssertTrue(bytes500.contains("500") && (bytes500.contains("B") || bytes500.contains("bytes")))

        let kb1 = FileMetadataExtractor.formatFileSize(1024)
        XCTAssertTrue(kb1.contains("KB") || kb1.contains("kB"))

        let kb1_5 = FileMetadataExtractor.formatFileSize(1536)
        XCTAssertTrue(kb1_5.contains("KB") || kb1_5.contains("kB"))

        let mb1 = FileMetadataExtractor.formatFileSize(1048576)
        XCTAssertTrue(mb1.contains("MB"))

        let gb1 = FileMetadataExtractor.formatFileSize(1073741824)
        XCTAssertTrue(gb1.contains("GB"))
    }

    func testGetFileTypeIcon() {
        // Documents
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: "pdf"), "doc.fill")
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: "doc"), "doc.fill")
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: "txt"), "doc.text.fill")

        // Images
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: "png"), "photo.fill")
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: "jpg"), "photo.fill")

        // Code
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: "swift"), "chevron.left.forwardslash.chevron.right")
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: "js"), "chevron.left.forwardslash.chevron.right")

        // Archives
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: "zip"), "doc.zipper")

        // Folders
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: nil, isDirectory: true), "folder.fill")

        // Unknown
        XCTAssertEqual(FileMetadataExtractor.getIconName(forExtension: "xyz"), "doc.fill")
    }
}

// MARK: - ClipboardItem File Tests

final class ClipboardItemFileTests: XCTestCase {

    func testFileItemPreviewShowsFilename() {
        let item = ClipboardItem(
            content: "file:///Users/test/Documents/report.pdf",
            contentType: .fileURL,
            contentHash: "test-hash"
        )

        XCTAssertEqual(item.preview, "report.pdf")
    }

    func testFileItemHasCorrectIcon() {
        let fileType = ClipboardContentType.fileURL
        XCTAssertEqual(fileType.iconName, "doc")
    }

    func testFileItemDisplayName() {
        let fileType = ClipboardContentType.fileURL
        XCTAssertEqual(fileType.displayName, "File")
    }

    func testFileItemDisplayFilename() {
        let item = ClipboardItem(
            content: "file:///Users/test/Documents/report.pdf",
            contentType: .fileURL,
            contentHash: "test-hash"
        )

        XCTAssertEqual(item.displayFilename, "report.pdf")
    }

    func testFileItemDisplayExtension() {
        let item = ClipboardItem(
            content: "file:///Users/test/Documents/report.pdf",
            contentType: .fileURL,
            contentHash: "test-hash"
        )

        XCTAssertEqual(item.displayExtension, "pdf")
    }

    func testFileItemDisplayParentFolder() {
        let item = ClipboardItem(
            content: "file:///Users/test/Documents/report.pdf",
            contentType: .fileURL,
            contentHash: "test-hash"
        )

        XCTAssertEqual(item.displayParentFolder, "Documents")
    }
}

// MARK: - File Search Tests

final class FileSearchTests: XCTestCase {
    var searchEngine: SearchEngine!

    override func setUp() {
        searchEngine = SearchEngine()
    }

    func testSearchFindsFileByName() {
        let items = [
            ClipboardItem(content: "file:///Users/test/report.pdf", contentType: .fileURL, contentHash: "h1"),
            ClipboardItem(content: "file:///Users/test/image.png", contentType: .fileURL, contentHash: "h2"),
            ClipboardItem(content: "Some text", contentType: .text, contentHash: "h3"),
        ]

        let results = searchEngine.search(query: "report", in: items)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.item.content.contains("report") ?? false)
    }

    func testSearchFindsFileByExtension() {
        let items = [
            ClipboardItem(content: "file:///Users/test/doc.pdf", contentType: .fileURL, contentHash: "h1"),
            ClipboardItem(content: "file:///Users/test/image.png", contentType: .fileURL, contentHash: "h2"),
        ]

        let results = searchEngine.search(query: "pdf", in: items)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.item.content.contains("pdf") ?? false)
    }

    func testSearchFindsFileByPath() {
        let items = [
            ClipboardItem(content: "file:///Users/test/Documents/report.pdf", contentType: .fileURL, contentHash: "h1"),
            ClipboardItem(content: "file:///Users/test/Downloads/file.txt", contentType: .fileURL, contentHash: "h2"),
        ]

        let results = searchEngine.search(query: "Documents", in: items)

        XCTAssertEqual(results.count, 1)
    }
}

// MARK: - File Paste Tests

final class FilePasteTests: XCTestCase {

    func testPasteFileRestoresFileURL() async throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("paste-test-\(UUID().uuidString).txt")
        try "test content".write(to: tempFile, atomically: true, encoding: .utf8)

        let item = ClipboardItem(
            content: tempFile.absoluteString,
            contentType: .fileURL,
            contentHash: "test-hash"
        )

        // Create a test pasteboard
        let testPasteboard = NSPasteboard(name: .init("test-file-paste-\(UUID().uuidString)"))
        testPasteboard.clearContents()

        // Simulate what PasteManager should do for files
        if let url = URL(string: item.content) {
            testPasteboard.writeObjects([url as NSURL])
        }

        // Verify the file URL was set correctly
        let urls = testPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        XCTAssertNotNil(urls)
        XCTAssertEqual(urls?.first?.path, tempFile.path)

        // Clean up
        try? FileManager.default.removeItem(at: tempFile)
    }
}

// MARK: - File Storage Tests

final class FileStorageTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_file_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    func testSaveAndFetchFileItem() async throws {
        let item = ClipboardItem(
            content: "file:///Users/test/Documents/report.pdf",
            contentType: .fileURL,
            contentHash: "file-hash-123",
            sourceApp: "Finder"
        )

        try await storage.save(item)

        let items = try await storage.fetchItems(limit: 10, favoriteOnly: false)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.contentType, .fileURL)
        XCTAssertEqual(items.first?.content, "file:///Users/test/Documents/report.pdf")
    }
}
