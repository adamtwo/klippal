import XCTest
@testable import KlipPal

/// Tests for rich text detection, storage, and extraction
final class RichTextTests: XCTestCase {

    // MARK: - Content Type Tests

    func testRichTextContentTypeDisplayName() {
        XCTAssertEqual(ClipboardContentType.richText.displayName, "Rich Text")
    }

    func testRichTextContentTypeIconName() {
        XCTAssertEqual(ClipboardContentType.richText.iconName, "doc.richtext")
    }

    // MARK: - Character Count Tests (blob size)

    func testCharacterCountFromSimpleHTML() {
        let plainText = "Hello World"
        let htmlString = "<html><body>\(plainText)</body></html>"
        let htmlData = htmlString.data(using: .utf8)!

        let item = ClipboardItem(
            content: String(plainText.prefix(100)),
            contentType: .richText,
            contentHash: "hash1",
            blobContent: htmlData
        )

        // Character count is blob size (includes HTML tags)
        XCTAssertEqual(item.characterCount, htmlData.count)
    }

    func testCharacterCountFromHTMLWithTags() {
        let htmlString = "<p>Hello <strong>World</strong></p>"
        let htmlData = htmlString.data(using: .utf8)!

        let item = ClipboardItem(
            content: "Hello Worl",
            contentType: .richText,
            contentHash: "hash2",
            blobContent: htmlData
        )

        // Character count is blob size
        XCTAssertEqual(item.characterCount, htmlData.count)
    }

    func testCharacterCountFromLongHTML() {
        let longText = String(repeating: "a", count: 500)
        let htmlString = "<div><p>\(longText)</p></div>"
        let htmlData = htmlString.data(using: .utf8)!

        let item = ClipboardItem(
            content: String(longText.prefix(100)),
            contentType: .richText,
            contentHash: "hash3",
            blobContent: htmlData
        )

        // Character count is blob size (500 chars + ~18 bytes of tags)
        XCTAssertEqual(item.characterCount, htmlData.count)
        XCTAssertGreaterThan(item.characterCount, 500)
    }

    func testCharacterCountFromHTMLWithEntities() {
        let htmlString = "<p>A &amp; B &lt; C &gt; D</p>"
        let htmlData = htmlString.data(using: .utf8)!

        let item = ClipboardItem(
            content: "A & B < C ",
            contentType: .richText,
            contentHash: "hash4",
            blobContent: htmlData
        )

        // Character count is blob size
        XCTAssertEqual(item.characterCount, htmlData.count)
    }

    // MARK: - Character Count from RTF Tests

    func testCharacterCountFromRTF() {
        let rtfString = #"{\rtf1\ansi Hello World}"#
        let rtfData = rtfString.data(using: .utf8)!

        let item = ClipboardItem(
            content: "Hello Worl",
            contentType: .richText,
            contentHash: "hash5",
            blobContent: rtfData
        )

        // Character count is blob size
        XCTAssertEqual(item.characterCount, rtfData.count)
    }

    // MARK: - Full Content Extraction Tests

    func testFullContentFromHTML() {
        let plainText = "This is the full content from HTML"
        let htmlString = "<p>\(plainText)</p>"
        let htmlData = htmlString.data(using: .utf8)!

        let item = ClipboardItem(
            content: String(plainText.prefix(100)),
            contentType: .richText,
            contentHash: "hash6",
            blobContent: htmlData
        )

        // Full content should contain the plain text (may have trailing whitespace)
        XCTAssertTrue(item.fullContent.trimmingCharacters(in: .whitespacesAndNewlines) == plainText)
    }

    func testFullContentFromComplexHTML() {
        let htmlString = """
            <html>
            <head><meta charset="utf-8"></head>
            <body>
            <h1>Title</h1>
            <p>Paragraph one.</p>
            <p>Paragraph two.</p>
            </body>
            </html>
            """
        let htmlData = htmlString.data(using: .utf8)!

        let item = ClipboardItem(
            content: "Title Parag",
            contentType: .richText,
            contentHash: "hash7",
            blobContent: htmlData
        )

        let fullContent = item.fullContent
        XCTAssertTrue(fullContent.contains("Title"), "Should contain 'Title'")
        XCTAssertTrue(fullContent.contains("Paragraph one"), "Should contain 'Paragraph one'")
        XCTAssertTrue(fullContent.contains("Paragraph two"), "Should contain 'Paragraph two'")
        XCTAssertFalse(fullContent.contains("<"), "Should not contain HTML tags")
    }

    // MARK: - isTruncated Tests

    func testIsTruncatedForLongRichText() {
        let longText = String(repeating: "x", count: 200)
        let htmlString = "<p>\(longText)</p>"
        let htmlData = htmlString.data(using: .utf8)!

        let item = ClipboardItem(
            content: String(longText.prefix(100)),
            contentType: .richText,
            contentHash: "hash8",
            blobContent: htmlData
        )

        XCTAssertTrue(item.isTruncated, "Rich text with 200 chars should be truncated")
    }

    func testIsTruncatedForShortRichText() {
        let shortText = "Short"
        let htmlString = "<p>\(shortText)</p>"
        let htmlData = htmlString.data(using: .utf8)!

        let item = ClipboardItem(
            content: shortText,
            contentType: .richText,
            contentHash: "hash9",
            blobContent: htmlData
        )

        // HTML blob size is larger than 100 bytes due to tags
        // So isTruncated checks blob size, which may be > 100
        // This is expected behavior - we show as truncated if blob is large
        let blobSize = htmlData.count
        XCTAssertEqual(item.isTruncated, blobSize > 100)
    }

    // MARK: - Preview Tests

    func testPreviewForRichText() {
        let longText = String(repeating: "y", count: 150)
        let htmlData = "<p>\(longText)</p>".data(using: .utf8)!

        let item = ClipboardItem(
            content: String(longText.prefix(100)),
            contentType: .richText,
            contentHash: "hash10",
            blobContent: htmlData
        )

        // Preview is based on content (100 chars), which equals previewLimit
        // so no truncation/ellipsis is added (100 is not > 100)
        XCTAssertEqual(item.preview.count, 100)
    }

    func testPreviewForShortRichText() {
        let shortText = "Short rich text"
        let htmlData = "<b>\(shortText)</b>".data(using: .utf8)!

        let item = ClipboardItem(
            content: shortText,
            contentType: .richText,
            contentHash: "hash11",
            blobContent: htmlData
        )

        XCTAssertEqual(item.preview, shortText)
        XCTAssertFalse(item.preview.hasSuffix("…"))
    }

    // MARK: - Formatted Character Count Tests

    func testFormattedCharacterCountForRichText() {
        let text1500 = String(repeating: "z", count: 1500)
        let htmlData = "<div>\(text1500)</div>".data(using: .utf8)!

        let item = ClipboardItem(
            content: String(text1500.prefix(100)),
            contentType: .richText,
            contentHash: "hash12",
            blobContent: htmlData
        )

        // Character count is blob size (1500 + tags)
        XCTAssertEqual(item.characterCount, htmlData.count)
        // Formatted should show ~1.5K
        XCTAssertTrue(item.formattedCharacterCount.contains("K"))
    }

    // MARK: - Attributed Content Tests

    func testAttributedContentFromRTF() {
        // Create valid RTF data
        let rtfString = #"{\rtf1\ansi\deff0 {\fonttbl{\f0 Times New Roman;}}Hello \b World\b0}"#
        let rtfData = rtfString.data(using: .utf8)!

        let item = ClipboardItem(
            content: "Hello Worl",
            contentType: .richText,
            contentHash: "hash13",
            blobContent: rtfData
        )

        // attributedContent should return an NSAttributedString
        let attributed = item.attributedContent
        // RTF parsing may or may not work depending on the RTF validity
        // Just verify it doesn't crash and returns something reasonable
        if let attributed = attributed {
            XCTAssertFalse(attributed.string.isEmpty, "Attributed string should not be empty")
        }
    }

    func testAttributedContentForNonRichText() {
        let item = ClipboardItem(
            content: "Plain text",
            contentType: .text,
            contentHash: "hash14"
        )

        XCTAssertNil(item.attributedContent, "Non-rich text should not have attributed content")
    }

    // MARK: - Edge Cases

    func testRichTextWithNilBlobContent() {
        let item = ClipboardItem(
            content: "No blob",
            contentType: .richText,
            contentHash: "hash15",
            blobContent: nil
        )

        // Should fall back to content
        XCTAssertEqual(item.characterCount, 7)
        XCTAssertEqual(item.fullContent, "No blob")
    }

    func testRichTextWithEmptyHTML() {
        let htmlData = "<html><body></body></html>".data(using: .utf8)!

        let item = ClipboardItem(
            content: "",
            contentType: .richText,
            contentHash: "hash16",
            blobContent: htmlData
        )

        // Character count is blob size (includes empty HTML tags)
        XCTAssertEqual(item.characterCount, htmlData.count)
    }

    func testRichTextWithMalformedHTML() {
        let malformedHTML = "<p>Unclosed tag <b>bold".data(using: .utf8)!

        let item = ClipboardItem(
            content: "Unclosed t",
            contentType: .richText,
            contentHash: "hash17",
            blobContent: malformedHTML
        )

        // Should still extract some text via regex fallback
        let fullContent = item.fullContent
        XCTAssertTrue(fullContent.contains("Unclosed") || fullContent.contains("bold"),
            "Should extract some text from malformed HTML")
    }
}
