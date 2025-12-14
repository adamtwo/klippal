import XCTest
@testable import KlipPal

/// Unit tests for FuzzyMatcher - the core fuzzy matching algorithm
final class FuzzyMatcherTests: XCTestCase {

    // MARK: - Exact Match Tests

    func testExactMatchReturnsHighScore() {
        let matcher = FuzzyMatcher()
        let result = matcher.match(query: "hello", in: "hello")

        XCTAssertNotNil(result, "Exact match should return a result")
        guard let result = result else { return }
        XCTAssertGreaterThan(result.score, 0.9, "Exact match should have very high score")
    }

    func testExactMatchCaseInsensitive() {
        let matcher = FuzzyMatcher()

        let result1 = matcher.match(query: "Hello", in: "hello")
        let result2 = matcher.match(query: "HELLO", in: "hello")
        let result3 = matcher.match(query: "hello", in: "HELLO")

        XCTAssertNotNil(result1, "Case-insensitive match should work")
        XCTAssertNotNil(result2, "Case-insensitive match should work")
        XCTAssertNotNil(result3, "Case-insensitive match should work")
    }

    // MARK: - Prefix Match Tests

    func testPrefixMatchScoresHigherThanSubstring() {
        let matcher = FuzzyMatcher()

        let prefixResult = matcher.match(query: "copy", in: "copy manager app")
        let substringResult = matcher.match(query: "copy", in: "the copy is here")

        XCTAssertNotNil(prefixResult, "Prefix match should return result")
        XCTAssertNotNil(substringResult, "Substring match should return result")
        guard let prefix = prefixResult, let substring = substringResult else { return }
        XCTAssertGreaterThan(prefix.score, substring.score,
            "Prefix match should score higher than substring match")
    }

    func testWordBoundaryPrefixMatch() {
        let matcher = FuzzyMatcher()

        // "man" at word boundary in "copy manager" should score higher
        // than "man" in "command"
        let wordBoundaryResult = matcher.match(query: "man", in: "copy manager")
        let midWordResult = matcher.match(query: "man", in: "command line")

        XCTAssertNotNil(wordBoundaryResult, "Word boundary match should return result")
        XCTAssertNotNil(midWordResult, "Mid-word match should return result")
        guard let wordBoundary = wordBoundaryResult, let midWord = midWordResult else { return }
        XCTAssertGreaterThan(wordBoundary.score, midWord.score,
            "Word boundary match should score higher")
    }

    // MARK: - Substring Match Tests

    func testSubstringMatchReturnsResult() {
        let matcher = FuzzyMatcher()
        let result = matcher.match(query: "clip", in: "my clipboard manager")

        XCTAssertNotNil(result, "Substring match should return result")
        guard let result = result else { return }
        XCTAssertTrue(result.score > 0, "Substring match should have positive score")
    }

    func testMultipleSubstringOccurrences() {
        let matcher = FuzzyMatcher()
        let result = matcher.match(query: "the", in: "the cat and the dog")

        XCTAssertNotNil(result, "Should match even with multiple occurrences")
    }

    // MARK: - Fuzzy Match Tests (character skipping)

    func testFuzzyMatchWithSkippedCharacters() {
        let matcher = FuzzyMatcher()

        // "cpmgr" should match "CopyManager" (c-p-m-g-r)
        let result = matcher.match(query: "cpmgr", in: "CopyManager")

        XCTAssertNotNil(result, "Fuzzy match with skipped characters should work")
    }

    func testFuzzyMatchConsecutiveBonus() {
        let matcher = FuzzyMatcher()

        // "copy" (consecutive) should score higher than "c-o-p-y" spread out
        let consecutiveResult = matcher.match(query: "copy", in: "copy manager")
        let spreadResult = matcher.match(query: "copy", in: "c_o_p_y")

        XCTAssertNotNil(consecutiveResult, "Consecutive match should return result")
        XCTAssertNotNil(spreadResult, "Spread match should return result")
        guard let consecutive = consecutiveResult, let spread = spreadResult else { return }
        XCTAssertGreaterThan(consecutive.score, spread.score,
            "Consecutive matches should score higher than spread matches")
    }

    func testFuzzyMatchAcronym() {
        let matcher = FuzzyMatcher()

        // "cm" should match "CopyManager" (acronym-style)
        let result = matcher.match(query: "cm", in: "CopyManager")

        XCTAssertNotNil(result, "Acronym-style match should work")
    }

    // MARK: - No Match Tests

    func testNoMatchReturnsNil() {
        let matcher = FuzzyMatcher()
        let result = matcher.match(query: "xyz", in: "hello world")

        XCTAssertNil(result, "Non-matching query should return nil")
    }

    func testEmptyQueryReturnsNil() {
        let matcher = FuzzyMatcher()
        let result = matcher.match(query: "", in: "hello world")

        XCTAssertNil(result, "Empty query should return nil")
    }

    func testEmptyTextReturnsNil() {
        let matcher = FuzzyMatcher()
        let result = matcher.match(query: "hello", in: "")

        XCTAssertNil(result, "Empty text should return nil")
    }

    func testQueryLongerThanTextReturnsNil() {
        let matcher = FuzzyMatcher()
        let result = matcher.match(query: "hello world", in: "hi")

        XCTAssertNil(result, "Query longer than text should return nil")
    }

    // MARK: - Match Range Tests

    func testMatchReturnsCorrectRanges() {
        let matcher = FuzzyMatcher()
        let result = matcher.match(query: "hello", in: "say hello there")

        XCTAssertNotNil(result, "Should return a result")
        guard let result = result else { return }
        XCTAssertFalse(result.matchedRanges.isEmpty, "Should return matched ranges")

        // Verify the ranges point to actual matched characters
        let text = "say hello there"
        for range in result.matchedRanges {
            let startIndex = text.index(text.startIndex, offsetBy: range.location)
            let endIndex = text.index(startIndex, offsetBy: range.length)
            let matchedSubstring = String(text[startIndex..<endIndex])
            XCTAssertFalse(matchedSubstring.isEmpty, "Matched range should contain text")
        }
    }

    // MARK: - Score Comparison Tests

    func testExactMatchScoresHighestThenPrefixThenSubstring() {
        let matcher = FuzzyMatcher()

        guard let exactResult = matcher.match(query: "copy", in: "copy"),
              let prefixResult = matcher.match(query: "copy", in: "copy manager"),
              let substringResult = matcher.match(query: "copy", in: "my copy here"),
              let fuzzyResult = matcher.match(query: "cpy", in: "copy") else {
            XCTFail("All matches should return results")
            return
        }

        XCTAssertGreaterThan(exactResult.score, prefixResult.score, "Exact > Prefix")
        XCTAssertGreaterThan(prefixResult.score, substringResult.score, "Prefix > Substring")
        XCTAssertGreaterThan(substringResult.score, fuzzyResult.score, "Substring > Fuzzy")
    }

    func testShorterMatchScoresHigher() {
        let matcher = FuzzyMatcher()

        // Matching "copy" in shorter text should score higher
        let shortResult = matcher.match(query: "copy", in: "copy app")
        let longResult = matcher.match(query: "copy", in: "this is a very long text with copy somewhere")

        XCTAssertNotNil(shortResult, "Short text match should return result")
        XCTAssertNotNil(longResult, "Long text match should return result")
        guard let short = shortResult, let long = longResult else { return }
        XCTAssertGreaterThan(short.score, long.score,
            "Match in shorter text should score higher")
    }

    // MARK: - Unicode and Special Characters

    func testUnicodeMatching() {
        let matcher = FuzzyMatcher()

        let result = matcher.match(query: "café", in: "I love café")
        XCTAssertNotNil(result, "Unicode characters should match")
    }

    func testEmojiMatching() {
        let matcher = FuzzyMatcher()

        let result = matcher.match(query: "🎉", in: "Party 🎉 time")
        XCTAssertNotNil(result, "Emoji should match")
    }

    func testSpecialCharactersMatching() {
        let matcher = FuzzyMatcher()

        let result = matcher.match(query: "c++", in: "I code in C++")
        XCTAssertNotNil(result, "Special characters should match")
    }

    // MARK: - Whitespace Handling

    func testMultiWordQuery() {
        let matcher = FuzzyMatcher()

        let result = matcher.match(query: "hello world", in: "hello beautiful world")
        XCTAssertNotNil(result, "Multi-word query should match")
    }

    func testLeadingTrailingWhitespace() {
        let matcher = FuzzyMatcher()

        let result1 = matcher.match(query: "  hello", in: "hello world")
        let result2 = matcher.match(query: "hello  ", in: "hello world")

        // Should either trim whitespace or handle it gracefully
        XCTAssertNotNil(result1, "Leading whitespace should be handled")
        XCTAssertNotNil(result2, "Trailing whitespace should be handled")
    }

    // MARK: - Performance Tests

    func testPerformanceWithLongText() {
        let matcher = FuzzyMatcher()
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100)

        measure {
            _ = matcher.match(query: "ipsum", in: longText)
        }
    }

    func testPerformanceWithManyMatches() {
        let matcher = FuzzyMatcher()
        let text = String(repeating: "abc ", count: 1000)

        measure {
            _ = matcher.match(query: "abc", in: text)
        }
    }
}

// MARK: - FuzzyMatchResult Tests

/// Tests for the FuzzyMatchResult struct
final class FuzzyMatchResultTests: XCTestCase {

    func testResultContainsScore() {
        let result = FuzzyMatchResult(score: 0.8, matchedRanges: [], matchType: .exact)
        XCTAssertEqual(result.score, 0.8)
    }

    func testResultContainsRanges() {
        let ranges = [NSRange(location: 0, length: 3), NSRange(location: 5, length: 2)]
        let result = FuzzyMatchResult(score: 0.5, matchedRanges: ranges, matchType: .exact)

        XCTAssertEqual(result.matchedRanges.count, 2)
        XCTAssertEqual(result.matchedRanges[0].location, 0)
        XCTAssertEqual(result.matchedRanges[1].location, 5)
    }

    func testResultComparable() {
        let result1 = FuzzyMatchResult(score: 0.8, matchedRanges: [], matchType: .exact)
        let result2 = FuzzyMatchResult(score: 0.5, matchedRanges: [], matchType: .fuzzy)

        XCTAssertGreaterThan(result1.score, result2.score)
    }
}
