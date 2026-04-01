import type { Env, TokenPayload } from '../types';

const encoder = new TextEncoder();

function base64UrlEncode(input: ArrayBuffer | string): string {
  const bytes = typeof input === 'string' ? encoder.encode(input) : new Uint8Array(input);
  const base64 = btoa(String.fromCharCode(...bytes));
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecode(input: string): string {
  const base64 = input.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
  return atob(padded);
}

async function sign(data: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(data));
  return base64UrlEncode(signature);
}

export async function issueToken(payload: TokenPayload, env: Env): Promise<string> {
  const header = base64UrlEncode(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = base64UrlEncode(JSON.stringify(payload));
  const content = `${header}.${body}`;
  const signature = await sign(content, env.JWT_SECRET);
  return `${content}.${signature}`;
}

export async function verifyToken(token: string, env: Env): Promise<TokenPayload | null> {
  const [header, body, signature] = token.split('.');
  if (!header || !body || !signature) return null;

  const content = `${header}.${body}`;
  const expected = await sign(content, env.JWT_SECRET);
  if (expected !== signature) return null;

  try {
    const payload = JSON.parse(base64UrlDecode(body)) as TokenPayload;
    if (payload.exp <= Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch {
    return null;
  }
}
