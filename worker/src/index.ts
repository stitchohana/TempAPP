import { notFound, json } from './lib/response';
import { register, login, refreshToken } from './modules/auth';
import { batchUpsert, fetchAllRecords } from './modules/records';
import { requireAuth } from './middleware/auth';
import type { Env } from './types';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      const { pathname } = url;

      if (request.method === 'GET' && pathname === '/health') {
        return json({ ok: true, ts: Date.now() });
      }

      if (request.method === 'POST' && pathname === '/auth/register') {
        return await register(request, env);
      }

      if (request.method === 'POST' && pathname === '/auth/login') {
        return await login(request, env);
      }

      if (request.method === 'POST' && pathname === '/auth/refresh') {
        return await refreshToken(request, env);
      }

      if (request.method === 'POST' && pathname === '/records/batch-upsert') {
        const auth = await requireAuth(request, env);
        if (auth instanceof Response) return auth;
        return await batchUpsert(request, env, auth);
      }

      if (request.method === 'GET' && pathname === '/records/all') {
        const auth = await requireAuth(request, env);
        if (auth instanceof Response) return auth;
        return await fetchAllRecords(env, auth);
      }

      return notFound();
    } catch (error) {
      console.error('Unhandled worker error', error);
      const detail = error instanceof Error ? error.message : String(error);

      if (env.APP_ENV === 'dev') {
        return json({ error: 'Internal server error', detail }, { status: 500 });
      }
      return json({ error: 'Internal server error' }, { status: 500 });
    }
  },
};
