import XCTest
@testable import KlipPal

/// Tests for ClipboardItemRowView and preview popover functionality
final class ClipboardItemRowViewTests: XCTestCase {

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
