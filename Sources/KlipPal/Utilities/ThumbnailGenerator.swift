import AppKit
import Foundation

/// Generates thumbnails from image data while maintaining aspect ratio
enum ThumbnailGenerator {
    /// Image format for thumbnail output
    enum ImageFormat {
        case png
        case jpeg
    }

    /// Generate a thumbnail image from raw image data
    /// - Parameters:
    ///   - data: Raw image data (TIFF, PNG, JPEG, etc.)
    ///   - maxSize: Maximum dimension (width or height) for the thumbnail
    /// - Returns: Resized NSImage or nil if data is invalid
    static func generateThumbnail(from data: Data, maxSize: CGFloat) -> NSImage? {
        guard !data.isEmpty else { return nil }
        guard let image = NSImage(data: data) else { return nil }

        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else { return nil }

        // Calculate scaled size maintaining aspect ratio
        let scaledSize = calculateScaledSize(originalSize: originalSize, maxSize: maxSize)

        // Create the thumbnail
        let thumbnail = NSImage(size: scaledSize)
        thumbnail.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        image.draw(
            in: NSRect(origin: .zero, size: scaledSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )

        thumbnail.unlockFocus()

        return thumbnail
    }

    /// Generate thumbnail data in specified format
    /// - Parameters:
    ///   - data: Raw image data
    ///   - maxSize: Maximum dimension for the thumbnail
    ///   - format: Output format (PNG or JPEG)
    /// - Returns: Encoded thumbnail data or nil if generation fails
    static func generateThumbnailData(from data: Data, maxSize: CGFloat, format: ImageFormat) -> Data? {
        guard let thumbnail = generateThumbnail(from: data, maxSize: maxSize) else {
            return nil
        }

        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        }
    }

    /// Get the dimensions of an image from its data
    /// - Parameter data: Raw image data
    /// - Returns: Size of the image or nil if data is invalid
    static func getImageDimensions(from data: Data) -> NSSize? {
        guard !data.isEmpty else { return nil }
        guard let image = NSImage(data: data) else { return nil }

        let size = image.size
        guard size.width > 0 && size.height > 0 else { return nil }

        return size
    }

    /// Calculate scaled size maintaining aspect ratio
    /// - Parameters:
    ///   - originalSize: Original image size
    ///   - maxSize: Maximum dimension (width or height)
    /// - Returns: Scaled size that fits within maxSize while maintaining aspect ratio
    private static func calculateScaledSize(originalSize: NSSize, maxSize: CGFloat) -> NSSize {
        let widthRatio = maxSize / originalSize.width
        let heightRatio = maxSize / originalSize.height

        // Use the smaller ratio to ensure the image fits within maxSize
        let ratio = min(widthRatio, heightRatio)

        // Don't scale up small images
        let finalRatio = min(ratio, 1.0)

        return NSSize(
            width: originalSize.width * finalRatio,
            height: originalSize.height * finalRatio
        )
    }
}
