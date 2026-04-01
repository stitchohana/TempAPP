import { unauthorized } from '../lib/response';
import { verifyToken } from '../lib/jwt';
import type { AuthContext, Env } from '../types';

export async function requireAuth(request: Request, env: Env): Promise<AuthContext | Response> {
  const auth = request.headers.get('authorization') ?? '';
  const prefix = 'Bearer ';
  if (!auth.startsWith(prefix)) return unauthorized();

  const token = auth.slice(prefix.length).trim();
  const payload = await verifyToken(token, env);
  if (!payload || payload.type !== 'access') return unauthorized('Invalid token');

  return {
    userId: payload.sub,
    email: payload.email,
  };
}
