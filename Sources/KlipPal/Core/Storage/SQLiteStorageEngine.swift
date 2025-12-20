import Foundation
import SQLite3

/// SQLite-based storage engine for clipboard items
/// Thread-safe via Swift actor isolation
actor SQLiteStorageEngine: StorageEngineProtocol {
    private var db: OpaquePointer?
    private let dbPath: String

    init(dbPath: String) async throws {
        self.dbPath = dbPath

        // Create directory if needed
        let dbURL = URL(fileURLWithPath: dbPath)
        let directory = dbURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Open database
        var tempDB: OpaquePointer?
        guard sqlite3_open(dbPath, &tempDB) == SQLITE_OK else {
            throw StorageError.databaseOpenFailed(message: String(cString: sqlite3_errmsg(tempDB)))
        }
        self.db = tempDB

        // Set up schema
        try await setupSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema Setup and Migrations

    private func setupSchema() async throws {
        // Create base tables if they don't exist
        for sql in DatabaseSchema.initialSetupStatements {
            try await execute(sql)
        }

        // Check current version and run migrations if needed
        let currentVersion = try await getSchemaVersion()

        if currentVersion < DatabaseSchema.currentVersion {
            try await runMigrations(from: currentVersion)
        } else if currentVersion == 0 {
            // New database - set initial version
            try await execute(DatabaseSchema.setVersion(DatabaseSchema.currentVersion))
        }
    }

    /// Get the current schema version from the database
    private func getSchemaVersion() async throws -> Int {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, DatabaseSchema.getVersion, -1, &statement, nil) == SQLITE_OK else {
            // Table might not exist yet - return 0
            return 0
        }

        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }

        // No version found - new database
        return 0
    }

    /// Run all migrations from the given version to current
    private func runMigrations(from fromVersion: Int) async throws {
        let migrations = DatabaseSchema.migrationsNeeded(from: fromVersion)

        for migration in migrations {
            print("📦 Running migration v\(migration.fromVersion) → v\(migration.toVersion)")

            for sql in migration.statements {
                try await execute(sql)
            }

            // Update version after each successful migration
            try await execute(DatabaseSchema.setVersion(migration.toVersion))
        }

        // Ensure we're at the current version
        if migrations.isEmpty && fromVersion < DatabaseSchema.currentVersion {
            // No migrations defined but version is old - just update version
            try await execute(DatabaseSchema.setVersion(DatabaseSchema.currentVersion))
        }

        print("✅ Database migrated to v\(DatabaseSchema.currentVersion)")
    }

    // MARK: - StorageEngineProtocol Implementation

    func save(_ item: ClipboardItem) async throws {
        let sql = """
            INSERT OR REPLACE INTO items (id, content, content_type, content_hash, timestamp, source_app, blob_path, is_favorite)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        sqlite3_bind_text(statement, 1, (item.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (item.content as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, (item.contentType.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, (item.contentHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 5, Int64(item.timestamp.timeIntervalSince1970))
        if let sourceApp = item.sourceApp {
            sqlite3_bind_text(statement, 6, (sourceApp as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        if let blobPath = item.blobPath {
            sqlite3_bind_text(statement, 7, (blobPath as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 7)
        }
        sqlite3_bind_int(statement, 8, item.isFavorite ? 1 : 0)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.executeFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    func fetchItems(limit: Int? = nil, favoriteOnly: Bool = false) async throws -> [ClipboardItem] {
        var sql = "SELECT id, content, content_type, content_hash, timestamp, source_app, blob_path, is_favorite FROM items"

        if favoriteOnly {
            sql += " WHERE is_favorite = 1"
        }

        sql += " ORDER BY timestamp DESC"

        if let limit = limit {
            sql += " LIMIT \(limit)"
        }

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        var items: [ClipboardItem] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseClipboardItem(from: statement) {
                items.append(item)
            }
        }

        return items
    }

    func fetchItem(byId id: UUID) async throws -> ClipboardItem? {
        let sql = "SELECT id, content, content_type, content_hash, timestamp, source_app, blob_path, is_favorite FROM items WHERE id = ?;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) == SQLITE_ROW {
            return parseClipboardItem(from: statement)
        }

        return nil
    }

    func itemExists(withHash hash: String) async throws -> Bool {
        let sql = "SELECT COUNT(*) FROM items WHERE content_hash = ?;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (hash as NSString).utf8String, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) == SQLITE_ROW {
            let count = sqlite3_column_int(statement, 0)
            return count > 0
        }

        return false
    }

    func updateTimestamp(forHash hash: String) async throws {
        let sql = "UPDATE items SET timestamp = ? WHERE content_hash = ?;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let now = Int64(Date().timeIntervalSince1970)

        sqlite3_bind_int64(statement, 1, now)
        sqlite3_bind_text(statement, 2, (hash as NSString).utf8String, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.executeFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    func update(_ item: ClipboardItem) async throws {
        // For now, just save (which does INSERT OR REPLACE)
        try await save(item)
    }

    func delete(_ item: ClipboardItem) async throws {
        let sql = "DELETE FROM items WHERE id = ?;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (item.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.executeFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    func deleteAll() async throws {
        try await execute("DELETE FROM items;")
    }

    func deleteOlderThan(days: Int) async throws {
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        let cutoffTimestamp = Int64(cutoffDate.timeIntervalSince1970)

        let sql = "DELETE FROM items WHERE timestamp < ? AND is_favorite = 0;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_int64(statement, 1, cutoffTimestamp)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.executeFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    func count() async throws -> Int {
        let sql = "SELECT COUNT(*) FROM items;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.prepareFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }

        return 0
    }

    func performMaintenance() async throws {
        try await execute("VACUUM;")
    }

    // MARK: - Helper Methods

    private func execute(_ sql: String) async throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        defer { sqlite3_free(errorMessage) }

        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage != nil ? String(cString: errorMessage!) : "Unknown error"
            throw StorageError.executeFailed(message: message)
        }
    }

    private func parseClipboardItem(from statement: OpaquePointer?) -> ClipboardItem? {
        guard let statement = statement else { return nil }

        guard let idString = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
              let id = UUID(uuidString: idString),
              let content = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
              let contentTypeRaw = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
              let contentType = ClipboardContentType(rawValue: contentTypeRaw),
              let contentHash = sqlite3_column_text(statement, 3).map({ String(cString: $0) }) else {
            return nil
        }

        let timestampInt = sqlite3_column_int64(statement, 4)
        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampInt))

        let sourceApp = sqlite3_column_text(statement, 5).map { String(cString: $0) }
        let blobPath = sqlite3_column_text(statement, 6).map { String(cString: $0) }
        let isFavorite = sqlite3_column_int(statement, 7) == 1

        return ClipboardItem(
            id: id,
            content: content,
            contentType: contentType,
            contentHash: contentHash,
            timestamp: timestamp,
            sourceApp: sourceApp,
            blobPath: blobPath,
            isFavorite: isFavorite
        )
    }
}

// MARK: - Storage Errors

enum StorageError: Error, LocalizedError {
    case databaseOpenFailed(message: String)
    case prepareFailed(message: String)
    case executeFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let msg): return "Failed to open database: \(msg)"
        case .prepareFailed(let msg): return "Failed to prepare statement: \(msg)"
        case .executeFailed(let msg): return "Failed to execute: \(msg)"
        }
    }
}
