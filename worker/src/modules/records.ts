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

function isDateKey(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}

export async function batchUpsert(request: Request, env: Env, auth: AuthContext): Promise<Response> {
  const body = (await request.json().catch(() => null)) as BatchUpsertBody | null;
  const records = body?.records;
  if (!records || !Array.isArray(records) || records.length === 0) {
    return badRequest('records required');
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
