CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS bbt_records (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  record_date TEXT NOT NULL,
  temperature_c REAL,
  weight_kg REAL,
  tags_json TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  UNIQUE(user_id, record_date)
);

CREATE INDEX IF NOT EXISTS idx_bbt_records_user_date ON bbt_records(user_id, record_date);
CREATE INDEX IF NOT EXISTS idx_bbt_records_user_updated ON bbt_records(user_id, updated_at);
