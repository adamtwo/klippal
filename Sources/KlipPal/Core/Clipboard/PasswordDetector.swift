import Foundation

/// Detects password-like strings and provides masking functionality
final class PasswordDetector {

    // MARK: - Configuration

    /// Minimum length for a string to be considered a potential password
    private let minPasswordLength = 8

    /// Keywords that suggest the string contains a secret
    private let secretKeywords = [
        "password", "passwd", "pwd", "secret", "token", "api_key", "apikey",
        "api-key", "auth", "bearer", "credential", "private_key", "privatekey",
        "access_token", "refresh_token", "client_secret"
    ]

    // MARK: - Public API

    /// Checks if a string looks like a password or secret
    /// - Parameter text: The text to analyze
    /// - Returns: True if the text appears to be a password-like string
    func looksLikePassword(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty or very short strings are not passwords
        guard trimmed.count >= minPasswordLength else {
            return false
        }

        // Strings with spaces are unlikely to be passwords (prose, code, etc.)
        // Exception: keyword patterns like "password: secret123"
        if trimmed.contains(" ") && !containsSecretKeyword(trimmed) {
            return false
        }

        // Check for keyword patterns first (e.g., "password: secret123")
        if containsSecretKeyword(trimmed) {
            return true
        }

        // Check for JWT tokens
        if looksLikeJWT(trimmed) {
            return true
        }

        // Check for UUID format (often used as tokens)
        if looksLikeUUID(trimmed) {
            return true
        }

        // Check for base64 encoded strings (potential secrets)
        if looksLikeBase64Secret(trimmed) {
            return true
        }

        // Check for API key patterns
        if looksLikeAPIKey(trimmed) {
            return true
        }

        // Skip obvious non-passwords
        if isObviouslyNotPassword(trimmed) {
            return false
        }

        // Check for high entropy random strings
        return hasHighEntropy(trimmed)
    }

    /// Masks a string by replacing all characters with bullets
    /// - Parameters:
    ///   - text: The text to mask
    ///   - character: The character to use for masking (default: bullet)
    /// - Returns: The masked string
    func mask(_ text: String, with character: String = "•") -> String {
        return String(repeating: character, count: text.count)
    }

    /// Masks the text only if it looks like a password
    /// - Parameter text: The text to potentially mask
    /// - Returns: Masked text if it looks like a password, original text otherwise
    func maskIfPassword(_ text: String) -> String {
        if looksLikePassword(text) {
            return mask(text)
        }
        return text
    }

    // MARK: - Detection Helpers

    private func containsSecretKeyword(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        for keyword in secretKeywords {
            // Check for patterns like "password:", "password=", "password "
            if lowercased.contains("\(keyword):") ||
               lowercased.contains("\(keyword)=") ||
               lowercased.contains("\(keyword) ") {
                return true
            }
        }
        return false
    }

    private func looksLikeJWT(_ text: String) -> Bool {
        // JWT format: header.payload.signature (all base64url encoded)
        let parts = text.split(separator: ".")
        guard parts.count == 3 else { return false }

        // Each part should be base64url encoded
        let base64urlPattern = "^[A-Za-z0-9_-]+$"
        guard let regex = try? NSRegularExpression(pattern: base64urlPattern) else { return false }

        for part in parts {
            let range = NSRange(part.startIndex..., in: part)
            if regex.firstMatch(in: String(part), range: range) == nil {
                return false
            }
        }

        // First part typically starts with "eyJ" (base64 for '{"')
        return parts[0].hasPrefix("eyJ")
    }

    private func looksLikeUUID(_ text: String) -> Bool {
        // UUID format: 8-4-4-4-12 hex digits
        let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        guard let regex = try? NSRegularExpression(pattern: uuidPattern) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    private func looksLikeBase64Secret(_ text: String) -> Bool {
        // Base64 strings end with = or == for padding
        guard text.hasSuffix("=") else { return false }

        // Must be long enough
        guard text.count >= 20 else { return false }

        // Should only contain base64 characters
        let base64Pattern = "^[A-Za-z0-9+/]+=*$"
        guard let regex = try? NSRegularExpression(pattern: base64Pattern) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    private func looksLikeAPIKey(_ text: String) -> Bool {
        // Common API key prefixes
        let apiKeyPrefixes = ["sk_", "pk_", "ghp_", "gho_", "ghu_", "ghs_", "ghr_", "AKIA", "xox"]
        for prefix in apiKeyPrefixes {
            if text.hasPrefix(prefix) && text.count >= 20 {
                return true
            }
        }
        return false
    }

    private func isObviouslyNotPassword(_ text: String) -> Bool {
        // URLs
        if text.hasPrefix("http://") || text.hasPrefix("https://") || text.hasPrefix("file://") {
            return true
        }

        // Email addresses
        let emailPattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        if let regex = try? NSRegularExpression(pattern: emailPattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }

        // File paths
        if text.hasPrefix("/") || text.hasPrefix("~/") || text.hasPrefix("./") {
            // But only if it looks like a path (contains / after the prefix)
            if text.dropFirst(2).contains("/") {
                return true
            }
        }

        // Phone numbers (contains mostly digits with common separators)
        let digitsAndSeps = text.filter { $0.isNumber || "()-+ ".contains($0) }
        if digitsAndSeps.count > text.count / 2 && text.filter({ $0.isNumber }).count >= 7 {
            return true
        }

        // Plain numbers (including decimals)
        if Double(text) != nil {
            return true
        }

        // Contains significant whitespace (likely prose)
        let words = text.split(separator: " ")
        if words.count >= 3 {
            // Check if words are mostly dictionary-like (lowercase letters)
            let normalWords = words.filter { word in
                word.allSatisfy { $0.isLetter && $0.isLowercase }
            }
            if normalWords.count >= words.count / 2 {
                return true
            }
        }

        // Code-like patterns with common keywords
        let codeKeywords = ["func ", "let ", "var ", "import ", "class ", "struct ", "return ", "if ", "for "]
        for keyword in codeKeywords {
            if text.contains(keyword) {
                return true
            }
        }

        return false
    }

    private func hasHighEntropy(_ text: String) -> Bool {
        // Calculate character class diversity
        var hasLower = false
        var hasUpper = false
        var hasDigit = false
        var hasSymbol = false

        for char in text {
            if char.isLowercase { hasLower = true }
            else if char.isUppercase { hasUpper = true }
            else if char.isNumber { hasDigit = true }
            else if !char.isWhitespace { hasSymbol = true }
        }

        let classCount = [hasLower, hasUpper, hasDigit, hasSymbol].filter { $0 }.count

        // High entropy requires at least 3 character classes and reasonable length
        if classCount >= 3 && text.count >= 8 && text.count <= 128 {
            // Also check that it's not too repetitive
            let uniqueChars = Set(text)
            let uniqueRatio = Double(uniqueChars.count) / Double(text.count)

            // Should have reasonable character diversity
            return uniqueRatio >= 0.3
        }

        return false
    }
}
