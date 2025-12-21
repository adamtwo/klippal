import AppKit
import Carbon
import ApplicationServices

/// Handles pasting clipboard items to the active application
@MainActor
class PasteManager {
    private let storage: SQLiteStorageEngine?

    init(storage: SQLiteStorageEngine? = nil) {
        self.storage = storage
    }

    /// Paste an item by restoring it to clipboard and simulating Cmd+V
    /// - Parameters:
    ///   - item: The clipboard item to paste
    ///   - asPlainText: If true, paste only the plain text content regardless of content type
    func paste(_ item: ClipboardItem, asPlainText: Bool = false) async throws {
        print("📋 Restoring item to clipboard\(asPlainText ? " as plain text" : "")...")

        // Check accessibility permissions
        let trusted = AXIsProcessTrusted()
        print("📋 Accessibility trusted: \(trusted)")

        if !trusted {
            print("⚠️ Accessibility permissions not granted! Paste will not work.")
            print("⚠️ Please grant permissions in System Settings > Privacy & Security > Accessibility")
        }

        // Restore to clipboard
        try await restoreToClipboard(item, asPlainText: asPlainText)

        print("📋 Clipboard updated, waiting 500ms before simulating Cmd+V...")

        // Even longer delay to ensure app has focus
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Simulate Cmd+V
        simulateCmdV()
    }

    /// Restore an item to the system clipboard without simulating paste
    /// - Parameters:
    ///   - item: The clipboard item to restore
    ///   - asPlainText: If true, restore only the plain text content regardless of content type
    func restoreToClipboard(_ item: ClipboardItem, asPlainText: Bool = false) async throws {
        // Fetch blob content if not already loaded
        var blobContent = item.blobContent
        if blobContent == nil, let storage = storage ?? AppDelegate.shared.storage {
            blobContent = try await storage.fetchBlobContent(byHash: item.contentHash)
        }

        // Tell clipboard monitor to skip this change (we're pasting, not copying)
        AppDelegate.shared?.skipNextClipboardChange()

        // Restore item to system clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // If pasting as plain text, always use plain text regardless of content type
        if asPlainText {
            let plainText = getPlainTextContent(from: item, blobContent: blobContent)
            pasteboard.setString(plainText, forType: .string)
            print("📋 Restored as plain text: \(plainText.prefix(50))...")
            return
        }

        switch item.contentType {
        case .image:
            // Load image from blob content and restore to clipboard
            if let blobContent = blobContent {
                if let image = NSImage(data: blobContent) {
                    pasteboard.writeObjects([image])
                    print("📋 Restored image to clipboard from blob content")
                } else {
                    print("⚠️ Failed to create NSImage from blob data, falling back to text")
                    pasteboard.setString(item.content, forType: .string)
                }
            } else {
                print("⚠️ No blob content available, falling back to text")
                pasteboard.setString(item.content, forType: .string)
            }

        case .fileURL:
            // Restore file URL to clipboard for proper file pasting
            if let url = URL(string: item.content), url.isFileURL {
                pasteboard.writeObjects([url as NSURL])
                print("📋 Restored file URL to clipboard: \(url.path)")
            } else {
                // Fallback: treat as text
                pasteboard.setString(item.content, forType: .string)
                print("⚠️ Invalid file URL, falling back to text")
            }

        case .richText:
            // Restore rich text with formatting
            if let blobContent = blobContent {
                // Try to determine format and restore appropriately
                if let attributed = NSAttributedString(rtf: blobContent, documentAttributes: nil) {
                    // Write RTF data and plain text fallback
                    pasteboard.setData(blobContent, forType: .rtf)
                    pasteboard.setString(attributed.string, forType: .string)
                    print("📋 Restored RTF to clipboard with formatting")
                } else if let attributed = NSAttributedString(html: blobContent, documentAttributes: nil) {
                    // Write HTML data and plain text fallback
                    pasteboard.setData(blobContent, forType: .html)
                    pasteboard.setString(attributed.string, forType: .string)
                    print("📋 Restored HTML to clipboard with formatting")
                } else {
                    // Fallback to plain text from content
                    pasteboard.setString(item.content, forType: .string)
                    print("⚠️ Could not parse rich text, falling back to plain text")
                }
            } else {
                pasteboard.setString(item.content, forType: .string)
            }

        case .text, .url:
            // Restore full text from blob if available
            if let blobContent = blobContent,
               let fullText = String(data: blobContent, encoding: .utf8) {
                pasteboard.setString(fullText, forType: .string)
            } else {
                pasteboard.setString(item.content, forType: .string)
            }
        }
    }

    /// Extract plain text content from a clipboard item
    private func getPlainTextContent(from item: ClipboardItem, blobContent: Data?) -> String {
        switch item.contentType {
        case .richText:
            // Try to extract plain text from rich text blob
            if let blobContent = blobContent {
                if let attributed = NSAttributedString(rtf: blobContent, documentAttributes: nil) {
                    return attributed.string
                } else if let attributed = NSAttributedString(html: blobContent, documentAttributes: nil) {
                    return attributed.string
                }
            }
            return item.content

        case .text, .url:
            // For text/URL, prefer full content from blob if available
            if let blobContent = blobContent,
               let fullText = String(data: blobContent, encoding: .utf8) {
                return fullText
            }
            return item.content

        case .image, .fileURL:
            // For images and files, return the content description/path
            return item.content
        }
    }

    /// Simulate Cmd+V keypress using CGEvent
    private func simulateCmdV() {
        print("📋 Creating CGEvent for Cmd+V...")

        // Key code for 'V' is 9
        let keyCode: CGKeyCode = 9

        // Create key down event with Cmd modifier
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            print("❌ Failed to create key down event")
            return
        }

        keyDownEvent.flags = .maskCommand

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("❌ Failed to create key up event")
            return
        }

        keyUpEvent.flags = .maskCommand

        // Post events
        print("📋 Posting key down event...")
        keyDownEvent.post(tap: .cghidEventTap)

        print("📋 Posting key up event...")
        keyUpEvent.post(tap: .cghidEventTap)

        print("✅ Simulated Cmd+V")
    }
}
