import Foundation

/// Result of a search operation containing the matched item and metadata
struct SearchResult {
    /// The clipboard item that matched
    let item: ClipboardItem

    /// Match score from 0.0 to 1.0
    let score: Double

    /// Ranges in the content that matched (for highlighting)
    let matchedRanges: [NSRange]
}

/// Search engine that coordinates fuzzy matching across clipboard items
/// Searches content, sourceApp, and filename (for file items)
class SearchEngine {
    private let matcher = FuzzyMatcher()

    // Content matches are weighted higher than source app matches
    private let contentWeight: Double = 1.0
    private let filenameWeight: Double = 1.2  // Filename matches ranked highest for files
    private let sourceAppWeight: Double = 0.7

    /// Searches for items matching the query
    /// - Parameters:
    ///   - query: The search query (empty returns all items)
    ///   - items: The items to search through
    /// - Returns: Sorted array of SearchResult, highest score first
    func search(query: String, in items: [ClipboardItem]) -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        // Empty query returns all items with default score
        if trimmedQuery.isEmpty {
            return items.map { item in
                SearchResult(item: item, score: 1.0, matchedRanges: [])
            }
        }

        var results: [SearchResult] = []

        for item in items {
            if let result = matchItem(query: trimmedQuery, item: item) {
                results.append(result)
            }
        }

        // Sort by score descending
        results.sort { $0.score > $1.score }

        return results
    }

    /// Matches a query against a single clipboard item
    /// Checks content, filename (for files), and sourceApp - returns the best match
    private func matchItem(query: String, item: ClipboardItem) -> SearchResult? {
        var bestScore: Double = 0
        var bestRanges: [NSRange] = []

        // Try matching content
        if let contentMatch = matcher.match(query: query, in: item.content) {
            let weightedScore = contentMatch.score * contentWeight
            if weightedScore > bestScore {
                bestScore = weightedScore
                bestRanges = contentMatch.matchedRanges
            }
        }

        // For file URLs, also try matching the filename (what the user sees)
        if item.contentType == .fileURL,
           let filename = item.displayFilename,
           let filenameMatch = matcher.match(query: query, in: filename) {
            let weightedScore = filenameMatch.score * filenameWeight
            if weightedScore > bestScore {
                bestScore = weightedScore
                // Return ranges relative to the filename for highlighting
                bestRanges = filenameMatch.matchedRanges
            }
        }

        // Try matching source app
        if let sourceApp = item.sourceApp,
           let appMatch = matcher.match(query: query, in: sourceApp) {
            let weightedScore = appMatch.score * sourceAppWeight
            if weightedScore > bestScore {
                bestScore = weightedScore
                // Note: ranges are for sourceApp, not content
                // For highlighting, we might want to track which field matched
                bestRanges = appMatch.matchedRanges
            }
        }

        guard bestScore > 0 else { return nil }

        return SearchResult(item: item, score: bestScore, matchedRanges: bestRanges)
    }
}
