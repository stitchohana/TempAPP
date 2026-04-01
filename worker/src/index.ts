import { notFound, json } from './lib/response';
import { sendCode, verifyCodeHandler, refreshToken } from './modules/auth';
import { batchUpsert } from './modules/records';
import { requireAuth } from './middleware/auth';
import type { Env } from './types';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const { pathname } = url;

    if (request.method === 'GET' && pathname === '/health') {
      return json({ ok: true, ts: Date.now() });
    }

    if (request.method === 'POST' && pathname === '/auth/send-code') {
      return sendCode(request, env);
    }

    if (request.method === 'POST' && pathname === '/auth/verify-code') {
      return verifyCodeHandler(request, env);
    }

    if (request.method === 'POST' && pathname === '/auth/refresh') {
      return refreshToken(request, env);
    }

    if (request.method === 'POST' && pathname === '/records/batch-upsert') {
      const auth = await requireAuth(request, env);
      if (auth instanceof Response) return auth;
      return batchUpsert(request, env, auth);
    }

    return notFound();
  },
};
