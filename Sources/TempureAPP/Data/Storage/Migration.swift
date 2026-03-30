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

    static let createDailyTagsTable = """
    CREATE TABLE IF NOT EXISTS daily_tags (
      date TEXT PRIMARY KEY,
      has_intercourse INTEGER NOT NULL DEFAULT 0,
      intercourse_time TEXT,
      has_menstruation INTEGER NOT NULL DEFAULT 0,
      menstrual_flow TEXT,
      menstrual_color TEXT,
      has_dysmenorrhea INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    );
    """

    static let createDailyTagsUpdatedAtIndex = """
    CREATE INDEX IF NOT EXISTS idx_daily_tags_updated_at
    ON daily_tags(updated_at);
    """

    static let addIntercourseTimeColumn = "ALTER TABLE daily_tags ADD COLUMN intercourse_time TEXT;"
    static let addMenstrualColorColumn = "ALTER TABLE daily_tags ADD COLUMN menstrual_color TEXT;"
    static let addHasDysmenorrheaColumn = "ALTER TABLE daily_tags ADD COLUMN has_dysmenorrhea INTEGER NOT NULL DEFAULT 0;"
}
