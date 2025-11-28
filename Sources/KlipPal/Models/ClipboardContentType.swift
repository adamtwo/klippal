import Foundation

/// Represents the type of content stored in a clipboard item
enum ClipboardContentType: String, Codable, CaseIterable {
    case text      // Plain text
    case url       // Detected URL (http/https)
    case image     // PNG/JPEG/TIFF
    case fileURL   // File path (file://)

    /// User-friendly display name
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .url: return "URL"
        case .image: return "Image"
        case .fileURL: return "File"
        }
    }

    /// SF Symbol icon name for this content type
    var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .image: return "photo"
        case .fileURL: return "doc"
        }
    }
}
