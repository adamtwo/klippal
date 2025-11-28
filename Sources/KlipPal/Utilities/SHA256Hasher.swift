import Foundation
import CryptoKit

/// Utility for generating SHA256 hashes for deduplication
enum SHA256Hasher {
    /// Generate SHA256 hash from string content
    static func hash(string: String) -> String {
        let data = Data(string.utf8)
        return hash(data: data)
    }

    /// Generate SHA256 hash from data
    static func hash(data: Data) -> String {
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
