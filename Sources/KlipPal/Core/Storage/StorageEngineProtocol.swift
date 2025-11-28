import Foundation

/// Protocol defining the storage interface for clipboard items
protocol StorageEngineProtocol: Actor {
    /// Save a clipboard item
    func save(_ item: ClipboardItem) async throws

    /// Fetch all items, optionally filtered and limited
    func fetchItems(limit: Int?, favoriteOnly: Bool) async throws -> [ClipboardItem]

    /// Fetch a specific item by ID
    func fetchItem(byId id: UUID) async throws -> ClipboardItem?

    /// Check if an item with the given hash already exists
    func itemExists(withHash hash: String) async throws -> Bool

    /// Update an existing item (e.g., to toggle favorite)
    func update(_ item: ClipboardItem) async throws

    /// Delete a specific item
    func delete(_ item: ClipboardItem) async throws

    /// Delete all items (clear history)
    func deleteAll() async throws

    /// Delete items older than the specified number of days
    func deleteOlderThan(days: Int) async throws

    /// Get total count of items
    func count() async throws -> Int

    /// Perform database maintenance (VACUUM, etc.)
    func performMaintenance() async throws
}
