# Cloudflare Worker 部署指南（Tempure 后端）

本文档说明如何把 `worker/` 目录下的后端发布到 Cloudflare。

## 1. 前置条件

- 已安装 Node.js 18+
- 已安装 Wrangler CLI
- 已登录 Cloudflare 账号（`wrangler login`）

## 2. 创建云资源

### 2.1 创建 D1

```bash
wrangler d1 create tempure-db
```

执行后会返回 `database_id`，把它填入 `worker/wrangler.toml` 的 `[[d1_databases]]` 中。

### 2.2 创建 KV（OTP 与限流）

```bash
wrangler kv namespace create OTP_KV
wrangler kv namespace create RATE_KV
```

将返回的 `id` 填入 `worker/wrangler.toml` 的 `[[kv_namespaces]]`。

## 3. 初始化数据库结构

在 `worker/` 目录执行：

```bash
wrangler d1 execute tempure-db --file=src/db/schema.sql
```

该脚本会创建 `users` 和 `bbt_records` 等表结构。

## 4. 配置密钥与环境变量

在 `worker/` 目录执行：

```bash
wrangler secret put JWT_SECRET
wrangler secret put OTP_SALT
```

可选：在 `wrangler.toml` 中设置 `APP_ENV = "dev"` 用于联调（`send-code` 会返回 `debugCode`）。

## 5. 本地联调

```bash
wrangler dev
```

检查健康接口：

```bash
curl http://127.0.0.1:8787/health
```

## 6. 发布到生产

```bash
wrangler deploy
```

发布成功后会得到 Worker URL，例如：

```txt
https://tempure-worker.<your-subdomain>.workers.dev
```

## 7. App 端接入

将 iOS 端环境变量 `WORKER_BASE_URL` 指向上面的 Worker URL。

示例：

```txt
WORKER_BASE_URL=https://tempure-worker.<your-subdomain>.workers.dev
```

`AppContainer.bootstrap()` 会在该变量存在时自动切到 `WorkerAuthRepository`。

## 8. 回滚与排查

- 快速回滚：重新 `wrangler deploy` 到上一个稳定 commit。
- 鉴权失败：检查 `JWT_SECRET` 是否与当前环境一致。
- OTP 不生效：检查 `OTP_KV` 绑定、TTL、以及 `APP_ENV` 配置。
- 数据写入失败：检查 D1 绑定和 `schema.sql` 是否已执行。
