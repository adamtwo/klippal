import XCTest
import AppKit
@testable import KlipPal

/// Tests for paste as plain text functionality (Shift+Enter or Shift+double-click)
final class PasteAsPlainTextTests: XCTestCase {
    var storage: SQLiteStorageEngine!
    var tempDBPath: String!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_paste_plain_\(UUID().uuidString).db").path
        storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Set up AppDelegate.shared for ViewModel to use
        let appDelegate = AppDelegate()
        appDelegate.storage = storage
        AppDelegate.shared = appDelegate
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - Key Code Constants

    struct KeyCodes {
        static let returnKey: UInt16 = 36
    }

    // MARK: - Event Creation Helper

    func createKeyEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) -> NSEvent? {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }

    // MARK: - PasteManager Tests

    @MainActor
    func testPasteManagerPasteAsPlainTextForRichText() async throws {
        // Create RTF content
        let rtfString = "{\\rtf1\\ansi Hello World}"
        guard let rtfData = rtfString.data(using: .utf8) else {
            XCTFail("Failed to create RTF data")
            return
        }

        let item = ClipboardItem(
            content: "Hello World",
            contentType: .richText,
            contentHash: "plaintext_rtf_\(UUID().uuidString)",
            sourceApp: "TestApp",
            blobContent: rtfData
        )
        try await storage.save(item)

        let pasteManager = PasteManager(storage: storage)

        // Clear the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Paste as plain text (don't actually simulate Cmd+V for testing)
        try await pasteManager.restoreToClipboard(item, asPlainText: true)

        // Verify only plain text was written
        XCTAssertNotNil(pasteboard.string(forType: .string), "Plain text should be on clipboard")
        XCTAssertNil(pasteboard.data(forType: .rtf), "RTF data should NOT be on clipboard when pasting as plain text")
    }

    @MainActor
    func testPasteManagerPasteAsPlainTextForImage() async throws {
        // Create a simple 1x1 PNG image
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG data")
            return
        }

        let item = ClipboardItem(
            content: "[Image 1x1]",
            contentType: .image,
            contentHash: "plaintext_img_\(UUID().uuidString)",
            sourceApp: "TestApp",
            blobContent: pngData
        )
        try await storage.save(item)

        let pasteManager = PasteManager(storage: storage)

        // Clear the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Paste as plain text
        try await pasteManager.restoreToClipboard(item, asPlainText: true)

        // Verify plain text was written (the content description)
        let clipboardString = pasteboard.string(forType: .string)
        XCTAssertNotNil(clipboardString, "Plain text should be on clipboard")
        XCTAssertEqual(clipboardString, "[Image 1x1]", "Should paste the image description as plain text")
    }

    @MainActor
    func testPasteManagerPasteAsPlainTextForFileURL() async throws {
        let fileURLString = "file:///Users/test/document.pdf"

        let item = ClipboardItem(
            content: fileURLString,
            contentType: .fileURL,
            contentHash: "plaintext_file_\(UUID().uuidString)",
            sourceApp: "TestApp"
        )
        try await storage.save(item)

        let pasteManager = PasteManager(storage: storage)

        // Clear the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Paste as plain text
        try await pasteManager.restoreToClipboard(item, asPlainText: true)

        // Verify plain text was written (the file path)
        let clipboardString = pasteboard.string(forType: .string)
        XCTAssertNotNil(clipboardString, "Plain text should be on clipboard")
        XCTAssertEqual(clipboardString, fileURLString, "Should paste the file URL as plain text")
    }

    @MainActor
    func testPasteManagerNormalPastePreservesRichText() async throws {
        // Create RTF content
        let attributed = NSAttributedString(string: "Bold Text", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)])
        guard let rtfData = try? attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) else {
            XCTFail("Failed to create RTF data")
            return
        }

        let item = ClipboardItem(
            content: "Bold Text",
            contentType: .richText,
            contentHash: "normal_rtf_\(UUID().uuidString)",
            sourceApp: "TestApp",
            blobContent: rtfData
        )
        try await storage.save(item)

        let pasteManager = PasteManager(storage: storage)

        // Clear the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Normal paste (not as plain text)
        try await pasteManager.restoreToClipboard(item, asPlainText: false)

        // Verify RTF was preserved
        XCTAssertNotNil(pasteboard.data(forType: .rtf), "RTF data should be on clipboard for normal paste")
        XCTAssertNotNil(pasteboard.string(forType: .string), "Plain text fallback should also be on clipboard")
    }

    // MARK: - ViewModel Tests

    @MainActor
    func testViewModelPasteSelectedAsPlainText() async throws {
        // Create a rich text item
        let rtfString = "{\\rtf1\\ansi Test}"
        guard let rtfData = rtfString.data(using: .utf8) else {
            XCTFail("Failed to create RTF data")
            return
        }

        let item = ClipboardItem(
            content: "Test",
            contentType: .richText,
            contentHash: "vm_plaintext_\(UUID().uuidString)",
            sourceApp: "TestApp",
            blobContent: rtfData
        )
        try await storage.save(item)

        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()

        // Wait for items to load
        try await Task.sleep(nanoseconds: 200_000_000)

        var pasteTriggered = false
        viewModel.onBeforePaste = {
            pasteTriggered = true
        }

        // Paste selected as plain text
        viewModel.pasteSelected(asPlainText: true)

        // Wait for async paste
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(pasteTriggered, "Paste should be triggered")
    }

    @MainActor
    func testViewModelPasteItemAsPlainText() async throws {
        // Create an image item
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.blue.drawSwatch(in: NSRect(x: 0, y: 0, width: 10, height: 10))
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG data")
            return
        }

        let item = ClipboardItem(
            content: "[Image 10x10]",
            contentType: .image,
            contentHash: "vm_img_plaintext_\(UUID().uuidString)",
            sourceApp: "TestApp",
            blobContent: pngData
        )
        try await storage.save(item)

        let viewModel = OverlayViewModel(storage: storage)

        var pasteTriggered = false
        viewModel.onBeforePaste = {
            pasteTriggered = true
        }

        // Paste item as plain text
        viewModel.pasteItem(item, asPlainText: true)

        // Wait for async paste
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(pasteTriggered, "Paste should be triggered")
    }

    // MARK: - Key Handler Tests

    @MainActor
    func testShiftReturnTriggersPasteAsPlainText() async throws {
        let item = ClipboardItem(
            content: "Test content",
            contentType: .text,
            contentHash: "key_plaintext_\(UUID().uuidString)",
            sourceApp: "TestApp"
        )
        try await storage.save(item)

        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()

        try await Task.sleep(nanoseconds: 200_000_000)

        var plainTextPasteTriggered = false

        // Create a test key handler that tracks plain text paste
        let keyHandler = PlainTextAwareKeyHandler(viewModel: viewModel)
        keyHandler.onPlainTextPaste = {
            plainTextPasteTriggered = true
        }

        // Simulate Shift+Return
        if let shiftReturnEvent = createKeyEvent(keyCode: KeyCodes.returnKey, modifiers: .shift) {
            let handled = keyHandler.handleKeyDown(shiftReturnEvent)
            XCTAssertTrue(handled, "Shift+Return should be handled")
        }

        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(plainTextPasteTriggered, "Shift+Return should trigger paste as plain text")
    }

    @MainActor
    func testPlainReturnTriggersNormalPaste() async throws {
        let item = ClipboardItem(
            content: "Test content",
            contentType: .text,
            contentHash: "key_normal_\(UUID().uuidString)",
            sourceApp: "TestApp"
        )
        try await storage.save(item)

        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()

        try await Task.sleep(nanoseconds: 200_000_000)

        var normalPasteTriggered = false

        let keyHandler = PlainTextAwareKeyHandler(viewModel: viewModel)
        keyHandler.onNormalPaste = {
            normalPasteTriggered = true
        }

        // Simulate plain Return (no modifiers)
        if let returnEvent = createKeyEvent(keyCode: KeyCodes.returnKey) {
            let handled = keyHandler.handleKeyDown(returnEvent)
            XCTAssertTrue(handled, "Return should be handled")
        }

        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(normalPasteTriggered, "Plain Return should trigger normal paste")
    }

    // MARK: - Database Preservation Tests

    @MainActor
    func testPasteAsPlainTextDoesNotModifyStoredContent() async throws {
        // Create RTF content
        let attributed = NSAttributedString(string: "Formatted", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)])
        guard let rtfData = try? attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) else {
            XCTFail("Failed to create RTF data")
            return
        }

        let contentHash = "preserve_\(UUID().uuidString)"
        let item = ClipboardItem(
            content: "Formatted",
            contentType: .richText,
            contentHash: contentHash,
            sourceApp: "TestApp",
            blobContent: rtfData
        )
        try await storage.save(item)

        let pasteManager = PasteManager(storage: storage)

        // Paste as plain text
        try await pasteManager.restoreToClipboard(item, asPlainText: true)

        // Verify stored content is unchanged
        let storedBlob = try await storage.fetchBlobContent(byHash: contentHash)
        XCTAssertNotNil(storedBlob, "Blob content should still exist in database")
        XCTAssertEqual(storedBlob, rtfData, "Blob content should be unchanged after paste as plain text")

        // Verify item type is unchanged
        let items = try await storage.fetchItems(limit: 10)
        let storedItem = items.first { $0.contentHash == contentHash }
        XCTAssertNotNil(storedItem, "Item should still exist")
        XCTAssertEqual(storedItem?.contentType, .richText, "Content type should be unchanged")
    }

    @MainActor
    func testPasteAsPlainTextUpdatesTimestamp() async throws {
        let contentHash = "timestamp_\(UUID().uuidString)"
        let originalTimestamp = Date().addingTimeInterval(-3600) // 1 hour ago

        let item = ClipboardItem(
            id: UUID(),
            content: "Test",
            contentType: .text,
            contentHash: contentHash,
            timestamp: originalTimestamp,
            sourceApp: "TestApp"
        )
        try await storage.save(item)

        let viewModel = OverlayViewModel(storage: storage)
        viewModel.loadItemsFromStorage()

        try await Task.sleep(nanoseconds: 200_000_000)

        // Disable the actual paste simulation for testing
        viewModel.onBeforePaste = {}

        // Paste as plain text
        viewModel.pasteItem(item, asPlainText: true)

        // Wait for timestamp update
        try await Task.sleep(nanoseconds: 300_000_000)

        // Fetch the updated item
        let items = try await storage.fetchItems(limit: 10)
        let updatedItem = items.first { $0.contentHash == contentHash }

        XCTAssertNotNil(updatedItem, "Item should still exist")
        XCTAssertGreaterThan(updatedItem!.timestamp, originalTimestamp, "Timestamp should be updated")
    }
}

// MARK: - Test Helpers

/// Key handler that distinguishes between normal paste and paste as plain text
@MainActor
class PlainTextAwareKeyHandler {
    private let viewModel: OverlayViewModel

    var onPlainTextPaste: (() -> Void)?
    var onNormalPaste: (() -> Void)?

    init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags

        switch keyCode {
        case 36: // Return/Enter
            if modifiers.contains(.shift) {
                onPlainTextPaste?()
                viewModel.pasteSelected(asPlainText: true)
            } else {
                onNormalPaste?()
                viewModel.pasteSelected(asPlainText: false)
            }
            return true

        default:
            return false
        }
    }
}
