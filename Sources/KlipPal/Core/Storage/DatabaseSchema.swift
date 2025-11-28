import Foundation

/// Database schema definitions and migrations
enum DatabaseSchema {
    /// Current schema version
    static let currentVersion = 1

    /// SQL to create the items table
    static let createItemsTable = """
        CREATE TABLE IF NOT EXISTS items (
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

    /// Insert initial version
    static let insertInitialVersion = """
        INSERT OR REPLACE INTO schema_version (version) VALUES (1);
        """

    /// Get all setup SQL statements
    static var allSetupStatements: [String] {
        return [createItemsTable, createVersionTable, insertInitialVersion] + createIndexes
    }
}
