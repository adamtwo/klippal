import XCTest
import SwiftUI
@testable import KlipPal

/// Tests for ClipboardItemRowView and preview popover functionality
final class ClipboardItemRowViewTests: XCTestCase {

    // MARK: - Popover Positioning Tests

    func testPopoverAppearsOnLeftSideOfMainWindow() {
        // The popover arrow edge should be .leading, which positions
        // the popover content to the left of the trigger element
        // (and thus to the left of the main window)
        XCTAssertEqual(ClipboardItemRowView.popoverArrowEdge, .leading,
            "Popover should appear on the left side of the main window")
    }

    // MARK: - shouldShowPreviewPopover Logic Tests

    func testShouldShowPreviewPopoverForImages() {
        // Images should always show preview popover (full-size preview)
        let imageItem = ClipboardItem(
            content: "100×100 PNG",
            contentType: .image,
            contentHash: "hash1"
        )

        XCTAssertTrue(shouldShowPreviewPopover(for: imageItem),
            "Images should show preview popover")
    }

    func testShouldShowPreviewPopoverForURLs() {
        // URLs should always show preview popover (website preview)
        let urlItem = ClipboardItem(
            content: "https://example.com/page",
            contentType: .url,
            contentHash: "hash2"
        )

        XCTAssertTrue(shouldShowPreviewPopover(for: urlItem),
            "URLs should show preview popover")
    }

    func testShouldShowPreviewPopoverForTruncatedText() {
        // Truncated text should show preview popover
        let longText = String(repeating: "a", count: 300) // Longer than preview limit
        let textItem = ClipboardItem(
            content: longText,
            contentType: .text,
            contentHash: "hash3"
        )

        XCTAssertTrue(textItem.isTruncated, "Long text should be truncated")
        XCTAssertTrue(shouldShowPreviewPopover(for: textItem),
            "Truncated text should show preview popover")
    }

    func testShouldNotShowPreviewPopoverForShortText() {
        // Short text that fits in preview should not show popover
        let shortText = "Short text"
        let textItem = ClipboardItem(
            content: shortText,
            contentType: .text,
            contentHash: "hash4"
        )

        XCTAssertFalse(textItem.isTruncated, "Short text should not be truncated")
        XCTAssertFalse(shouldShowPreviewPopover(for: textItem),
            "Non-truncated text should not show preview popover")
    }

    func testShouldShowPreviewPopoverForFileURLs() {
        // File URLs are treated like regular files, not URLs
        let fileItem = ClipboardItem(
            content: "/path/to/file.txt",
            contentType: .fileURL,
            contentHash: "hash5"
        )

        // File URLs don't show preview unless truncated
        XCTAssertFalse(fileItem.isTruncated, "Short file path should not be truncated")
        XCTAssertFalse(shouldShowPreviewPopover(for: fileItem),
            "Non-truncated file URLs should not show preview popover")
    }

    // MARK: - TextPreviewPopover Tests

    func testTextPreviewPopoverShowsFullTextForShortContent() {
        let shortContent = "This is a short piece of text."

        // Text preview should show full content when under 1000 chars
        XCTAssertEqual(shortContent.count, 30)
        XCTAssertLessThan(shortContent.count, 1000,
            "Short content should be under the preview limit")
    }

    func testTextPreviewPopoverTruncatesVeryLongContent() {
        let veryLongContent = String(repeating: "x", count: 2000)
        let maxPreviewChars = 1000

        // Preview should truncate to 1000 chars
        let previewText: String
        if veryLongContent.count > maxPreviewChars {
            previewText = String(veryLongContent.prefix(maxPreviewChars)) + "..."
        } else {
            previewText = veryLongContent
        }

        XCTAssertEqual(previewText.count, 1003, // 1000 + "..."
            "Preview should truncate to 1000 chars plus ellipsis")
    }

    // MARK: - Character Count Display Tests (based on blob size)

    func testRowWithMoreThan100CharsDisplaysCharacterCount() {
        // Create item with 150 chars in blob, but only 100 in content column
        let fullText = String(repeating: "a", count: 150)
        let truncatedContent = String(fullText.prefix(100))
        let blobData = fullText.data(using: .utf8)!

        let item = ClipboardItem(
            content: truncatedContent,
            contentType: .text,
            contentHash: "hash_long",
            blobContent: blobData
        )

        // isTruncated should be based on blob size (150) vs preview limit (100)
        XCTAssertTrue(item.isTruncated, "Item with 150 chars in blob should be truncated")
        XCTAssertEqual(item.characterCount, 150, "Character count should be based on blob size")
        XCTAssertEqual(item.formattedCharacterCount, "150 chars")
    }

    func testRowWithExactly100CharsDoesNotDisplayCharacterCount() {
        let exactText = String(repeating: "b", count: 100)
        let blobData = exactText.data(using: .utf8)!

        let item = ClipboardItem(
            content: exactText,
            contentType: .text,
            contentHash: "hash_exact",
            blobContent: blobData
        )

        // 100 chars is not greater than 100, so not truncated
        XCTAssertFalse(item.isTruncated, "Item with exactly 100 chars should not be truncated")
    }

    func testRowWith101CharsDisplaysCharacterCount() {
        let text101 = String(repeating: "c", count: 101)
        let truncatedContent = String(text101.prefix(100))
        let blobData = text101.data(using: .utf8)!

        let item = ClipboardItem(
            content: truncatedContent,
            contentType: .text,
            contentHash: "hash_101",
            blobContent: blobData
        )

        XCTAssertTrue(item.isTruncated, "Item with 101 chars in blob should be truncated")
        XCTAssertEqual(item.characterCount, 101)
    }

    func testCharacterCountUsesKFormatForLargeNumbers() {
        let largeText = String(repeating: "d", count: 1500)
        let blobData = largeText.data(using: .utf8)!

        let item = ClipboardItem(
            content: String(largeText.prefix(100)),
            contentType: .text,
            contentHash: "hash_large",
            blobContent: blobData
        )

        XCTAssertEqual(item.characterCount, 1500)
        XCTAssertEqual(item.formattedCharacterCount, "1.5K chars")
    }

    // MARK: - Popover Full Content Tests (from blob)

    func testPopoverShowsFullContentFromBlob() {
        let fullText = "This is the full content that should appear in the popover preview"
        let truncatedContent = String(fullText.prefix(30))
        let blobData = fullText.data(using: .utf8)!

        let item = ClipboardItem(
            content: truncatedContent,
            contentType: .text,
            contentHash: "hash_popover",
            blobContent: blobData
        )

        // fullContent should return the complete text from blob
        XCTAssertEqual(item.fullContent, fullText)
        XCTAssertNotEqual(item.fullContent, item.content, "fullContent should differ from truncated content")
    }

    func testPopoverContentTruncatesAt1000CharsFor2000CharBlob() {
        let veryLongText = String(repeating: "e", count: 2000)
        let blobData = veryLongText.data(using: .utf8)!
        let maxPreviewChars = 1000

        let item = ClipboardItem(
            content: String(veryLongText.prefix(100)),
            contentType: .text,
            contentHash: "hash_2000",
            blobContent: blobData
        )

        // fullContent returns the full 2000 chars
        XCTAssertEqual(item.fullContent.count, 2000)

        // TextPreviewPopover should truncate to 1000 chars
        let previewText: String
        if item.fullContent.count > maxPreviewChars {
            previewText = String(item.fullContent.prefix(maxPreviewChars)) + "..."
        } else {
            previewText = item.fullContent
        }

        XCTAssertEqual(previewText.count, 1003, "Popover should show 1000 chars + '...'")
        XCTAssertTrue(previewText.hasSuffix("..."), "Truncated preview should end with ellipsis")
    }

    func testPopoverContentShowsFullTextUnder1000Chars() {
        let mediumText = String(repeating: "f", count: 500)
        let blobData = mediumText.data(using: .utf8)!
        let maxPreviewChars = 1000

        let item = ClipboardItem(
            content: String(mediumText.prefix(100)),
            contentType: .text,
            contentHash: "hash_500",
            blobContent: blobData
        )

        // Simulate TextPreviewPopover logic
        let previewText: String
        if item.fullContent.count > maxPreviewChars {
            previewText = String(item.fullContent.prefix(maxPreviewChars)) + "..."
        } else {
            previewText = item.fullContent
        }

        XCTAssertEqual(previewText.count, 500, "Popover should show full 500 chars without truncation")
        XCTAssertFalse(previewText.hasSuffix("..."), "Non-truncated preview should not have ellipsis")
    }

    func testPopoverContentExactly1000CharsNotTruncated() {
        let exact1000 = String(repeating: "g", count: 1000)
        let blobData = exact1000.data(using: .utf8)!
        let maxPreviewChars = 1000

        let item = ClipboardItem(
            content: String(exact1000.prefix(100)),
            contentType: .text,
            contentHash: "hash_1000",
            blobContent: blobData
        )

        // Simulate TextPreviewPopover logic
        let previewText: String
        if item.fullContent.count > maxPreviewChars {
            previewText = String(item.fullContent.prefix(maxPreviewChars)) + "..."
        } else {
            previewText = item.fullContent
        }

        XCTAssertEqual(previewText.count, 1000, "Exactly 1000 chars should not be truncated")
        XCTAssertFalse(previewText.hasSuffix("..."))
    }

    func testPopoverContent1001CharsTruncated() {
        let text1001 = String(repeating: "h", count: 1001)
        let blobData = text1001.data(using: .utf8)!
        let maxPreviewChars = 1000

        let item = ClipboardItem(
            content: String(text1001.prefix(100)),
            contentType: .text,
            contentHash: "hash_1001",
            blobContent: blobData
        )

        // Simulate TextPreviewPopover logic
        let previewText: String
        if item.fullContent.count > maxPreviewChars {
            previewText = String(item.fullContent.prefix(maxPreviewChars)) + "..."
        } else {
            previewText = item.fullContent
        }

        XCTAssertEqual(previewText.count, 1003, "1001 chars should be truncated to 1000 + '...'")
        XCTAssertTrue(previewText.hasSuffix("..."))
    }

    // MARK: - URLPreviewData Tests

    func testURLPreviewDataInitialization() {
        let previewData = URLPreviewData(
            title: "Example Page",
            description: "This is an example page description",
            siteName: "Example.com",
            imageURL: URL(string: "https://example.com/image.png"),
            image: nil
        )

        XCTAssertEqual(previewData.title, "Example Page")
        XCTAssertEqual(previewData.description, "This is an example page description")
        XCTAssertEqual(previewData.siteName, "Example.com")
        XCTAssertNotNil(previewData.imageURL)
        XCTAssertNil(previewData.image)
    }

    func testURLPreviewDataWithNilValues() {
        let previewData = URLPreviewData(
            title: nil,
            description: nil,
            siteName: nil,
            imageURL: nil,
            image: nil
        )

        XCTAssertNil(previewData.title)
        XCTAssertNil(previewData.description)
        XCTAssertNil(previewData.siteName)
        XCTAssertNil(previewData.imageURL)
        XCTAssertNil(previewData.image)
    }

    // MARK: - Image Preview Scaling Tests

    func testImagePreviewScalingMaintainsAspectRatio() {
        let maxPreviewSize: CGFloat = 480

        // Test landscape image
        let landscapeSize = NSSize(width: 1920, height: 1080)
        let landscapeScaled = scaledSize(for: landscapeSize, maxSize: maxPreviewSize)

        XCTAssertLessThanOrEqual(landscapeScaled.width, maxPreviewSize)
        XCTAssertLessThanOrEqual(landscapeScaled.height, maxPreviewSize)

        // Check aspect ratio is maintained
        let originalRatio = landscapeSize.width / landscapeSize.height
        let scaledRatio = landscapeScaled.width / landscapeScaled.height
        XCTAssertEqual(originalRatio, scaledRatio, accuracy: 0.01,
            "Aspect ratio should be maintained")
    }

    func testImagePreviewDoesNotUpscale() {
        let maxPreviewSize: CGFloat = 480

        // Test small image
        let smallSize = NSSize(width: 100, height: 100)
        let scaled = scaledSize(for: smallSize, maxSize: maxPreviewSize)

        XCTAssertEqual(scaled.width, 100, "Small images should not be upscaled")
        XCTAssertEqual(scaled.height, 100, "Small images should not be upscaled")
    }

    func testImagePreviewScalesDownLargeImages() {
        let maxPreviewSize: CGFloat = 480

        // Test large square image
        let largeSize = NSSize(width: 1000, height: 1000)
        let scaled = scaledSize(for: largeSize, maxSize: maxPreviewSize)

        XCTAssertEqual(scaled.width, maxPreviewSize)
        XCTAssertEqual(scaled.height, maxPreviewSize)
    }

    // MARK: - Helper Methods

    /// Replicates the shouldShowPreviewPopover logic from ClipboardItemRowView
    private func shouldShowPreviewPopover(for item: ClipboardItem) -> Bool {
        item.contentType == .image || item.contentType == .url || item.isTruncated
    }

    /// Replicates the image scaling logic from ImagePreviewPopover
    private func scaledSize(for originalSize: NSSize, maxSize: CGFloat) -> CGSize {
        let widthRatio = maxSize / originalSize.width
        let heightRatio = maxSize / originalSize.height
        let scale = min(widthRatio, heightRatio, 1.0) // Don't upscale

        return CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
    }
}
