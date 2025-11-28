import Foundation

/// Extracts metadata from URLs for display purposes
enum URLMetadataExtractor {

    /// Extract the domain from a URL, removing 'www.' prefix
    /// - Parameter url: The URL to extract domain from
    /// - Returns: The domain (e.g., "github.com") or nil if invalid
    static func extractDomain(from url: URL) -> String? {
        guard let host = url.host else { return nil }

        // Remove www. prefix if present
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }

        return host
    }

    /// Extract the domain from a URL string
    /// - Parameter urlString: The URL string
    /// - Returns: The domain or nil if invalid
    static func extractDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return extractDomain(from: url)
    }

    /// Extract the path from a URL
    /// - Parameter url: The URL to extract path from
    /// - Returns: The path (e.g., "/user/repo") or nil if empty
    static func extractPath(from url: URL) -> String? {
        let path = url.path
        return path.isEmpty ? nil : path
    }

    /// Extract the path from a URL string
    /// - Parameter urlString: The URL string
    /// - Returns: The path or nil if invalid/empty
    static func extractPath(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return extractPath(from: url)
    }

    /// Extract a human-readable title from a URL
    /// This attempts to derive a title from the URL path
    /// - Parameter url: The URL to extract title from
    /// - Returns: A derived title or nil
    static func extractTitle(from url: URL) -> String? {
        let path = url.path

        // Remove leading slash and split by /
        let components = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/")
            .filter { !$0.isEmpty }

        // Try to get a meaningful title from the last path component
        guard let lastComponent = components.last else {
            // If no path, use the domain
            return extractDomain(from: url)
        }

        // Clean up the component
        var title = lastComponent

        // Remove common file extensions
        let extensions = [".html", ".htm", ".php", ".asp", ".aspx", ".jsp"]
        for ext in extensions {
            if title.lowercased().hasSuffix(ext) {
                title = String(title.dropLast(ext.count))
            }
        }

        // Replace dashes and underscores with spaces
        title = title.replacingOccurrences(of: "-", with: " ")
        title = title.replacingOccurrences(of: "_", with: " ")

        // Capitalize first letter of each word
        title = title.capitalized

        return title.isEmpty ? nil : title
    }

    /// Extract a human-readable title from a URL string
    /// - Parameter urlString: The URL string
    /// - Returns: A derived title or nil
    static func extractTitle(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return extractTitle(from: url)
    }

    /// Get a formatted display string for a URL
    /// - Parameter urlString: The URL string
    /// - Returns: A nicely formatted display string
    static func formatForDisplay(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }

        let domain = extractDomain(from: url) ?? ""
        let path = url.path

        // For short URLs, return as-is
        if urlString.count <= 50 {
            return urlString
        }

        // For longer URLs, show domain + truncated path
        if path.isEmpty || path == "/" {
            return domain
        }

        let truncatedPath = path.count > 30 ? String(path.prefix(27)) + "..." : path
        return "\(domain)\(truncatedPath)"
    }

    /// Check if a URL is likely a documentation/reference page
    /// - Parameter url: The URL to check
    /// - Returns: True if it appears to be documentation
    static func isDocumentation(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        let docHosts = ["docs.", "documentation.", "developer.", "api.", "reference."]
        let docPaths = ["/docs", "/documentation", "/api", "/reference", "/guide", "/manual"]

        for docHost in docHosts {
            if host.contains(docHost) { return true }
        }

        for docPath in docPaths {
            if path.contains(docPath) { return true }
        }

        return false
    }

    /// Check if a URL is a code repository
    /// - Parameter url: The URL to check
    /// - Returns: True if it appears to be a code repository
    static func isCodeRepository(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""

        let repoHosts = ["github.com", "gitlab.com", "bitbucket.org", "codeberg.org", "sr.ht"]

        for repoHost in repoHosts {
            if host.contains(repoHost) { return true }
        }

        return false
    }
}
