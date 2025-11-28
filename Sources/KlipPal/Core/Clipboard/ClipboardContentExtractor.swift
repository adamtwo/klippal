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

        // Try to get string content
        if let string = pasteboard.string(forType: .string) {
            let type = determineType(for: string)
            return (string, type, nil)
        }

        // Try to get image data (check multiple formats)
        if let imageData = extractImageData(from: pasteboard) {
            let dimensions = ThumbnailGenerator.getImageDimensions(from: imageData)
            let dimensionStr = dimensions.map { "\(Int($0.width))×\(Int($0.height))" } ?? "unknown size"
            let content = "[Image \(dimensionStr) copied at \(Date().formatted())]"
            return (content, .image, imageData)
        }

        return nil
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
    private static func extractImageData(from pasteboard: NSPasteboard) -> Data? {
        // Try PNG first (lossless, preferred)
        if let pngData = pasteboard.data(forType: .png) {
            return pngData
        }

        // Try TIFF (common on macOS)
        if let tiffData = pasteboard.data(forType: .tiff) {
            return tiffData
        }

        // Try to get NSImage and convert (handles many formats including JPEG)
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let tiffData = image.tiffRepresentation {
            return tiffData
        }

        return nil
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
