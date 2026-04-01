# Tempure Cloudflare Worker Backend

这是 TempureAPP 的后端起步实现，提供：

- `POST /auth/send-code`
- `POST /auth/verify-code`
- `POST /auth/refresh`
- `POST /records/batch-upsert`
- `GET /health`

## 快速开始

1. 安装 Wrangler（本地环境）
2. 按 `wrangler.toml` 配置 D1/KV 绑定
3. 执行 D1 初始化：

```bash
wrangler d1 execute tempure-db --file=src/db/schema.sql
```

4. 配置 secrets：

```bash
wrangler secret put JWT_SECRET
wrangler secret put OTP_SALT
```

5. 本地运行：

```bash
wrangler dev
```

> `APP_ENV=dev` 时 `send-code` 会返回 `debugCode` 便于联调。
