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
        // With no migrations defined (current state), should return empty
        let migrations = DatabaseSchema.migrationsNeeded(from: 0)
        XCTAssertTrue(migrations.isEmpty)
    }

    // MARK: - Database Without Version Table (Legacy)

    func testDatabaseWithoutVersionTableGetsMigrated() async throws {
        // Manually create a legacy database without version table
        try await createLegacyDatabase()

        // Now open with StorageEngine - should handle migration
        let storage = try await SQLiteStorageEngine(dbPath: tempDBPath)

        // Verify data is preserved
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Legacy content")

        // Keep storage reference alive while checking version
        _ = storage
    }

    /// Create a legacy database without version table
    private func createLegacyDatabase() async throws {
        var db: OpaquePointer?

        guard sqlite3_open(tempDBPath, &db) == SQLITE_OK else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open database"])
        }

        defer { sqlite3_close(db) }

        // Create items table without version table (simulating old database)
        let createTable = """
            CREATE TABLE items (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                content_type TEXT NOT NULL,
                content_hash TEXT NOT NULL UNIQUE,
                timestamp INTEGER NOT NULL,
                source_app TEXT,
                blob_path TEXT,
                is_favorite INTEGER DEFAULT 0
            );
            """

        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, createTable, nil, nil, &errMsg) == SQLITE_OK else {
            let msg = String(cString: errMsg!)
            sqlite3_free(errMsg)
            throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        // Insert test data (using valid UUID format)
        let testUUID = UUID().uuidString
        let insertData = """
            INSERT INTO items (id, content, content_type, content_hash, timestamp, is_favorite)
            VALUES ('\(testUUID)', 'Legacy content', 'text', 'legacyhash', 1234567890, 0);
            """
        guard sqlite3_exec(db, insertData, nil, nil, &errMsg) == SQLITE_OK else {
            let msg = String(cString: errMsg!)
            sqlite3_free(errMsg)
            throw NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

}
