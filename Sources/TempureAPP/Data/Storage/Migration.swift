import Foundation

enum Migration {
    static let createBBTRecordsTable = """
    CREATE TABLE IF NOT EXISTS bbt_records (
      date TEXT PRIMARY KEY,
      temperature REAL NOT NULL,
      updated_at INTEGER NOT NULL
    );
    """

    static let createUpdatedAtIndex = """
    CREATE INDEX IF NOT EXISTS idx_bbt_updated_at
    ON bbt_records(updated_at);
    """
}
