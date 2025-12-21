import Foundation
import SQLite3

/// Handles database migrations between schema versions
/// This class contains all v1-specific knowledge for migration purposes
enum DatabaseMigrator {

    // MARK: - V1 to V2 Migration

    /// Migrate database from schema v1 to v2
    /// - Parameters:
    ///   - db: The SQLite database pointer
    ///   - blobDirectory: Directory containing v1 blob files (images)
    /// - Returns: Number of items migrated successfully
    @discardableResult
    static func migrateV1ToV2(db: OpaquePointer?, blobDirectory: URL) throws -> Int {
        guard let db = db else {
            throw MigrationError.databaseNotOpen
        }

        print("📦 Starting migration from v1 to v2...")

        // 1. Create new table with v2 schema
        let createV2Table = """
            CREATE TABLE IF NOT EXISTS items_v2 (
                id TEXT PRIMARY KEY,
                summary TEXT NOT NULL,
                content_type TEXT NOT NULL,
                content_hash TEXT NOT NULL UNIQUE,
                timestamp INTEGER NOT NULL,
                source_app TEXT,
                content BLOB,
                is_favorite INTEGER DEFAULT 0,
                preview TEXT
            );
            """
        try execute(db: db, sql: createV2Table)

        // 2. Read all items from v1 table
        let selectV1 = """
            SELECT id, content, content_type, content_hash, timestamp, source_app, blob_path, is_favorite
            FROM items;
            """

        var selectStatement: OpaquePointer?
        defer { sqlite3_finalize(selectStatement) }

        guard sqlite3_prepare_v2(db, selectV1, -1, &selectStatement, nil) == SQLITE_OK else {
            throw MigrationError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        // 3. Migrate each item
        var migratedCount = 0
        var failedCount = 0

        while sqlite3_step(selectStatement) == SQLITE_ROW {
            do {
                try migrateRow(
                    db: db,
                    statement: selectStatement,
                    blobDirectory: blobDirectory
                )
                migratedCount += 1
            } catch {
                failedCount += 1
                let itemId = sqlite3_column_text(selectStatement, 0).map { String(cString: $0) } ?? "unknown"
                print("⚠️ Failed to migrate item \(itemId): \(error.localizedDescription)")
            }
        }

        // 4. Swap tables
        try execute(db: db, sql: "DROP TABLE items;")
        try execute(db: db, sql: "ALTER TABLE items_v2 RENAME TO items;")

        // 5. Recreate indexes
        try execute(db: db, sql: "CREATE INDEX IF NOT EXISTS idx_timestamp ON items(timestamp DESC);")
        try execute(db: db, sql: "CREATE INDEX IF NOT EXISTS idx_content_hash ON items(content_hash);")
        try execute(db: db, sql: "CREATE INDEX IF NOT EXISTS idx_favorite ON items(is_favorite DESC, timestamp DESC);")

        // 6. Update schema version (delete old, insert new since version is primary key)
        try execute(db: db, sql: "DELETE FROM schema_version;")
        try execute(db: db, sql: "INSERT INTO schema_version (version) VALUES (2);")

        // 7. Delete old blob directory
        if FileManager.default.fileExists(atPath: blobDirectory.path) {
            do {
                try FileManager.default.removeItem(at: blobDirectory)
                print("🗑️ Deleted old blob directory")
            } catch {
                print("⚠️ Failed to delete blob directory: \(error.localizedDescription)")
            }
        }

        print("✅ Migration complete: \(migratedCount) items migrated, \(failedCount) failed")
        return migratedCount
    }

    // MARK: - Private Helpers

    /// Migrate a single row from v1 to v2 format
    private static func migrateRow(
        db: OpaquePointer,
        statement: OpaquePointer?,
        blobDirectory: URL
    ) throws {
        guard let statement = statement else { return }

        // Extract v1 columns
        guard let idString = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
              let content = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
              let contentTypeRaw = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
              let contentHash = sqlite3_column_text(statement, 3).map({ String(cString: $0) }) else {
            throw MigrationError.invalidRow
        }

        let timestamp = sqlite3_column_int64(statement, 4)
        let sourceApp = sqlite3_column_text(statement, 5).map { String(cString: $0) }
        let blobPath = sqlite3_column_text(statement, 6).map { String(cString: $0) }
        let isFavorite = sqlite3_column_int(statement, 7) == 1

        // Determine blob content and preview based on content type
        var blobContent: Data? = nil
        var preview: String? = nil

        if contentTypeRaw == "image", let path = blobPath {
            // Load image from blob file
            let blobURL = blobDirectory.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: blobURL.path) {
                blobContent = try Data(contentsOf: blobURL)
            }
            preview = "[Image]"
        } else {
            // Text/URL/fileURL: store content as UTF-8 blob
            blobContent = content.data(using: .utf8)
            // Compute preview (first 100 chars, newlines replaced with spaces)
            let cleaned = content.replacingOccurrences(of: "\n", with: " ")
            if cleaned.count > 100 {
                preview = String(cleaned.prefix(100)) + "…"
            } else {
                preview = cleaned
            }
        }

        // Insert into v2 table
        let insertSQL = """
            INSERT INTO items_v2 (id, summary, content_type, content_hash, timestamp, source_app, content, is_favorite, preview)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

        var insertStatement: OpaquePointer?
        defer { sqlite3_finalize(insertStatement) }

        guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK else {
            throw MigrationError.insertFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        sqlite3_bind_text(insertStatement, 1, (idString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 2, (content as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 3, (contentTypeRaw as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 4, (contentHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(insertStatement, 5, timestamp)

        if let sourceApp = sourceApp {
            sqlite3_bind_text(insertStatement, 6, (sourceApp as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(insertStatement, 6)
        }

        if let blob = blobContent {
            _ = blob.withUnsafeBytes { bytes in
                sqlite3_bind_blob(insertStatement, 7, bytes.baseAddress, Int32(blob.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(insertStatement, 7)
        }

        sqlite3_bind_int(insertStatement, 8, isFavorite ? 1 : 0)

        if let preview = preview {
            sqlite3_bind_text(insertStatement, 9, (preview as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(insertStatement, 9)
        }

        guard sqlite3_step(insertStatement) == SQLITE_DONE else {
            throw MigrationError.insertFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private static func execute(db: OpaquePointer, sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        defer { sqlite3_free(errorMessage) }

        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage != nil ? String(cString: errorMessage!) : "Unknown error"
            throw MigrationError.executeFailed(message: message)
        }
    }
}

// MARK: - Migration Errors

enum MigrationError: Error, LocalizedError {
    case databaseNotOpen
    case queryFailed(message: String)
    case invalidRow
    case insertFailed(message: String)
    case executeFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "Database is not open"
        case .queryFailed(let msg):
            return "Query failed: \(msg)"
        case .invalidRow:
            return "Invalid row data"
        case .insertFailed(let msg):
            return "Insert failed: \(msg)"
        case .executeFailed(let msg):
            return "Execute failed: \(msg)"
        }
    }
}
