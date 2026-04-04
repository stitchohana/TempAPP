# Tempure Cloudflare Worker Backend

这是 TempureAPP 的后端起步实现，提供：

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /records/batch-upsert`
- `GET /records/all`
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

## 账号密码认证说明

- `register` 和 `login` 均接收 `{ account, password }`
- `account` 支持 3-64 位字母、数字、`.`、`_`、`@`、`-`
- `password` 最短 6 位

## 线上域名

- 默认接入域名：`https://234575.xyz`
