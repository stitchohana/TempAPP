export interface Env {
  DB: D1Database;
  OTP_KV: KVNamespace;
  RATE_KV: KVNamespace;
  JWT_SECRET: string;
  OTP_SALT: string;
  APP_ENV?: string;
}

export interface TokenPayload {
  sub: string;
  account: string;
  type: 'access' | 'refresh';
  exp: number;
}

export interface AuthContext {
  userId: string;
  account: string;
}
