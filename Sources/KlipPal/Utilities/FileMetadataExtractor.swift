import Foundation
import AppKit

/// Extracts metadata from file paths for display purposes
enum FileMetadataExtractor {

    /// Extract the filename from a path
    /// - Parameter path: File path (can be file:// URL or plain path)
    /// - Returns: The filename including extension (URL decoded for human readability)
    static func extractFilename(from path: String) -> String {
        let cleanPath = path.replacingOccurrences(of: "file://", with: "")
            .removingPercentEncoding ?? path.replacingOccurrences(of: "file://", with: "")
        return (cleanPath as NSString).lastPathComponent
    }

    /// Extract the file extension (lowercase)
    /// - Parameter path: File path
    /// - Returns: The file extension without dot, or nil if none
    static func extractExtension(from path: String) -> String? {
        let filename = extractFilename(from: path)
        let ext = (filename as NSString).pathExtension
        return ext.isEmpty ? nil : ext.lowercased()
    }

    /// Extract the parent folder name
    /// - Parameter path: File path
    /// - Returns: The parent folder name (URL decoded for human readability)
    static func extractParentFolder(from path: String) -> String {
        let cleanPath = path.replacingOccurrences(of: "file://", with: "")
            .removingPercentEncoding ?? path.replacingOccurrences(of: "file://", with: "")
        let parent = (cleanPath as NSString).deletingLastPathComponent
        return (parent as NSString).lastPathComponent
    }

    /// Check if a path is a directory
    /// - Parameter path: File path
    /// - Returns: True if the path is a directory
    static func isDirectory(path: String) -> Bool {
        let cleanPath = path.replacingOccurrences(of: "file://", with: "")
            .removingPercentEncoding ?? path
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: cleanPath, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    /// Get the file size in bytes
    /// - Parameter path: File path
    /// - Returns: File size in bytes, or nil if not available
    static func getFileSize(path: String) -> Int64? {
        let cleanPath = path.replacingOccurrences(of: "file://", with: "")
            .removingPercentEncoding ?? path

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: cleanPath),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return size
    }

    /// Format file size for display
    /// - Parameter bytes: Size in bytes
    /// - Returns: Human-readable size string
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    /// Get the appropriate SF Symbol icon name for a file extension
    /// - Parameters:
    ///   - extension: File extension (without dot)
    ///   - isDirectory: Whether this is a directory
    /// - Returns: SF Symbol name
    static func getIconName(forExtension ext: String?, isDirectory: Bool = false) -> String {
        if isDirectory {
            return "folder.fill"
        }

        guard let ext = ext?.lowercased() else {
            return "doc.fill"
        }

        // Document types
        let documents = ["pdf", "doc", "docx", "rtf", "odt"]
        if documents.contains(ext) {
            return "doc.fill"
        }

        // Text files
        let textFiles = ["txt", "md", "markdown", "rtf"]
        if textFiles.contains(ext) {
            return "doc.text.fill"
        }

        // Spreadsheets
        let spreadsheets = ["xls", "xlsx", "csv", "numbers"]
        if spreadsheets.contains(ext) {
            return "tablecells.fill"
        }

        // Presentations
        let presentations = ["ppt", "pptx", "key", "keynote"]
        if presentations.contains(ext) {
            return "play.rectangle.fill"
        }

        // Images
        let images = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic", "webp", "svg", "ico"]
        if images.contains(ext) {
            return "photo.fill"
        }

        // Videos
        let videos = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"]
        if videos.contains(ext) {
            return "film.fill"
        }

        // Audio
        let audio = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma"]
        if audio.contains(ext) {
            return "music.note"
        }

        // Code files
        let code = ["swift", "js", "ts", "py", "rb", "go", "rs", "c", "cpp", "h", "java", "kt",
                    "php", "html", "css", "scss", "json", "xml", "yaml", "yml", "sh", "bash",
                    "sql", "r", "m", "mm"]
        if code.contains(ext) {
            return "chevron.left.forwardslash.chevron.right"
        }

        // Archives
        let archives = ["zip", "tar", "gz", "rar", "7z", "dmg", "pkg", "iso"]
        if archives.contains(ext) {
            return "doc.zipper"
        }

        // Executables/Apps
        let executables = ["app", "exe", "dmg"]
        if executables.contains(ext) {
            return "app.fill"
        }

        // Default
        return "doc.fill"
    }

    /// Get icon color for a file extension
    /// - Parameters:
    ///   - extension: File extension
    ///   - isDirectory: Whether this is a directory
    /// - Returns: Color for the icon
    static func getIconColor(forExtension ext: String?, isDirectory: Bool = false) -> String {
        if isDirectory {
            return "blue"
        }

        guard let ext = ext?.lowercased() else {
            return "gray"
        }

        // PDF - red
        if ext == "pdf" {
            return "red"
        }

        // Documents - blue
        let documents = ["doc", "docx", "rtf", "odt", "txt", "md"]
        if documents.contains(ext) {
            return "blue"
        }

        // Spreadsheets - green
        let spreadsheets = ["xls", "xlsx", "csv", "numbers"]
        if spreadsheets.contains(ext) {
            return "green"
        }

        // Images - cyan
        let images = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic", "webp", "svg"]
        if images.contains(ext) {
            return "cyan"
        }

        // Videos - purple
        let videos = ["mp4", "mov", "avi", "mkv", "wmv"]
        if videos.contains(ext) {
            return "purple"
        }

        // Audio - pink
        let audio = ["mp3", "wav", "aac", "flac", "m4a"]
        if audio.contains(ext) {
            return "pink"
        }

        // Code - orange
        let code = ["swift", "js", "ts", "py", "rb", "go", "rs", "c", "cpp", "java", "html", "css", "json"]
        if code.contains(ext) {
            return "orange"
        }

        // Archives - yellow
        let archives = ["zip", "tar", "gz", "rar", "7z", "dmg"]
        if archives.contains(ext) {
            return "yellow"
        }

        return "gray"
    }
}
