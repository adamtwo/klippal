import Foundation

/// Database schema definitions and migrations
enum DatabaseSchema {
    /// Current schema version
    static let currentVersion = 1

    /// SQL to create the items table
    static let createItemsTable = """
        CREATE TABLE IF NOT EXISTS items (
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

    /// SQL to create indexes for performance
    static let createIndexes = [
        "CREATE INDEX IF NOT EXISTS idx_timestamp ON items(timestamp DESC);",
        "CREATE INDEX IF NOT EXISTS idx_content_hash ON items(content_hash);",
        "CREATE INDEX IF NOT EXISTS idx_favorite ON items(is_favorite DESC, timestamp DESC);"
    ]

    /// SQL to create the schema_version table
    static let createVersionTable = """
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY
        );
        """

    /// Get initial setup SQL statements (for new databases)
    static var initialSetupStatements: [String] {
        return [createItemsTable, createVersionTable] + createIndexes
    }

    // MARK: - Migrations

    /// A database migration from one version to the next
    struct Migration {
        let fromVersion: Int
        let toVersion: Int
        let statements: [String]
    }

    /// All available migrations, ordered by version
    /// Each migration upgrades from `fromVersion` to `toVersion`
    ///
    /// To add a new migration:
    /// 1. Increment `currentVersion` above
    /// 2. Add a new Migration entry here with the ALTER TABLE or other SQL statements
    /// 3. Add tests in DatabaseMigrationTests.swift
    ///
    /// Example for adding a new column in version 2:
    /// ```
    /// Migration(
    ///     fromVersion: 1,
    ///     toVersion: 2,
    ///     statements: [
    ///         "ALTER TABLE items ADD COLUMN pinned_at INTEGER;",
    ///         "CREATE INDEX IF NOT EXISTS idx_pinned_at ON items(pinned_at DESC);"
    ///     ]
    /// )
    /// ```
    static let migrations: [Migration] = [
        // Future migrations go here
    ]

    /// Get migrations needed to upgrade from a given version to current
    /// - Parameter fromVersion: The current database version
    /// - Returns: Array of migrations to apply, in order
    static func migrationsNeeded(from fromVersion: Int) -> [Migration] {
        return migrations.filter { $0.fromVersion >= fromVersion && $0.toVersion <= currentVersion }
            .sorted { $0.fromVersion < $1.fromVersion }
    }

    /// SQL to get current schema version
    static let getVersion = "SELECT version FROM schema_version LIMIT 1;"

    /// SQL to update schema version
    static func setVersion(_ version: Int) -> String {
        return "INSERT OR REPLACE INTO schema_version (version) VALUES (\(version));"
    }
}
