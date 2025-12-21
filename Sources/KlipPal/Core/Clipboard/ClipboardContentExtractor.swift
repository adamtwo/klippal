import AppKit
import Foundation

/// Extracts and classifies content from NSPasteboard
struct ClipboardContentExtractor {
    /// Extract clipboard content and determine its type
    static func extract(from pasteboard: NSPasteboard) -> (content: String, type: ClipboardContentType, data: Data?)? {
        // Check for file URLs first (Finder file copies)
        // This must come before string check because Finder also provides string representation
        if let fileURLs = extractFileURLs(from: pasteboard), !fileURLs.isEmpty {
            let content = formatFileURLs(fileURLs)
            return (content, .fileURL, nil)
        }

        // Check for rich text (RTF or HTML) before plain text
        // Rich text apps typically provide both rich and plain versions
        if let richTextResult = extractRichText(from: pasteboard) {
            return richTextResult
        }

        // Check for image BEFORE string - images take priority
        // This fixes an issue where copying an image from history would
        // be detected as text if any string representation exists
        if let imageData = extractImageData(from: pasteboard) {
            let dimensions = ThumbnailGenerator.getImageDimensions(from: imageData)
            let dimensionStr = dimensions.map { "\(Int($0.width))×\(Int($0.height))" } ?? "unknown size"
            let content = "[Image \(dimensionStr) copied at \(Date().formatted())]"
            return (content, .image, imageData)
        }

        // Try to get string content
        if let string = pasteboard.string(forType: .string) {
            let type = determineType(for: string)
            return (string, type, nil)
        }

        return nil
    }

    /// Extract rich text (RTF or HTML) from pasteboard
    /// Returns plain text for display and rich text data for storage
    private static func extractRichText(from pasteboard: NSPasteboard) -> (content: String, type: ClipboardContentType, data: Data?)? {
        // Check for RTF first (more common for formatted text)
        if let rtfData = pasteboard.data(forType: .rtf) {
            // Get plain text version for display
            if let plainText = pasteboard.string(forType: .string), !plainText.isEmpty {
                // Only treat as rich text if there's actual formatting
                // Check if RTF has meaningful formatting beyond plain text
                if hasRichFormatting(rtfData: rtfData, plainText: plainText) {
                    return (plainText, .richText, rtfData)
                }
            }
        }

        // Check for HTML
        if let htmlData = pasteboard.data(forType: .html) {
            if let plainText = pasteboard.string(forType: .string), !plainText.isEmpty {
                return (plainText, .richText, htmlData)
            }
        }

        return nil
    }

    /// Check if RTF data contains meaningful formatting beyond plain text
    private static func hasRichFormatting(rtfData: Data, plainText: String) -> Bool {
        // Simple heuristic: RTF with formatting is typically larger than plain text
        // Plain text wrapped in minimal RTF is roughly 100-200 bytes overhead
        // If RTF is significantly larger, it likely has formatting
        let overhead = rtfData.count - plainText.utf8.count

        // Also check for common RTF formatting markers
        if let rtfString = String(data: rtfData, encoding: .ascii) {
            // Check for bold, italic, underline, color, font changes
            let formattingMarkers = ["\\b ", "\\i ", "\\ul", "\\cf", "\\f1", "\\fs", "\\highlight"]
            for marker in formattingMarkers {
                if rtfString.contains(marker) {
                    return true
                }
            }
        }

        // If overhead is large (>500 bytes), assume there's formatting
        return overhead > 500
    }

    /// Extract file URLs from pasteboard (handles Finder file copies)
    private static func extractFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        // Method 1: Read NSURL objects directly (preferred for Finder)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            // Filter to only file:// URLs
            let fileURLs = urls.filter { $0.isFileURL }
            if !fileURLs.isEmpty {
                return fileURLs
            }
        }

        // Method 2: Try the fileURL pasteboard type
        if let urlString = pasteboard.string(forType: .fileURL),
           let url = URL(string: urlString),
           url.isFileURL {
            return [url]
        }

        return nil
    }

    /// Format file URLs for storage
    private static func formatFileURLs(_ urls: [URL]) -> String {
        if urls.count == 1 {
            return urls[0].absoluteString
        } else {
            // For multiple files, store them newline-separated
            // The first line indicates it's multiple files
            let filenames = urls.map { FileMetadataExtractor.extractFilename(from: $0.path) }
            return "[\(urls.count) files: \(filenames.joined(separator: ", "))]"
        }
    }

    /// Extract image data from pasteboard, trying multiple formats
    /// Always returns PNG data for consistency and smaller file sizes
    private static func extractImageData(from pasteboard: NSPasteboard) -> Data? {
        // Try PNG first (lossless, preferred)
        if let pngData = pasteboard.data(forType: .png) {
            return pngData
        }

        // Try TIFF (common on macOS) - convert to PNG for smaller size
        if let tiffData = pasteboard.data(forType: .tiff) {
            return convertToPNG(tiffData)
        }

        // Try to get NSImage and convert to PNG
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let tiffData = image.tiffRepresentation {
            return convertToPNG(tiffData)
        }

        return nil
    }

    /// Convert image data (TIFF or other) to PNG for consistent hashing and smaller storage
    private static func convertToPNG(_ imageData: Data) -> Data? {
        guard let imageRep = NSBitmapImageRep(data: imageData) else {
            return imageData // Return original if can't convert
        }
        return imageRep.representation(using: .png, properties: [:]) ?? imageData
    }

    /// Determine content type from string
    private static func determineType(for string: String) -> ClipboardContentType {
        // Check if it's a URL
        if let url = URL(string: string),
           let scheme = url.scheme,
           (scheme == "http" || scheme == "https") {
            return .url
        }

        // Check if it's a file URL
        if string.hasPrefix("file://") {
            return .fileURL
        }

        // Default to text
        return .text
    }

    /// Get the frontmost application name
    static func getFrontmostApp() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
