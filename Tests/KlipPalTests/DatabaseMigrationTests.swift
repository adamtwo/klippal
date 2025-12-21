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

    // MARK: - V1 to V2 Migration Tests

    func testMigrateV1ToV2WithTextItems() async throws {
        // 1. Create a v1 database manually
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("klippal.db").path
        let blobDir = tempDir.appendingPathComponent("blobs")
        try FileManager.default.createDirectory(at: blobDir, withIntermediateDirectories: true)

        // Open database and create v1 schema
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbPath, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        // Create v1 tables
        let createV1Items = """
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
        let createVersionTable = "CREATE TABLE schema_version (version INTEGER PRIMARY KEY);"
        XCTAssertEqual(sqlite3_exec(db, createV1Items, nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, createVersionTable, nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO schema_version (version) VALUES (1);", nil, nil, nil), SQLITE_OK)

        // Insert v1 test data
        let testUUID = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        let insertSQL = """
            INSERT INTO items (id, content, content_type, content_hash, timestamp, source_app, blob_path, is_favorite)
            VALUES ('\(testUUID)', 'Hello World', 'text', 'hash123', \(timestamp), 'TestApp', NULL, 0);
            """
        XCTAssertEqual(sqlite3_exec(db, insertSQL, nil, nil, nil), SQLITE_OK)

        // 2. Run migration
        let migratedCount = try DatabaseMigrator.migrateV1ToV2(db: db, blobDirectory: blobDir)
        XCTAssertEqual(migratedCount, 1)

        // 3. Verify v2 schema exists with correct data
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT id, summary, content_type, content_hash, preview FROM items WHERE id = '\(testUUID)';", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)

        let summary = String(cString: sqlite3_column_text(stmt, 1))
        let contentType = String(cString: sqlite3_column_text(stmt, 2))
        let preview = String(cString: sqlite3_column_text(stmt, 4))

        XCTAssertEqual(summary, "Hello World")
        XCTAssertEqual(contentType, "text")
        XCTAssertEqual(preview, "Hello World")

        sqlite3_finalize(stmt)

        // 4. Verify schema version is now 2
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT version FROM schema_version;", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(stmt, 0), 2)
        sqlite3_finalize(stmt)
    }

    func testMigrateV1ToV2WithImageItems() async throws {
        // 1. Create a v1 database with an image item
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("klippal.db").path
        let blobDir = tempDir.appendingPathComponent("blobs")
        try FileManager.default.createDirectory(at: blobDir, withIntermediateDirectories: true)

        // Create a fake image blob file
        let imageHash = "imagehash123"
        let blobFilename = "\(imageHash).png"
        let blobPath = blobDir.appendingPathComponent(blobFilename)
        let fakeImageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
        try fakeImageData.write(to: blobPath)

        // Open database and create v1 schema
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbPath, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let createV1Items = """
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
        let createVersionTable = "CREATE TABLE schema_version (version INTEGER PRIMARY KEY);"
        XCTAssertEqual(sqlite3_exec(db, createV1Items, nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, createVersionTable, nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO schema_version (version) VALUES (1);", nil, nil, nil), SQLITE_OK)

        // Insert v1 image item
        let testUUID = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        let insertSQL = """
            INSERT INTO items (id, content, content_type, content_hash, timestamp, source_app, blob_path, is_favorite)
            VALUES ('\(testUUID)', '[Image]', 'image', '\(imageHash)', \(timestamp), 'Screenshot', '\(blobFilename)', 1);
            """
        XCTAssertEqual(sqlite3_exec(db, insertSQL, nil, nil, nil), SQLITE_OK)

        // 2. Run migration
        let migratedCount = try DatabaseMigrator.migrateV1ToV2(db: db, blobDirectory: blobDir)
        XCTAssertEqual(migratedCount, 1)

        // 3. Verify image blob was migrated inline
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT id, summary, content_type, content, preview, is_favorite FROM items WHERE id = '\(testUUID)';", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)

        let contentType = String(cString: sqlite3_column_text(stmt, 2))
        let blobSize = sqlite3_column_bytes(stmt, 3)
        let preview = String(cString: sqlite3_column_text(stmt, 4))
        let isFavorite = sqlite3_column_int(stmt, 5)

        XCTAssertEqual(contentType, "image")
        XCTAssertEqual(blobSize, 4) // PNG magic bytes
        XCTAssertEqual(preview, "[Image]")
        XCTAssertEqual(isFavorite, 1)

        sqlite3_finalize(stmt)

        // 4. Verify blob directory was deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: blobDir.path))
    }

    func testMigrateV1ToV2SkipsItemsWithMissingBlobFile() async throws {
        // 1. Create a v1 database with an image that has no blob file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("klippal.db").path
        let blobDir = tempDir.appendingPathComponent("blobs")
        try FileManager.default.createDirectory(at: blobDir, withIntermediateDirectories: true)

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbPath, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let createV1Items = """
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
        let createVersionTable = "CREATE TABLE schema_version (version INTEGER PRIMARY KEY);"
        XCTAssertEqual(sqlite3_exec(db, createV1Items, nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, createVersionTable, nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO schema_version (version) VALUES (1);", nil, nil, nil), SQLITE_OK)

        // Insert image with missing blob, plus a valid text item
        let imageUUID = UUID().uuidString
        let textUUID = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)

        // Image with blob_path but file doesn't exist
        let insertImage = """
            INSERT INTO items (id, content, content_type, content_hash, timestamp, blob_path, is_favorite)
            VALUES ('\(imageUUID)', '[Image]', 'image', 'missinghash', \(timestamp), 'missing.png', 0);
            """
        // Valid text item
        let insertText = """
            INSERT INTO items (id, content, content_type, content_hash, timestamp, blob_path, is_favorite)
            VALUES ('\(textUUID)', 'Valid text', 'text', 'texthash', \(timestamp), NULL, 0);
            """

        XCTAssertEqual(sqlite3_exec(db, insertImage, nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, insertText, nil, nil, nil), SQLITE_OK)

        // 2. Run migration - should succeed despite missing blob
        let migratedCount = try DatabaseMigrator.migrateV1ToV2(db: db, blobDirectory: blobDir)

        // Image with missing blob still migrates (with nil content), text item migrates
        XCTAssertEqual(migratedCount, 2)

        // 3. Verify text item was migrated correctly
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT summary FROM items WHERE id = '\(textUUID)';", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        XCTAssertEqual(String(cString: sqlite3_column_text(stmt, 0)), "Valid text")
        sqlite3_finalize(stmt)
    }

    func testMigrateV1ToV2PreservesFavoriteStatus() async throws {
        // Create v1 database with favorited items
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("klippal.db").path
        let blobDir = tempDir.appendingPathComponent("blobs")
        try FileManager.default.createDirectory(at: blobDir, withIntermediateDirectories: true)

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbPath, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let createV1Items = """
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
        XCTAssertEqual(sqlite3_exec(db, createV1Items, nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE schema_version (version INTEGER PRIMARY KEY);", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO schema_version (version) VALUES (1);", nil, nil, nil), SQLITE_OK)

        let favUUID = UUID().uuidString
        let notFavUUID = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)

        XCTAssertEqual(sqlite3_exec(db, """
            INSERT INTO items (id, content, content_type, content_hash, timestamp, is_favorite)
            VALUES ('\(favUUID)', 'Favorite', 'text', 'fav1', \(timestamp), 1);
            """, nil, nil, nil), SQLITE_OK)

        XCTAssertEqual(sqlite3_exec(db, """
            INSERT INTO items (id, content, content_type, content_hash, timestamp, is_favorite)
            VALUES ('\(notFavUUID)', 'Not Favorite', 'text', 'nofav1', \(timestamp), 0);
            """, nil, nil, nil), SQLITE_OK)

        // Run migration
        try DatabaseMigrator.migrateV1ToV2(db: db, blobDirectory: blobDir)

        // Verify favorite status preserved
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT is_favorite FROM items WHERE id = '\(favUUID)';", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(stmt, 0), 1)
        sqlite3_finalize(stmt)

        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT is_favorite FROM items WHERE id = '\(notFavUUID)';", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(stmt, 0), 0)
        sqlite3_finalize(stmt)
    }

    func testStorageEngineAutoMigratesV1Database() async throws {
        // This test verifies the full flow through SQLiteStorageEngine
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("klippal.db").path
        let blobDir = tempDir.appendingPathComponent("blobs")
        try FileManager.default.createDirectory(at: blobDir, withIntermediateDirectories: true)

        // Create v1 database directly
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbPath, &db), SQLITE_OK)

        let createV1Items = """
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
        XCTAssertEqual(sqlite3_exec(db, createV1Items, nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE schema_version (version INTEGER PRIMARY KEY);", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO schema_version (version) VALUES (1);", nil, nil, nil), SQLITE_OK)

        let testContent = "Test content for migration"
        let testHash = "testhash123"
        let timestamp = Int(Date().timeIntervalSince1970)
        XCTAssertEqual(sqlite3_exec(db, """
            INSERT INTO items (id, content, content_type, content_hash, timestamp, is_favorite)
            VALUES ('\(UUID().uuidString)', '\(testContent)', 'text', '\(testHash)', \(timestamp), 0);
            """, nil, nil, nil), SQLITE_OK)

        sqlite3_close(db)

        // Open with SQLiteStorageEngine - should auto-migrate
        let storage = try await SQLiteStorageEngine(dbPath: dbPath)

        // Verify data is accessible via v2 API
        let items = try await storage.fetchItems(limit: nil, favoriteOnly: false)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, testContent)
        XCTAssertEqual(items.first?.contentHash, testHash)
    }

}
