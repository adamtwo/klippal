import SwiftUI

/// Row view for a clipboard item with optional search highlighting
struct ClipboardItemRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let highlightRanges: [NSRange]
    let thumbnailImage: NSImage?
    var onDelete: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onLoadFullImage: (() async -> NSImage?)?

    @State private var isHoveringPreviewIcon = false
    @State private var fullImage: NSImage?
    @State private var isLoadingFullImage = false
    @State private var urlPreview: URLPreviewData?
    @State private var isLoadingURLPreview = false

    /// The edge where the popover arrow points (popover appears on opposite side)
    /// Using .leading positions the popover to the left of the main window
    static let popoverArrowEdge: Edge = .leading

    init(item: ClipboardItem, isSelected: Bool, highlightRanges: [NSRange] = [], thumbnailImage: NSImage? = nil, onDelete: (() -> Void)? = nil, onToggleFavorite: (() -> Void)? = nil, onSingleClick: (() -> Void)? = nil, onDoubleClick: (() -> Void)? = nil, onLoadFullImage: (() async -> NSImage?)? = nil) {
        self.item = item
        self.isSelected = isSelected
        self.highlightRanges = highlightRanges
        self.thumbnailImage = thumbnailImage
        self.onDelete = onDelete
        self.onToggleFavorite = onToggleFavorite
        self.onSingleClick = onSingleClick
        self.onDoubleClick = onDoubleClick
        self.onLoadFullImage = onLoadFullImage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Clickable content area (excludes delete button)
            HStack(alignment: .top, spacing: 12) {
                // Icon or Thumbnail - all same size (60x60) with preview button overlay
                ZStack(alignment: .topTrailing) {
                    if item.contentType == .image, let thumbnail = thumbnailImage {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        // Large icon for all content types
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(iconBackgroundColor)
                            Image(systemName: iconForContentType)
                                .font(.system(size: 24))
                                .foregroundColor(iconColor)
                        }
                        .frame(width: 60, height: 60)
                    }

                    // Preview magnifying glass icon - visual indicator for items with preview content
                    if shouldShowPreviewPopover {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.6))
                            .offset(x: -2, y: 2)
                    }
                }
                .contentShape(Rectangle())
                .onHover { hovering in
                    guard shouldShowPreviewPopover else { return }
                    isHoveringPreviewIcon = hovering
                    // Pre-load content when hovering starts (only for async content)
                    if hovering {
                        if item.contentType == .image && fullImage == nil && !isLoadingFullImage {
                            loadFullImageAsync()
                        } else if item.contentType == .url && urlPreview == nil && !isLoadingURLPreview {
                            loadURLPreviewAsync()
                        }
                        // Text preview is now pre-computed and stored in item.previewContent
                    }
                }
                .onTapGesture {
                    // Close popover on click
                    isHoveringPreviewIcon = false
                }
                .popover(isPresented: $isHoveringPreviewIcon, arrowEdge: Self.popoverArrowEdge) {
                    if item.contentType == .image {
                        ImagePreviewPopover(
                            image: fullImage,
                            isLoading: isLoadingFullImage,
                            dimensions: item.content
                        )
                    } else if item.contentType == .url {
                        URLPreviewPopover(
                            url: item.content,
                            preview: urlPreview,
                            isLoading: isLoadingURLPreview
                        )
                    } else {
                        // Use pre-computed preview content (stored in database)
                        TextPreviewPopover(
                            content: item.previewContent ?? item.content,
                            characterCount: item.formattedCharacterCount
                        )
                    }
                }
                .help(shouldShowPreviewPopover ? "Preview content" : "")

                    VStack(alignment: .leading, spacing: 4) {
                        // Content preview with highlighting
                        if item.contentType == .image {
                            // For images, show dimensions/metadata instead of preview
                            Text(item.content)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        } else if item.contentType == .url {
                            // For URLs, show the full URL with highlighting
                            HighlightedText(
                                item.content,
                                highlightRanges: adjustedRanges,
                                highlightColor: .accentColor,
                                lineLimit: 3
                            )
                            .font(.system(size: 13))
                            .foregroundColor(.purple)
                        } else {
                            // Text content
                            HighlightedText(
                                item.preview,
                                highlightRanges: adjustedRanges,
                                highlightColor: .accentColor,
                                lineLimit: 3
                            )
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        }

                        // Metadata
                        HStack(spacing: 8) {
                            Text(item.timestamp.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let appName = item.sourceApp {
                                Text("•")
                                    .foregroundColor(.secondary)
                                    .font(.caption)

                                Text(appName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            // Show character count if content is truncated
                            if item.isTruncated {
                                Text("•")
                                    .foregroundColor(.secondary)
                                    .font(.caption)

                                Text(item.formattedCharacterCount)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            Spacer()
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onDoubleClick?()
                }
                .simultaneousGesture(
                    TapGesture(count: 1).onEnded {
                        onSingleClick?()
                    }
                )

            // Pin button - toggles favorite status
            if let onToggleFavorite = onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: item.isFavorite ? "pin.fill" : "pin")
                        .font(.system(size: 16))
                        .foregroundColor(item.isFavorite ? .orange : .secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help(item.isFavorite ? "Unpin from favorites" : "Pin to favorites")
            }

            // Delete button - always visible on right side (outside clickable area)
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Delete from history")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    /// Whether this item should show a preview popover on hover
    private var shouldShowPreviewPopover: Bool {
        // Show for images (always have full-size preview)
        // Show for URLs (website preview)
        // Show for truncated text
        item.contentType == .image || item.contentType == .url || item.isTruncated
    }

    /// Adjusts highlight ranges to work with the preview text
    /// The preview might be truncated, so we need to clamp ranges
    private var adjustedRanges: [NSRange] {
        let previewText = item.preview
        let previewLength = previewText.utf16.count

        return highlightRanges.compactMap { range -> NSRange? in
            // Skip ranges that start after the preview ends
            guard range.location < previewLength else { return nil }

            // Clamp the range to fit within the preview
            let adjustedLength = min(range.length, previewLength - range.location)
            guard adjustedLength > 0 else { return nil }

            return NSRange(location: range.location, length: adjustedLength)
        }
    }

    /// For URL items, compute highlight ranges that apply to the domain portion
    private var domainHighlightRanges: [NSRange] {
        guard item.contentType == .url,
              let domain = item.displayDomain else { return [] }

        // Find where domain appears in the original content
        let content = item.content.lowercased()
        let domainLower = domain.lowercased()

        guard let domainRange = content.range(of: domainLower) else { return [] }
        let domainStart = content.distance(from: content.startIndex, to: domainRange.lowerBound)

        // Adjust highlight ranges to be relative to domain string
        return highlightRanges.compactMap { range -> NSRange? in
            let rangeEnd = range.location + range.length
            let domainEnd = domainStart + domain.count

            // Check if range overlaps with domain
            guard rangeEnd > domainStart && range.location < domainEnd else { return nil }

            // Calculate the overlap
            let overlapStart = max(range.location, domainStart) - domainStart
            let overlapEnd = min(rangeEnd, domainEnd) - domainStart
            let overlapLength = overlapEnd - overlapStart

            guard overlapLength > 0 else { return nil }

            return NSRange(location: overlapStart, length: overlapLength)
        }
    }

    /// For URL items, compute highlight ranges that apply to the path portion
    private var pathHighlightRanges: [NSRange] {
        guard item.contentType == .url,
              let path = item.displayPath else { return [] }

        // Find where path appears in the original content
        let content = item.content
        guard let pathRange = content.range(of: path) else { return [] }
        let pathStart = content.distance(from: content.startIndex, to: pathRange.lowerBound)

        // Adjust highlight ranges to be relative to path string
        return highlightRanges.compactMap { range -> NSRange? in
            let rangeEnd = range.location + range.length
            let pathEnd = pathStart + path.count

            // Check if range overlaps with path
            guard rangeEnd > pathStart && range.location < pathEnd else { return nil }

            // Calculate the overlap
            let overlapStart = max(range.location, pathStart) - pathStart
            let overlapEnd = min(rangeEnd, pathEnd) - pathStart
            let overlapLength = overlapEnd - overlapStart

            guard overlapLength > 0 else { return nil }

            return NSRange(location: overlapStart, length: overlapLength)
        }
    }

    /// Icon to display based on content type (with special cases for URLs and files)
    private var iconForContentType: String {
        switch item.contentType {
        case .text:
            return "doc.text"
        case .richText:
            return "doc.richtext"
        case .url:
            if item.isCodeRepository {
                return "chevron.left.forwardslash.chevron.right"
            } else if item.isDocumentation {
                return "book"
            } else {
                return "link"
            }
        case .image:
            return "photo"
        case .fileURL:
            // Use file-specific icon based on extension
            return item.fileIconName ?? "doc"
        }
    }

    /// Foreground color for the icon
    private var iconColor: Color {
        switch item.contentType {
        case .text: return .primary
        case .richText: return .indigo
        case .url: return .purple
        case .image: return .blue
        case .fileURL:
            // Use file-specific color based on extension
            guard let colorName = item.fileIconColor else { return .orange }
            switch colorName {
            case "red": return .red
            case "blue": return .blue
            case "green": return .green
            case "cyan": return .cyan
            case "purple": return .purple
            case "pink": return .pink
            case "orange": return .orange
            case "yellow": return .yellow
            default: return .gray
            }
        }
    }

    /// Background color for the icon container
    private var iconBackgroundColor: Color {
        switch item.contentType {
        case .text: return Color.secondary.opacity(0.1)
        case .richText: return Color.indigo.opacity(0.1)
        case .url: return Color.purple.opacity(0.1)
        case .image: return Color.blue.opacity(0.1)
        case .fileURL:
            // Use file-specific background color based on extension
            return iconColor.opacity(0.1)
        }
    }

    /// Load full image asynchronously for preview
    private func loadFullImageAsync() {
        guard let loadFullImage = onLoadFullImage else { return }
        isLoadingFullImage = true
        Task {
            let image = await loadFullImage()
            await MainActor.run {
                fullImage = image
                isLoadingFullImage = false
            }
        }
    }

    /// Load URL preview asynchronously
    private func loadURLPreviewAsync() {
        guard let url = URL(string: item.content) else { return }
        isLoadingURLPreview = true
        Task {
            let preview = await URLPreviewFetcher.fetchPreview(for: url)
            await MainActor.run {
                urlPreview = preview
                isLoadingURLPreview = false
            }
        }
    }
}

// MARK: - URL Preview Data

/// Data structure for URL preview information
struct URLPreviewData {
    let title: String?
    let description: String?
    let siteName: String?
    let imageURL: URL?
    let image: NSImage?
}

/// Fetches preview data for URLs using Open Graph metadata
enum URLPreviewFetcher {
    /// Fetch preview data for a URL
    static func fetchPreview(for url: URL) async -> URLPreviewData? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }

            // Parse Open Graph and standard meta tags
            let title = extractMetaContent(from: html, property: "og:title")
                ?? extractTitle(from: html)
            let description = extractMetaContent(from: html, property: "og:description")
                ?? extractMetaContent(from: html, name: "description")
            let siteName = extractMetaContent(from: html, property: "og:site_name")
                ?? url.host
            let imageURLString = extractMetaContent(from: html, property: "og:image")

            var image: NSImage?
            if let imageURLString = imageURLString,
               let imageURL = URL(string: imageURLString, relativeTo: url) {
                image = await fetchImage(from: imageURL.absoluteURL)
            }

            return URLPreviewData(
                title: title,
                description: description,
                siteName: siteName,
                imageURL: imageURLString.flatMap { URL(string: $0, relativeTo: url)?.absoluteURL },
                image: image
            )
        } catch {
            print("⚠️ Failed to fetch URL preview: \(error)")
            return nil
        }
    }

    /// Extract content from meta tag with property attribute
    private static func extractMetaContent(from html: String, property: String) -> String? {
        let pattern = #"<meta[^>]*property=["\']"# + NSRegularExpression.escapedPattern(for: property) + #"["\'][^>]*content=["\']([^"\']*)["\']"#
        let altPattern = #"<meta[^>]*content=["\']([^"\']*)["\'][^>]*property=["\']"# + NSRegularExpression.escapedPattern(for: property) + #"["\']"#

        if let match = firstMatch(pattern: pattern, in: html) {
            return match
        }
        return firstMatch(pattern: altPattern, in: html)
    }

    /// Extract content from meta tag with name attribute
    private static func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = #"<meta[^>]*name=["\']"# + NSRegularExpression.escapedPattern(for: name) + #"["\'][^>]*content=["\']([^"\']*)["\']"#
        let altPattern = #"<meta[^>]*content=["\']([^"\']*)["\'][^>]*name=["\']"# + NSRegularExpression.escapedPattern(for: name) + #"["\']"#

        if let match = firstMatch(pattern: pattern, in: html) {
            return match
        }
        return firstMatch(pattern: altPattern, in: html)
    }

    /// Extract title from <title> tag
    private static func extractTitle(from html: String) -> String? {
        let pattern = #"<title[^>]*>([^<]*)</title>"#
        return firstMatch(pattern: pattern, in: html)
    }

    /// Helper to find first regex match
    private static func firstMatch(pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: string) else {
            return nil
        }
        let result = String(string[captureRange])
        return result.isEmpty ? nil : decodeHTMLEntities(result)
    }

    /// Decode common HTML entities
    private static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " ")
        ]
        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }

    /// Fetch image from URL
    private static func fetchImage(from url: URL) async -> NSImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Image Preview Popover

/// Popover view showing a larger preview of an image
struct ImagePreviewPopover: View {
    let image: NSImage?
    let isLoading: Bool
    let dimensions: String

    /// Maximum size for the preview
    private let maxPreviewSize: CGFloat = 480

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 200, height: 200)
            } else if let image = image {
                let size = scaledSize(for: image.size)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .cornerRadius(8)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                    .frame(width: 200, height: 200)
            }

            Text(dimensions)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
    }

    /// Calculate scaled size maintaining aspect ratio within max bounds
    private func scaledSize(for originalSize: NSSize) -> CGSize {
        let widthRatio = maxPreviewSize / originalSize.width
        let heightRatio = maxPreviewSize / originalSize.height
        let scale = min(widthRatio, heightRatio, 1.0) // Don't upscale

        return CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
    }
}

// MARK: - Text Preview Popover

/// Popover view showing full text content for truncated items
struct TextPreviewPopover: View {
    let content: String
    let characterCount: String
    var isLoading: Bool = false

    /// Width for the preview text area
    private let textWidth: CGFloat = 380
    /// Maximum height for the scroll area
    private let maxHeight: CGFloat = 300
    /// Maximum characters to show in preview
    private let maxPreviewChars = 1000

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading content...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(width: textWidth, height: 100)
            } else {
                ScrollView {
                    Text(previewText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                        .frame(width: textWidth, alignment: .leading)
                }
                .frame(width: textWidth)
                .frame(maxHeight: maxHeight)

                HStack {
                    Text(characterCount)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if content.count > maxPreviewChars {
                        Text("• showing first \(maxPreviewChars) chars")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    Spacer()
                }
                .frame(width: textWidth)
            }
        }
        .padding(12)
    }

    /// Text to display (truncated if very long)
    private var previewText: String {
        if content.count > maxPreviewChars {
            return String(content.prefix(maxPreviewChars)) + "..."
        }
        return content
    }
}

// MARK: - URL Preview Popover

/// Popover view showing a preview of a URL/website
struct URLPreviewPopover: View {
    let url: String
    let preview: URLPreviewData?
    let isLoading: Bool

    /// Maximum width for the preview
    private let maxWidth: CGFloat = 350
    /// Maximum height for the image
    private let maxImageHeight: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading preview...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(width: maxWidth, height: 120)
            } else if let preview = preview {
                // Preview image
                if let image = preview.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: maxWidth, maxHeight: maxImageHeight)
                        .clipped()
                        .cornerRadius(8)
                }

                // Site name
                if let siteName = preview.siteName {
                    Text(siteName.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                // Title
                if let title = preview.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                // Description
                if let description = preview.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                // URL
                Text(url)
                    .font(.caption)
                    .foregroundColor(.purple)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                // Fallback when no preview available
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "link")
                            .font(.title2)
                            .foregroundColor(.purple)
                        Text("Link Preview")
                            .font(.headline)
                    }

                    Text(url)
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .lineLimit(2)

                    Text("Preview not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: maxWidth)
            }
        }
        .frame(width: maxWidth)
        .padding(12)
    }
}
