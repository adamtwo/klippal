import Foundation

/// Result of a fuzzy match operation
struct FuzzyMatchResult {
    /// Match score from 0.0 (no match) to 1.0 (perfect match)
    let score: Double

    /// Ranges in the original text that matched the query
    let matchedRanges: [NSRange]
}

/// Fuzzy string matching algorithm
/// Supports exact match, prefix match, substring match, and character-skipping fuzzy match
/// Scoring priority: exact > prefix > word boundary > substring > fuzzy
class FuzzyMatcher {

    // MARK: - Scoring Constants

    private enum Score {
        static let exactMatch: Double = 1.0
        static let prefixMatch: Double = 0.9
        static let wordBoundaryMatch: Double = 0.8
        static let substringMatch: Double = 0.7
        static let fuzzyMatch: Double = 0.5

        // Bonuses
        static let consecutiveBonus: Double = 0.05
        static let camelCaseBonus: Double = 0.03

        // Penalties
        static let lengthPenaltyFactor: Double = 0.001
    }

    // MARK: - Public API

    /// Matches a query against text and returns a result with score and matched ranges
    /// - Parameters:
    ///   - query: The search query
    ///   - text: The text to search in
    /// - Returns: FuzzyMatchResult if there's a match, nil otherwise
    func match(query: String, in text: String) -> FuzzyMatchResult? {
        // Handle edge cases
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty, !text.isEmpty else {
            return nil
        }

        let lowerQuery = trimmedQuery.lowercased()
        let lowerText = text.lowercased()

        // Query longer than text can't match (for substring/exact)
        // But fuzzy match might still work, so we check fuzzy last

        // Try different match types in order of preference
        if let result = tryExactMatch(query: lowerQuery, in: text, lowerText: lowerText) {
            return result
        }

        if let result = tryPrefixMatch(query: lowerQuery, in: text, lowerText: lowerText) {
            return result
        }

        if let result = tryWordBoundaryMatch(query: lowerQuery, in: text, lowerText: lowerText) {
            return result
        }

        if let result = trySubstringMatch(query: lowerQuery, in: text, lowerText: lowerText) {
            return result
        }

        if let result = tryFuzzyMatch(query: lowerQuery, in: text, lowerText: lowerText) {
            return result
        }

        return nil
    }

    // MARK: - Match Strategies

    /// Exact match: query equals text exactly (case-insensitive)
    private func tryExactMatch(query: String, in text: String, lowerText: String) -> FuzzyMatchResult? {
        guard lowerText == query else { return nil }

        let range = NSRange(location: 0, length: text.utf16.count)
        return FuzzyMatchResult(score: Score.exactMatch, matchedRanges: [range])
    }

    /// Prefix match: text starts with query
    private func tryPrefixMatch(query: String, in text: String, lowerText: String) -> FuzzyMatchResult? {
        guard lowerText.hasPrefix(query) else { return nil }

        let range = NSRange(location: 0, length: query.utf16.count)
        let lengthPenalty = Double(text.count) * Score.lengthPenaltyFactor
        let score = max(0.1, Score.prefixMatch - lengthPenalty)

        return FuzzyMatchResult(score: score, matchedRanges: [range])
    }

    /// Word boundary match: query matches at the start of a word
    private func tryWordBoundaryMatch(query: String, in text: String, lowerText: String) -> FuzzyMatchResult? {
        // Find all word boundaries
        let words = lowerText.components(separatedBy: CharacterSet.alphanumerics.inverted)
        var currentLocation = 0

        for word in words {
            if word.isEmpty {
                currentLocation += 1
                continue
            }

            // Find actual location in original text
            if let range = lowerText.range(of: word, range: lowerText.index(lowerText.startIndex, offsetBy: currentLocation)..<lowerText.endIndex) {
                let location = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)

                if word.hasPrefix(query) {
                    let nsRange = NSRange(location: location, length: query.utf16.count)
                    let lengthPenalty = Double(text.count) * Score.lengthPenaltyFactor
                    let score = max(0.1, Score.wordBoundaryMatch - lengthPenalty)
                    return FuzzyMatchResult(score: score, matchedRanges: [nsRange])
                }

                currentLocation = location + word.count
            } else {
                currentLocation += word.count + 1
            }
        }

        return nil
    }

    /// Substring match: query appears somewhere in text
    private func trySubstringMatch(query: String, in text: String, lowerText: String) -> FuzzyMatchResult? {
        guard let range = lowerText.range(of: query) else { return nil }

        let location = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)
        let nsRange = NSRange(location: location, length: query.utf16.count)

        let lengthPenalty = Double(text.count) * Score.lengthPenaltyFactor
        let positionPenalty = Double(location) * Score.lengthPenaltyFactor * 0.5
        let score = max(0.1, Score.substringMatch - lengthPenalty - positionPenalty)

        return FuzzyMatchResult(score: score, matchedRanges: [nsRange])
    }

    /// Fuzzy match: characters appear in order but not necessarily consecutive
    private func tryFuzzyMatch(query: String, in text: String, lowerText: String) -> FuzzyMatchResult? {
        let queryChars = Array(query)
        let textChars = Array(lowerText)

        guard !queryChars.isEmpty else { return nil }

        var matchedRanges: [NSRange] = []
        var queryIndex = 0
        var consecutiveCount = 0
        var lastMatchIndex = -2  // Track consecutive matches
        var totalConsecutiveBonus: Double = 0

        for (textIndex, textChar) in textChars.enumerated() {
            if queryIndex < queryChars.count && textChar == queryChars[queryIndex] {
                // Check if this is a consecutive match
                if textIndex == lastMatchIndex + 1 {
                    consecutiveCount += 1
                    totalConsecutiveBonus += Score.consecutiveBonus
                } else {
                    consecutiveCount = 0
                }

                // Check for camelCase bonus (uppercase after lowercase)
                let originalTextChars = Array(text)
                if textIndex > 0 && textIndex < originalTextChars.count {
                    let currentChar = originalTextChars[textIndex]
                    let prevChar = originalTextChars[textIndex - 1]
                    if currentChar.isUppercase && prevChar.isLowercase {
                        totalConsecutiveBonus += Score.camelCaseBonus
                    }
                }

                matchedRanges.append(NSRange(location: textIndex, length: 1))
                lastMatchIndex = textIndex
                queryIndex += 1
            }
        }

        // All query characters must be found
        guard queryIndex == queryChars.count else { return nil }

        // Calculate score
        let baseScore = Score.fuzzyMatch
        let lengthPenalty = Double(text.count) * Score.lengthPenaltyFactor
        let spreadPenalty = Double(matchedRanges.last!.location - matchedRanges.first!.location) * Score.lengthPenaltyFactor * 0.5

        let score = max(0.1, baseScore + totalConsecutiveBonus - lengthPenalty - spreadPenalty)

        // Merge consecutive ranges for cleaner output
        let mergedRanges = mergeConsecutiveRanges(matchedRanges)

        return FuzzyMatchResult(score: score, matchedRanges: mergedRanges)
    }

    // MARK: - Helpers

    /// Merges consecutive NSRanges into single ranges
    private func mergeConsecutiveRanges(_ ranges: [NSRange]) -> [NSRange] {
        guard !ranges.isEmpty else { return [] }

        var merged: [NSRange] = []
        var current = ranges[0]

        for i in 1..<ranges.count {
            let next = ranges[i]
            if current.location + current.length == next.location {
                // Extend current range
                current = NSRange(location: current.location, length: current.length + next.length)
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)

        return merged
    }
}
