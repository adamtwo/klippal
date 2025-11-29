import SwiftUI

/// Row view for a clipboard item with optional search highlighting
struct ClipboardItemRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let highlightRanges: [NSRange]
    let thumbnailImage: NSImage?
    var onDelete: (() -> Void)?
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    init(item: ClipboardItem, isSelected: Bool, highlightRanges: [NSRange] = [], thumbnailImage: NSImage? = nil, onDelete: (() -> Void)? = nil, onSingleClick: (() -> Void)? = nil, onDoubleClick: (() -> Void)? = nil) {
        self.item = item
        self.isSelected = isSelected
        self.highlightRanges = highlightRanges
        self.thumbnailImage = thumbnailImage
        self.onDelete = onDelete
        self.onSingleClick = onSingleClick
        self.onDoubleClick = onDoubleClick
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Clickable content area (excludes delete button)
            HStack(alignment: .top, spacing: 12) {
                // Icon or Thumbnail - all same size (60x60)
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

                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
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
        case .url: return Color.purple.opacity(0.1)
        case .image: return Color.blue.opacity(0.1)
        case .fileURL:
            // Use file-specific background color based on extension
            return iconColor.opacity(0.1)
        }
    }
}
