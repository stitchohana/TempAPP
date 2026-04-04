import { badRequest, json, unauthorized } from '../lib/response';
import { issueToken, verifyToken } from '../lib/jwt';
import type { Env, TokenPayload } from '../types';

interface RegisterBody {
  account?: string;
  password?: string;
}

interface LoginBody {
  account?: string;
  password?: string;
}

interface RefreshBody {
  refreshToken?: string;
}

interface UserRow {
  id: string;
  email: string;
  password_hash: string | null;
  password_salt: string | null;
}

const PASSWORD_MIN_LENGTH = 6;
const PASSWORD_MAX_LENGTH = 72;
// Cloudflare Workers currently caps PBKDF2 iterations at 100000.
const PBKDF2_ITERATIONS = 100000;
const PBKDF2_OUTPUT_BYTES = 32;

let schemaReadyPromise: Promise<void> | null = null;

function normalizeAccount(account: string): string {
  return account.trim().toLowerCase();
}

function isValidAccount(account: string): boolean {
  return /^[A-Za-z0-9._@-]{3,64}$/.test(account);
}

function isValidPassword(password: string): boolean {
  return password.length >= PASSWORD_MIN_LENGTH && password.length <= PASSWORD_MAX_LENGTH;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let index = 0; index < bytes.length; index += 512) {
    const chunk = bytes.subarray(index, index + 512);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const output = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    output[index] = binary.charCodeAt(index);
  }
  return output;
}

function makePasswordSalt(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return bytesToBase64(bytes);
}

function constantTimeEquals(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let index = 0; index < left.length; index += 1) {
    diff |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return diff === 0;
}

async function hashPassword(account: string, password: string, passwordSalt: string, env: Env): Promise<string> {
  const pepper = env.OTP_SALT ?? '';
  const material = `${normalizeAccount(account)}|${password}|${pepper}`;
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(material),
    'PBKDF2',
    false,
    ['deriveBits']
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      hash: 'SHA-256',
      iterations: PBKDF2_ITERATIONS,
      salt: base64ToBytes(passwordSalt),
    },
    keyMaterial,
    PBKDF2_OUTPUT_BYTES * 8
  );

  return bytesToBase64(new Uint8Array(bits));
}

async function ensureAuthColumns(env: Env): Promise<void> {
  if (!schemaReadyPromise) {
    schemaReadyPromise = (async () => {
      const result = await env.DB.prepare('PRAGMA table_info(users);').all<{ name: string }>();
      const columns = new Set((result.results ?? []).map((item) => item.name));

      if (columns.size === 0) {
        await env.DB.prepare(
          `CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT,
            password_salt TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );`
        ).run();
        columns.add('id');
        columns.add('email');
        columns.add('password_hash');
        columns.add('password_salt');
        columns.add('created_at');
        columns.add('updated_at');
      }

      if (!columns.has('password_hash')) {
        await env.DB.prepare('ALTER TABLE users ADD COLUMN password_hash TEXT;').run();
      }
      if (!columns.has('password_salt')) {
        await env.DB.prepare('ALTER TABLE users ADD COLUMN password_salt TEXT;').run();
      }
    })();
  }
  await schemaReadyPromise;
}

async function issueSession(userId: string, account: string, env: Env): Promise<Response> {
  const accessPayload: TokenPayload = {
    sub: userId,
    account,
    type: 'access',
    exp: Math.floor(Date.now() / 1000) + 60 * 30,
  };
  const refreshPayload: TokenPayload = {
    sub: userId,
    account,
    type: 'refresh',
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30,
  };

  const accessToken = await issueToken(accessPayload, env);
  const refreshToken = await issueToken(refreshPayload, env);

  return json({
    accessToken,
    refreshToken,
    user: {
      id: userId,
      email: account,
    },
  });
}

export async function register(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => null)) as RegisterBody | null;
  const account = normalizeAccount(body?.account ?? '');
  const password = body?.password ?? '';

  if (!isValidAccount(account)) {
    return badRequest('Invalid account');
  }
  if (!isValidPassword(password)) {
    return badRequest('Invalid password');
  }

  await ensureAuthColumns(env);

  const now = Date.now();
  const passwordSalt = makePasswordSalt();
  const passwordHash = await hashPassword(account, password, passwordSalt, env);
  const existing = await env.DB.prepare(
    'SELECT id, password_hash, password_salt FROM users WHERE email=?1 LIMIT 1'
  )
    .bind(account)
    .first<{ id: string; password_hash: string | null; password_salt: string | null }>();

  if (existing) {
    if (existing.password_hash && existing.password_salt) {
      return json({ error: 'Account already exists' }, { status: 409 });
    }

    await env.DB.prepare(
      `UPDATE users
       SET password_hash=?1, password_salt=?2, updated_at=?3
       WHERE id=?4`
    )
      .bind(passwordHash, passwordSalt, now, existing.id)
      .run();

    return issueSession(existing.id, account, env);
  }

  const userId = crypto.randomUUID();
  await env.DB.prepare(
    `INSERT INTO users (id, email, password_hash, password_salt, created_at, updated_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6)`
  )
    .bind(userId, account, passwordHash, passwordSalt, now, now)
    .run();

  return issueSession(userId, account, env);
}

export async function login(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => null)) as LoginBody | null;
  const account = normalizeAccount(body?.account ?? '');
  const password = body?.password ?? '';

  if (!isValidAccount(account) || !isValidPassword(password)) {
    return unauthorized('Account or password incorrect');
  }

  await ensureAuthColumns(env);

  const user = await env.DB.prepare(
    'SELECT id, email, password_hash, password_salt FROM users WHERE email=?1 LIMIT 1'
  )
    .bind(account)
    .first<UserRow>();

  if (!user) {
    return unauthorized('Account or password incorrect');
  }
  if (!user.password_hash || !user.password_salt) {
    return unauthorized('Account has no password, please register again');
  }

  const candidateHash = await hashPassword(account, password, user.password_salt, env);
  if (!constantTimeEquals(candidateHash, user.password_hash)) {
    return unauthorized('Account or password incorrect');
  }

  await env.DB.prepare('UPDATE users SET updated_at=?1 WHERE id=?2').bind(Date.now(), user.id).run();
  return issueSession(user.id, user.email, env);
}

export async function refreshToken(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => null)) as RefreshBody | null;
  const token = body?.refreshToken;
  if (!token) return badRequest('refreshToken required');

  const payload = await verifyToken(token, env);
  if (!payload || payload.type !== 'refresh') return unauthorized('Invalid refresh token');

  const next: TokenPayload = {
    sub: payload.sub,
    account: payload.account,
    type: 'access',
    exp: Math.floor(Date.now() / 1000) + 60 * 30,
  };

  const accessToken = await issueToken(next, env);
  return json({ accessToken });
}
