import SwiftUI

/// A view that renders text with highlighted portions based on NSRange matches
struct HighlightedText: View {
    let text: String
    let ranges: [NSRange]
    let highlightColor: Color
    let lineLimit: Int?

    init(
        _ text: String,
        highlightRanges ranges: [NSRange] = [],
        highlightColor: Color = .yellow,
        lineLimit: Int? = nil
    ) {
        self.text = text
        self.ranges = ranges
        self.highlightColor = highlightColor
        self.lineLimit = lineLimit
    }

    var body: some View {
        if ranges.isEmpty {
            // No highlighting needed
            Text(text)
                .lineLimit(lineLimit)
        } else {
            // Build attributed text with highlights
            Text(attributedString)
                .lineLimit(lineLimit)
        }
    }

    private var attributedString: AttributedString {
        var result = AttributedString(text)

        // Sort ranges by location to process in order
        let sortedRanges = ranges.sorted { $0.location < $1.location }

        for range in sortedRanges {
            // Convert NSRange to AttributedString range
            guard let swiftRange = Range(range, in: text) else { continue }
            guard let attributedRange = Range(swiftRange, in: result) else { continue }

            // Apply highlight styling
            result[attributedRange].backgroundColor = highlightColor.opacity(0.3)
            result[attributedRange].foregroundColor = .primary
        }

        return result
    }
}

// MARK: - Preview

#if DEBUG
struct HighlightedText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            // No highlight
            HighlightedText("Hello world, this is a test")

            // Single word highlight
            HighlightedText(
                "Hello world, this is a test",
                highlightRanges: [NSRange(location: 0, length: 5)]
            )

            // Multiple highlights
            HighlightedText(
                "Copy manager clipboard app",
                highlightRanges: [
                    NSRange(location: 0, length: 4),
                    NSRange(location: 13, length: 9)
                ]
            )

            // Custom color
            HighlightedText(
                "Search result with match",
                highlightRanges: [NSRange(location: 7, length: 6)],
                highlightColor: .blue
            )
        }
        .padding()
    }
}
#endif
