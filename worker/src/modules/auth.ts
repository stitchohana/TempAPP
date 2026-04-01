import { badRequest, json, unauthorized } from '../lib/response';
import { issueToken, verifyToken } from '../lib/jwt';
import type { Env, TokenPayload } from '../types';

interface SendCodeBody {
  email?: string;
}

interface VerifyCodeBody {
  email?: string;
  code?: string;
}

interface RefreshBody {
  refreshToken?: string;
}

const OTP_TTL_SECONDS = 300;

function emailKey(email: string): string {
  return email.trim().toLowerCase();
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

async function hashOtp(email: string, code: string, env: Env): Promise<string> {
  const text = `${email}|${code}|${env.OTP_SALT}`;
  const data = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest)).map((x) => x.toString(16).padStart(2, '0')).join('');
}

function makeOtpCode(): string {
  return `${Math.floor(Math.random() * 900000) + 100000}`;
}

export async function sendCode(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => null)) as SendCodeBody | null;
  const rawEmail = body?.email?.trim().toLowerCase();
  if (!rawEmail || !isValidEmail(rawEmail)) {
    return badRequest('Invalid email');
  }

  const rateKey = `rate:${emailKey(rawEmail)}`;
  const current = Number((await env.RATE_KV.get(rateKey)) ?? '0');
  if (current >= 5) {
    return json({ error: 'Too many attempts, retry later' }, { status: 429 });
  }
  await env.RATE_KV.put(rateKey, String(current + 1), { expirationTtl: 300 });

  const code = makeOtpCode();
  const otpHash = await hashOtp(rawEmail, code, env);
  await env.OTP_KV.put(`otp:${emailKey(rawEmail)}`, otpHash, { expirationTtl: OTP_TTL_SECONDS });

  const response: Record<string, unknown> = { ok: true };
  if (env.APP_ENV === 'dev') response.debugCode = code;
  return json(response);
}

export async function verifyCodeHandler(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => null)) as VerifyCodeBody | null;
  const rawEmail = body?.email?.trim().toLowerCase();
  const rawCode = body?.code?.trim();
  if (!rawEmail || !rawCode) return badRequest('email/code required');

  const stored = await env.OTP_KV.get(`otp:${emailKey(rawEmail)}`);
  if (!stored) return unauthorized('Code expired');

  const hash = await hashOtp(rawEmail, rawCode, env);
  if (hash !== stored) return unauthorized('Code mismatch');

  const now = Date.now();
  const userId = crypto.randomUUID();

  await env.DB.prepare(
    `INSERT INTO users (id, email, created_at, updated_at)
     VALUES (?1, ?2, ?3, ?4)
     ON CONFLICT(email) DO UPDATE SET updated_at=excluded.updated_at`
  ).bind(userId, rawEmail, now, now).run();

  const user = await env.DB.prepare('SELECT id, email FROM users WHERE email=?1').bind(rawEmail).first<{ id: string; email: string }>();
  if (!user) return json({ error: 'Failed to resolve user' }, { status: 500 });

  await env.OTP_KV.delete(`otp:${emailKey(rawEmail)}`);

  const accessPayload: TokenPayload = {
    sub: user.id,
    email: user.email,
    type: 'access',
    exp: Math.floor(Date.now() / 1000) + 60 * 30,
  };
  const refreshPayload: TokenPayload = {
    sub: user.id,
    email: user.email,
    type: 'refresh',
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30,
  };

  const accessToken = await issueToken(accessPayload, env);
  const refreshToken = await issueToken(refreshPayload, env);

  return json({ accessToken, refreshToken, user });
}

export async function refreshToken(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => null)) as RefreshBody | null;
  const token = body?.refreshToken;
  if (!token) return badRequest('refreshToken required');

  const payload = await verifyToken(token, env);
  if (!payload || payload.type !== 'refresh') return unauthorized('Invalid refresh token');

  const next: TokenPayload = {
    sub: payload.sub,
    email: payload.email,
    type: 'access',
    exp: Math.floor(Date.now() / 1000) + 60 * 30,
  };

  const accessToken = await issueToken(next, env);
  return json({ accessToken });
}
