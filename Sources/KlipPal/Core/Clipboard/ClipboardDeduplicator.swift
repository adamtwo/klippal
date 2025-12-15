import Foundation

/// Result of checking if content is a duplicate
enum DeduplicationResult {
    /// Content is new, should be saved with the given hash
    case newContent(hash: String)
    /// Content is a duplicate of an existing item with the given hash
    case duplicate(hash: String)
}

/// Handles deduplication of clipboard items using SHA256 hashing
actor ClipboardDeduplicator {
    private let storage: StorageEngineProtocol

    init(storage: StorageEngineProtocol) {
        self.storage = storage
    }

    /// Check if content already exists in storage
    /// Returns whether it's new or a duplicate, along with the content hash
    func checkContent(content: String, imageData: Data? = nil) async -> DeduplicationResult {
        let hash: String

        // Generate hash based on content type
        if let imageData = imageData {
            hash = SHA256Hasher.hash(data: imageData)
        } else {
            hash = SHA256Hasher.hash(string: content)
        }

        // Check if item with this hash already exists
        do {
            let exists = try await storage.itemExists(withHash: hash)
            return exists ? .duplicate(hash: hash) : .newContent(hash: hash)
        } catch {
            print("Error checking for duplicate: \(error)")
            // On error, treat as new content (better to have duplicates than lose data)
            return .newContent(hash: hash)
        }
    }

    /// Legacy method for backward compatibility
    /// Returns the hash to use if item should be saved, nil if duplicate
    func shouldSave(content: String, imageData: Data? = nil) async -> String? {
        let result = await checkContent(content: content, imageData: imageData)
        switch result {
        case .newContent(let hash):
            return hash
        case .duplicate:
            return nil
        }
    }
}
