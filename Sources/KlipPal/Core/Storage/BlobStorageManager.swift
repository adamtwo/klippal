import Foundation
import AppKit

/// Result of saving an image with its thumbnail
struct ImageSaveResult {
    let fullPath: String
    let thumbnailPath: String
}

/// Manages storage of large binary data (images) on disk
actor BlobStorageManager {
    private let blobDirectory: URL

    /// Maximum image size to store (10MB)
    private let maxImageSize: Int = 10 * 1024 * 1024

    /// Default thumbnail size
    private let defaultThumbnailSize: CGFloat = 80

    init(blobDirectory: URL) throws {
        self.blobDirectory = blobDirectory

        // Create blob directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: blobDirectory,
            withIntermediateDirectories: true
        )

        // Create thumbnails subdirectory
        let thumbDir = blobDirectory.appendingPathComponent("thumbnails")
        try FileManager.default.createDirectory(
            at: thumbDir,
            withIntermediateDirectories: true
        )
    }

    /// Save image data to blob storage
    /// Returns the relative path to the saved blob
    func save(imageData: Data, hash: String) async throws -> String {
        // Check size limit
        guard imageData.count <= maxImageSize else {
            throw BlobStorageError.imageTooLarge(size: imageData.count, max: maxImageSize)
        }

        // Create filename from hash
        let filename = "\(hash).png"
        let fileURL = blobDirectory.appendingPathComponent(filename)

        // Convert to PNG and save
        guard let image = NSImage(data: imageData),
              let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw BlobStorageError.imageConversionFailed
        }

        try pngData.write(to: fileURL)

        return filename
    }

    /// Save image data with a thumbnail
    /// Returns paths to both the full image and thumbnail
    func saveWithThumbnail(imageData: Data, hash: String, thumbnailSize: CGFloat? = nil) async throws -> ImageSaveResult {
        // Check size limit
        guard imageData.count <= maxImageSize else {
            throw BlobStorageError.imageTooLarge(size: imageData.count, max: maxImageSize)
        }

        let size = thumbnailSize ?? defaultThumbnailSize

        // Save full image
        let fullPath = try await save(imageData: imageData, hash: hash)

        // Generate and save thumbnail
        let thumbnailFilename = "thumbnails/\(hash)_thumb.png"
        let thumbnailURL = blobDirectory.appendingPathComponent(thumbnailFilename)

        if let thumbnailData = ThumbnailGenerator.generateThumbnailData(
            from: imageData,
            maxSize: size,
            format: .png
        ) {
            try thumbnailData.write(to: thumbnailURL)
        } else {
            throw BlobStorageError.thumbnailGenerationFailed
        }

        return ImageSaveResult(fullPath: fullPath, thumbnailPath: thumbnailFilename)
    }

    /// Load thumbnail for an image
    func loadThumbnail(hash: String) async throws -> Data {
        let thumbnailPath = "thumbnails/\(hash)_thumb.png"
        return try await load(relativePath: thumbnailPath)
    }

    /// Load image data from blob storage
    func load(relativePath: String) async throws -> Data {
        let fileURL = blobDirectory.appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw BlobStorageError.blobNotFound(path: relativePath)
        }

        return try Data(contentsOf: fileURL)
    }

    /// Delete a blob file
    func delete(relativePath: String) async throws {
        let fileURL = blobDirectory.appendingPathComponent(relativePath)
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Delete all blob files
    func deleteAll() async throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: blobDirectory,
            includingPropertiesForKeys: nil
        )

        for fileURL in contents {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Get total size of all blobs in bytes
    func getTotalSize() async throws -> Int {
        let contents = try FileManager.default.contentsOfDirectory(
            at: blobDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )

        var totalSize = 0
        for fileURL in contents {
            let resources = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += resources.fileSize ?? 0
        }

        return totalSize
    }
}

// MARK: - Blob Storage Errors

enum BlobStorageError: Error, LocalizedError {
    case imageTooLarge(size: Int, max: Int)
    case imageConversionFailed
    case thumbnailGenerationFailed
    case blobNotFound(path: String)

    var errorDescription: String? {
        switch self {
        case .imageTooLarge(let size, let max):
            return "Image too large: \(size) bytes (max: \(max) bytes)"
        case .imageConversionFailed:
            return "Failed to convert image to PNG"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        case .blobNotFound(let path):
            return "Blob not found: \(path)"
        }
    }
}
