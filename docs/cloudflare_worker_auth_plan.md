# TempureAPP 登录与云端存储（Cloudflare Worker）方案

## 1. 项目现状与目标

基于现有代码，`TempureRootView` 启动后直接进入 `HomeView`，当前是本地优先的数据架构（SQLite）。

本次改造目标：
1. 增加「登录界面 + 会话态管理」，支持邮箱验证码登录（无密码）与 Apple 登录（二选一可分期）。
2. 在本地 SQLite 之外，新增 Cloudflare Worker 后端，保存并同步用户体温/体重/标签数据。
3. 保持离线可用：本地可写，联网后后台同步。

---

## 2. 登录界面设计（iOS / SwiftUI）

> 设计原则：最少步骤、明显反馈、与现有视觉风格（柔和配色）一致。

### 2.1 页面结构（建议）

### A. 未登录页 `LoginView`
- 顶部：Logo + 标语（例如“记录每一天的体温变化”）
- 中部：
  - 邮箱输入框
  - 「发送验证码」按钮
  - 验证码输入框（6位）
  - 「登录 / 注册」主按钮
- 底部：
  - 「使用 Apple 登录」次按钮（后续可接入）
  - 隐私协议与服务条款链接

### B. 登录态入口控制
- 在 `TempureRootView` 中改为：
  - `if authState == .authenticated` -> `HomeView`
  - else -> `LoginView`

### C. 状态与交互
- 发送验证码后显示倒计时（60s）。
- 登录按钮 loading 状态，防重复点击。
- 错误提示统一弹窗（邮箱格式错误、验证码失效、网络异常）。

### 2.2 ViewModel 设计

新增 `AuthViewModel`（建议字段）：
- `email: String`
- `otpCode: String`
- `isSendingCode: Bool`
- `isLoggingIn: Bool`
- `countdown: Int`
- `errorMessage: String?`

主要方法：
- `sendOtp()` -> 调用 Worker `/auth/send-code`
- `loginWithOtp()` -> 调用 Worker `/auth/verify-code`，拿到 `accessToken + refreshToken`
- `restoreSession()` -> App 启动时从 Keychain 恢复 token 并静默刷新
- `logout()` -> 清空本地会话

### 2.3 本地安全存储

- `accessToken` / `refreshToken` 存 Keychain（不要存 UserDefaults）。
- 登录成功后将 `userId` 存内存态（可缓存到 Keychain）。
- 所有 API 请求走 `Authorization: Bearer <accessToken>`。

---

## 3. Cloudflare Worker 后端方案

## 3.1 技术栈
- **Cloudflare Workers**：API 层（鉴权、数据写入、同步接口）
- **Cloudflare D1 (SQLite)**：结构化数据（用户、记录、同步游标）
- **Cloudflare KV**：验证码、限流计数、短期会话缓存
- **Cloudflare R2（可选）**：未来图表导出文件/附件存储

## 3.2 核心数据模型（D1）

### users
- `id TEXT PRIMARY KEY` (uuid)
- `email TEXT UNIQUE NOT NULL`
- `created_at INTEGER NOT NULL`
- `updated_at INTEGER NOT NULL`

### bbt_records
- `id TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `record_date TEXT NOT NULL` (`YYYY-MM-DD`)
- `temperature_c REAL`
- `weight_kg REAL`
- `tags_json TEXT` (JSON 字符串)
- `version INTEGER NOT NULL`（乐观锁/同步版本）
- `updated_at INTEGER NOT NULL`
- `deleted_at INTEGER`（软删除）
- 唯一索引：`(user_id, record_date)`

### sync_cursors
- `user_id TEXT PRIMARY KEY`
- `last_sync_ts INTEGER NOT NULL`

## 3.3 API 设计（Worker）

### 鉴权
1. `POST /auth/send-code`
   - 入参：`{ email }`
   - 行为：生成 6 位码（有效期 5 分钟）写 KV，并做 IP + email 限流
2. `POST /auth/verify-code`
   - 入参：`{ email, code }`
   - 返回：`{ accessToken, refreshToken, user }`
3. `POST /auth/refresh`
   - 入参：`{ refreshToken }`
   - 返回新 `accessToken`

### 业务数据
4. `POST /records/upsert`
   - 入参：单条记录
   - 鉴权：Bearer Token
   - 策略：按 `user_id + record_date` upsert，版本号递增
5. `POST /records/batch-upsert`
   - 入参：记录数组（离线恢复后批量同步）
6. `GET /records?from=...&to=...`
   - 拉取指定日期区间
7. `GET /sync/pull?since=timestamp`
   - 获取变更集（含删除标记）
8. `POST /sync/push`
   - 推送本地变更集，返回服务端冲突结果

## 3.4 冲突处理策略

推荐：**Last-Write-Wins + version**
- 客户端每条记录带 `updatedAt` 与本地 `version`。
- Worker 对比版本：
  - 客户端版本更新：覆盖并 version+1
  - 服务端更新：返回冲突，客户端提示并合并

对当前体温记录场景，冲突概率低，LWW 成本最低。

---

## 4. 客户端与 Worker 的集成改造

## 4.1 分层改造建议

当前已有 `Domain/Repositories/BBTRepository` + `Data/Repositories/BBTRepositoryImpl`。

建议新增：
- `AuthRepository`（登录、token 刷新、登出）
- `RemoteBBTRepository`（调用 Worker API）
- `SyncService`（本地 SQLite <-> 远端 Worker 的增量同步）

并把 `HomeViewModel` 的数据来源改为：
1. 先读本地 SQLite（即时展示）
2. 后台触发 `SyncService.pull + push`
3. 同步完成后刷新 UI

## 4.2 同步时机
- App 启动并登录成功后
- 进入前台（`scenePhase == .active`）
- 用户执行保存（可 debounce 合并）
- 手动下拉刷新（后续可加）

## 4.3 失败兜底
- 网络失败：仅本地保存，不阻断主流程
- 鉴权失效：尝试 refresh，失败则回登录页
- 同步失败：记录重试任务（指数退避）

---

## 5. Cloudflare Worker 项目结构建议

```txt
worker/
  src/
    index.ts               # 路由入口
    middleware/auth.ts     # JWT 校验
    modules/auth.ts        # 发送验证码、验证登录
    modules/records.ts     # 记录 CRUD / upsert
    modules/sync.ts        # push/pull 同步
    db/schema.sql          # D1 表结构
    lib/rateLimit.ts       # 限流
    lib/jwt.ts             # token 签发/校验
  wrangler.toml
```

### wrangler 绑定（示例）
- `[[d1_databases]]` -> `DB`
- `[[kv_namespaces]]` -> `OTP_KV`
- 环境变量：`JWT_SECRET`, `OTP_SALT`, `APP_ENV`

---

## 6. 安全与合规建议

1. Worker 全部接口仅 HTTPS。
2. 验证码接口必须限流（IP、邮箱维度）。
3. token 有效期建议：
   - access token：15~30 分钟
   - refresh token：30 天（可轮换）
4. 所有 D1 查询使用参数绑定，避免 SQL 注入。
5. 审计日志：记录登录失败、异常访问频次。

---

## 7. 分阶段落地计划（推荐）

### Phase 1（1 周）
- 完成 Worker 鉴权最小闭环：`send-code / verify-code / refresh`
- App 加入 `LoginView` + token 存储 + 登录态切换

### Phase 2（1 周）
- Worker 完成 `records/upsert` + `records query`
- App 增加远端写入（先单向：本地写入后异步上云）

### Phase 3（1~2 周）
- 完成 `sync/push + sync/pull` 增量同步
- 增加冲突处理与重试策略

### Phase 4（可选）
- Apple 登录
- 数据导出与设备迁移
- 运营告警与可观测性

---

## 8. 成功标准（验收）

- 新用户可在 30 秒内完成登录。
- 断网保存体温数据不丢失；恢复网络后 10 秒内完成同步。
- 同一账号在两台设备编辑同一天数据，能正确处理冲突并给出反馈。
- 关键鉴权接口具备限流、防重放、token 刷新机制。
