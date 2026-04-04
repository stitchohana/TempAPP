import { badRequest, json } from '../lib/response';
import type { AuthContext, Env } from '../types';

interface BatchRecord {
  recordDate?: string;
  temperatureC?: number | null;
  weightKg?: number | null;
  tags?: unknown;
  updatedAt?: number;
}

interface BatchUpsertBody {
  records?: BatchRecord[];
}

let recordsSchemaReadyPromise: Promise<void> | null = null;

interface DbRecordRow {
  record_date: string;
  temperature_c: number | null;
  weight_kg: number | null;
  tags_json: string | null;
  updated_at: number;
}

interface TagPayload {
  hasIntercourse: boolean;
  intercourseTime?: string | null;
  hasMenstruation: boolean;
  menstrualFlow?: string | null;
  menstrualColor?: string | null;
  hasDysmenorrhea: boolean;
}

function isDateKey(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}

async function ensureRecordsSchema(env: Env): Promise<void> {
  if (!recordsSchemaReadyPromise) {
    recordsSchemaReadyPromise = (async () => {
      await env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS bbt_records (
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
        );`
      ).run();
      await env.DB.prepare(
        'CREATE INDEX IF NOT EXISTS idx_bbt_records_user_date ON bbt_records(user_id, record_date);'
      ).run();
      await env.DB.prepare(
        'CREATE INDEX IF NOT EXISTS idx_bbt_records_user_updated ON bbt_records(user_id, updated_at);'
      ).run();
    })();
  }
  await recordsSchemaReadyPromise;
}

export async function batchUpsert(request: Request, env: Env, auth: AuthContext): Promise<Response> {
  await ensureRecordsSchema(env);

  const body = (await request.json().catch(() => null)) as BatchUpsertBody | null;
  const records = body?.records;
  if (!records || !Array.isArray(records)) {
    return badRequest('records required');
  }
  if (records.length === 0) {
    return json({ ok: true, count: 0 });
  }

  const now = Date.now();
  const statements: D1PreparedStatement[] = [];

  for (const item of records) {
    if (!item.recordDate || !isDateKey(item.recordDate)) {
      return badRequest('invalid recordDate');
    }

    const id = `${auth.userId}:${item.recordDate}`;
    const tagsJson = item.tags ? JSON.stringify(item.tags) : null;
    const updatedAt = item.updatedAt ?? now;

    const stmt = env.DB.prepare(
      `INSERT INTO bbt_records (
        id, user_id, record_date, temperature_c, weight_kg, tags_json, version, updated_at, deleted_at
      ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, ?7, NULL)
      ON CONFLICT(user_id, record_date)
      DO UPDATE SET
        temperature_c=excluded.temperature_c,
        weight_kg=excluded.weight_kg,
        tags_json=excluded.tags_json,
        version=bbt_records.version + 1,
        updated_at=excluded.updated_at,
        deleted_at=NULL`
    ).bind(id, auth.userId, item.recordDate, item.temperatureC ?? null, item.weightKg ?? null, tagsJson, updatedAt);

    statements.push(stmt);
  }

  await env.DB.batch(statements);
  return json({ ok: true, count: records.length });
}

function parseTags(raw: string | null): TagPayload | null {
  if (!raw) return null;
  try {
    const value = JSON.parse(raw) as TagPayload;
    if (typeof value !== 'object' || value === null) return null;
    if (typeof value.hasIntercourse !== 'boolean') return null;
    if (typeof value.hasMenstruation !== 'boolean') return null;
    if (typeof value.hasDysmenorrhea !== 'boolean') return null;
    return value;
  } catch {
    return null;
  }
}

export async function fetchAllRecords(env: Env, auth: AuthContext): Promise<Response> {
  await ensureRecordsSchema(env);

  const result = await env.DB.prepare(
    `SELECT record_date, temperature_c, weight_kg, tags_json, updated_at
     FROM bbt_records
     WHERE user_id=?1
     ORDER BY record_date ASC`
  )
    .bind(auth.userId)
    .all<DbRecordRow>();

  const records = (result.results ?? []).map((row) => ({
    recordDate: row.record_date,
    temperatureC: row.temperature_c,
    weightKg: row.weight_kg,
    tags: parseTags(row.tags_json),
    updatedAt: row.updated_at,
  }));

  return json({ records });
}
