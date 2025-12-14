import Foundation

/// Which field the search matched on
enum SearchMatchField {
    case content
    case filename
    case sourceApp
}

/// Result of a search operation containing the matched item and metadata
struct SearchResult {
    /// The clipboard item that matched
    let item: ClipboardItem

    /// Match score from 0.0 to 1.0
    let score: Double

    /// Ranges in the content that matched (for highlighting)
    /// Only valid when matchField is .content or .filename
    let matchedRanges: [NSRange]

    /// Which field the match was found in
    let matchField: SearchMatchField

    /// Type of match (exact or fuzzy)
    let matchType: MatchType
}

/// Search engine that coordinates fuzzy matching across clipboard items
/// Searches content, sourceApp, and filename (for file items)
class SearchEngine {
    private let matcher = FuzzyMatcher()

    // Content matches are weighted higher than source app matches
    private let contentWeight: Double = 1.0
    private let filenameWeight: Double = 1.2  // Filename matches ranked highest for files
    private let sourceAppWeight: Double = 0.7

    /// Whether fuzzy matching is enabled (syncs with preferences)
    var fuzzyMatchingEnabled: Bool {
        get { matcher.fuzzyMatchingEnabled }
        set { matcher.fuzzyMatchingEnabled = newValue }
    }

    /// Searches for items matching the query
    /// - Parameters:
    ///   - query: The search query (empty returns all items)
    ///   - items: The items to search through
    /// - Returns: Sorted array of SearchResult - exact matches by timestamp (newest first),
    ///            then fuzzy matches by timestamp (newest first)
    func search(query: String, in items: [ClipboardItem]) -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        // Empty query returns all items sorted by timestamp (newest first)
        if trimmedQuery.isEmpty {
            return items.map { item in
                SearchResult(item: item, score: 1.0, matchedRanges: [], matchField: .content, matchType: .exact)
            }
        }

        var results: [SearchResult] = []

        for item in items {
            if let result = matchItem(query: trimmedQuery, item: item) {
                results.append(result)
            }
        }

        // Sort: exact matches first (by timestamp, newest first), then fuzzy matches (by timestamp, newest first)
        results.sort { lhs, rhs in
            // First, separate exact from fuzzy
            if lhs.matchType != rhs.matchType {
                return lhs.matchType == .exact  // Exact matches come first
            }
            // Within same match type, sort by timestamp (newest first)
            return lhs.item.timestamp > rhs.item.timestamp
        }

        return results
    }

    /// Matches a query against a single clipboard item
    /// Checks content, filename (for files), and sourceApp - returns the best match
    private func matchItem(query: String, item: ClipboardItem) -> SearchResult? {
        var bestScore: Double = 0
        var bestRanges: [NSRange] = []
        var bestField: SearchMatchField = .content
        var bestMatchType: MatchType = .exact

        // For file URLs, search behavior depends on fuzzy setting
        if item.contentType == .fileURL {
            // Always try matching the filename (what the user sees)
            if let filename = item.displayFilename,
               let filenameMatch = matcher.match(query: query, in: filename) {
                let weightedScore = filenameMatch.score * filenameWeight
                if weightedScore > bestScore {
                    bestScore = weightedScore
                    bestRanges = filenameMatch.matchedRanges
                    bestField = .filename
                    bestMatchType = filenameMatch.matchType
                }
            }

            // Only search full path when fuzzy search is enabled
            if fuzzyMatchingEnabled,
               let contentMatch = matcher.match(query: query, in: item.content) {
                let weightedScore = contentMatch.score * contentWeight
                if weightedScore > bestScore {
                    bestScore = weightedScore
                    // Don't use ranges from full path - UI displays filename only
                    bestRanges = []
                    bestField = .content
                    bestMatchType = contentMatch.matchType
                }
            }
        } else {
            // For non-file items, always try matching content
            if let contentMatch = matcher.match(query: query, in: item.content) {
                let weightedScore = contentMatch.score * contentWeight
                if weightedScore > bestScore {
                    bestScore = weightedScore
                    bestRanges = contentMatch.matchedRanges
                    bestField = .content
                    bestMatchType = contentMatch.matchType
                }
            }
        }

        // Try matching source app (only when fuzzy search is enabled)
        // When fuzzy search is disabled, users expect strict content matching only
        if fuzzyMatchingEnabled,
           let sourceApp = item.sourceApp,
           let appMatch = matcher.match(query: query, in: sourceApp) {
            let weightedScore = appMatch.score * sourceAppWeight
            if weightedScore > bestScore {
                bestScore = weightedScore
                // Don't use ranges from sourceApp match - they don't apply to content
                bestRanges = []
                bestField = .sourceApp
                bestMatchType = appMatch.matchType
            }
        }

        guard bestScore > 0 else { return nil }

        return SearchResult(item: item, score: bestScore, matchedRanges: bestRanges, matchField: bestField, matchType: bestMatchType)
    }
}
