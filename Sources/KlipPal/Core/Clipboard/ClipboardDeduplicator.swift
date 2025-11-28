import Foundation

/// Handles deduplication of clipboard items using SHA256 hashing
actor ClipboardDeduplicator {
    private let storage: StorageEngineProtocol

    init(storage: StorageEngineProtocol) {
        self.storage = storage
    }

    /// Check if content should be saved (not a duplicate)
    /// Returns the hash to use if item should be saved, nil if duplicate
    func shouldSave(content: String, imageData: Data? = nil) async -> String? {
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
            return exists ? nil : hash
        } catch {
            print("Error checking for duplicate: \(error)")
            // On error, allow saving (better to have duplicates than lose data)
            return hash
        }
    }
}
