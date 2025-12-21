import XCTest
import SQLite3
@testable import KlipPal

final class DatabaseMigrationTests: XCTestCase {
    var tempDBPath: String!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_migration_\(UUID().uuidString).db").path
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDBPath)
    }

    // MARK: - Schema Version Tests

    func testNewDatabaseInitializesSuccessfully() async throws {
        // Create a new database - should not throw
        let storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Verify we can perform operations (proves schema is set up)
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertTrue(items.isEmpty)

        // Keep storage alive
        _ = storage
    }

    func testExistingDatabaseWithDataIsPreserved() async throws {
        // Create initial database
        let storage1 = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Save an item
        let item = ClipboardItem(
            content: "Test content",
            contentType: .text,
            contentHash: "hash123"
        )
        try await storage1.save(item)

        // Re-open the database (simulates app restart)
        let storage2 = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Verify data is preserved
        let items = try await storage2.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Test content")
    }

    // MARK: - Migration Logic Tests

    func testMigrationsNeededReturnsEmptyForCurrentVersion() {
        let migrations = DatabaseSchema.migrationsNeeded(from: DatabaseSchema.currentVersion)
        XCTAssertTrue(migrations.isEmpty)
    }

    func testMigrationsNeededReturnsEmptyWhenNoMigrationsDefined() {
        // With no migrations defined, should return empty
        let migrations = DatabaseSchema.migrationsNeeded(from: 0)
        XCTAssertTrue(migrations.isEmpty)
    }

}
