import Foundation

/// Represents a single clipboard history item
struct ClipboardItem: Identifiable, Codable, Equatable {
    /// Unique identifier
    let id: UUID

    /// Text content or file path
    let content: String

    /// Type of content
    let contentType: ClipboardContentType

    /// SHA256 hash for deduplication
    let contentHash: String

    /// When this item was copied
    let timestamp: Date

    /// Application that was active when copied (optional)
    let sourceApp: String?

    /// Path to blob storage for images (optional)
    var blobPath: String?

    /// Whether this item is pinned/favorited
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        content: String,
        contentType: ClipboardContentType,
        contentHash: String,
        timestamp: Date = Date(),
        sourceApp: String? = nil,
        blobPath: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.content = content
        self.contentType = contentType
        self.contentHash = contentHash
        self.timestamp = timestamp
        self.sourceApp = sourceApp
        self.blobPath = blobPath
        self.isFavorite = isFavorite
    }

    /// Maximum characters shown in preview
    private static let previewLimit = 100

    /// Preview text (truncated for display)
    var preview: String {
        switch contentType {
        case .text:
            let cleaned = content.replacingOccurrences(of: "\n", with: " ")
            let truncated = String(cleaned.prefix(Self.previewLimit))
            return cleaned.count > Self.previewLimit ? truncated + "…" : truncated
        case .url:
            // For URLs, show the full URL but truncated if too long
            let truncated = String(content.prefix(Self.previewLimit))
            return content.count > Self.previewLimit ? truncated + "…" : truncated
        case .image:
            return "[Image]"
        case .fileURL:
            // Use displayFilename which decodes percent encoding
            return displayFilename ?? (content as NSString).lastPathComponent
        }
    }

    /// Whether the content is truncated in the preview
    var isTruncated: Bool {
        switch contentType {
        case .text, .url:
            return content.count > Self.previewLimit
        case .image, .fileURL:
            return false
        }
    }

    /// Character count of the full content
    var characterCount: Int {
        content.count
    }

    /// Formatted character count string (e.g., "1.2K chars" or "150 chars")
    var formattedCharacterCount: String {
        let count = characterCount
        if count >= 1000 {
            let kCount = Double(count) / 1000.0
            return String(format: "%.1fK chars", kCount)
        } else {
            return "\(count) chars"
        }
    }

    /// For URL items, extract and return the domain
    var displayDomain: String? {
        guard contentType == .url else { return nil }
        return URLMetadataExtractor.extractDomain(from: content)
    }

    /// For URL items, extract and return the path
    var displayPath: String? {
        guard contentType == .url else { return nil }
        return URLMetadataExtractor.extractPath(from: content)
    }

    /// For URL items, get a derived title
    var displayTitle: String? {
        guard contentType == .url else { return nil }
        return URLMetadataExtractor.extractTitle(from: content)
    }

    /// Check if this is a code repository URL
    var isCodeRepository: Bool {
        guard contentType == .url, let url = URL(string: content) else { return false }
        return URLMetadataExtractor.isCodeRepository(url)
    }

    /// Check if this is a documentation URL
    var isDocumentation: Bool {
        guard contentType == .url, let url = URL(string: content) else { return false }
        return URLMetadataExtractor.isDocumentation(url)
    }

    // MARK: - File Display Properties

    /// For file items, extract and return the filename
    var displayFilename: String? {
        guard contentType == .fileURL else { return nil }
        return FileMetadataExtractor.extractFilename(from: content)
    }

    /// For file items, extract and return the file extension
    var displayExtension: String? {
        guard contentType == .fileURL else { return nil }
        return FileMetadataExtractor.extractExtension(from: content)
    }

    /// For file items, extract and return the parent folder name
    var displayParentFolder: String? {
        guard contentType == .fileURL else { return nil }
        return FileMetadataExtractor.extractParentFolder(from: content)
    }

    /// For file items, check if it's a directory
    var isDirectory: Bool {
        guard contentType == .fileURL else { return false }
        return FileMetadataExtractor.isDirectory(path: content)
    }

    /// For file items, get the appropriate icon name
    var fileIconName: String? {
        guard contentType == .fileURL else { return nil }
        let ext = FileMetadataExtractor.extractExtension(from: content)
        let isDir = FileMetadataExtractor.isDirectory(path: content)
        return FileMetadataExtractor.getIconName(forExtension: ext, isDirectory: isDir)
    }

    /// For file items, get the appropriate icon color
    var fileIconColor: String? {
        guard contentType == .fileURL else { return nil }
        let ext = FileMetadataExtractor.extractExtension(from: content)
        let isDir = FileMetadataExtractor.isDirectory(path: content)
        return FileMetadataExtractor.getIconColor(forExtension: ext, isDirectory: isDir)
    }
}
