## Context

运营人员需要在开发机上对 sibling **`../api-server`**（Cloudflare Worker）做两类动作：

1. **用户登录**拿到 JWT `access_token`，供后续主机 Make 目标复用。
2. **注册设备**：`POST /v1/admin/devices` 只需 `{ sn, model }`，且要求 caller `user.role` ∈ `{3,4,9}`；板端 identity 已由 Vendor Storage / `read-identity` 提供，主机已有 SSH 设备选择（`SN=` / `IP=`）。

进行中的 **`make-publish-ota`** 计划用 Bearer 上传 OTA；本变更提供统一的登录落盘，供 publish 与 register-device 共用。Worker 静态库上传今日认 **`STATIC_API_TOKENS`**，与用户登录 JWT 不是同一套密钥——设计上必须诚实区分。

## Goals / Non-Goals

**Goals:**

- **`make login`**：提示输入 `account` / `password`，调用 **`POST /v1/login`**，落盘 `access_token`。
- **`make register-device`**：SSH 读 sn+model → Bearer JWT → **`POST /v1/admin/devices`**。
- 共享凭据文件 / env 约定，供 **`make publish`**（sibling）与本目标读取。
- API 基址可配置（默认对齐 test Worker origin，与设备候选一致）。

**Non-Goals:**

- 不实现 / 不修改 api-server。
- 不实现设备端 activate（`POST /v1/devices/:sn/activate`）或 device token mint。
- 不替代 `make write-identity`（板端无 model/sn 时 register 应 fail-fast）。
- 不实现 `POST /v1/register`（用户注册）。
- 不把用户 JWT 强行当作唯一 publish 凭据——若 Worker 仅接受 static token，允许 `PUBLISH_API_TOKEN` 覆盖。

## Decisions

### 1. API 契约：直接对接已文档化的 v1 路由

**选择：**

| 目标 | Method / Path | Body / Auth |
|------|---------------|-------------|
| login | `POST /v1/login` | JSON `{ "account", "password" }`；无 JWT；成功 `data.access_token` |
| register-device | `POST /v1/admin/devices` | JSON `{ "sn", "model" }`；`Authorization: Bearer <access_token>` |

解析 **ApiResult**：HTTP 非 2xx 或业务错误码时打印 `message` / `code` 并非零退出。忽略旧 `/login`、`/system/device/*`。

**理由：** 与 `http-apis.md` / `admin-devices` 一致；无需本仓再发明网关。

### 2. 凭据落盘：gitignored 文件 + env 覆盖

**选择：**

- 默认路径：`output/cloud/credentials.json`（或等价；目录 gitignore；**禁止**提交）。
- 文件至少含：`access_token`、可选 `account` / `role` / `api_base` / `updated_at`（便于排障）。
- 读取优先级（消费者）：显式 env（如 `CLOUD_ACCESS_TOKEN=` / `PUBLISH_API_TOKEN=`）→ 凭据文件 → 缺失则提示先 `make login`。
- **密码不落盘**；仅内存/管道传给 login HTTP。

**备选否决：** 只写 `.env`——易误提交且与 dotenv 加载混用危险。

### 3. API 基址：`CLOUD_API_BASE`

**选择：** 环境 / `.env` 键 **`CLOUD_API_BASE`**（无尾斜杠），默认 **`https://api-prod.lasercyber.workers.dev`**（正式环境，与设备 prod 主候选一致）。测试用 **`CLOUD_API_BASE=https://api-test.lasercyber.workers.dev`**。login / register-device /（建议）publish 共用。

**备选：** 复用板端探测逻辑——主机 Make 不需要并发 probe；显式基址更可预期。

### 4. `make login` 交互与非交互

**选择：**

- 默认：TTY 提示 `Account:` / `Password:`（密码无回显，`read -s` 或等价）。
- 允许非交互：`CLOUD_ACCOUNT=` + `CLOUD_PASSWORD=`（或 stdin JSON）供 CI/脚本；帮助文案警告勿把密码写进已跟踪文件。
- 成功后打印简短确认（account / role），**不**回显完整 token（可打印末几位）。

### 5. `make register-device`：SSH 取 identity 再注册

**选择：**

1. 复用 `usb-ssh-session` / `device-target`（与 `write-identity`、`upgrade-process-library` 相同选择规则）。
2. 远程执行 `read-identity sn` 与 `read-identity model`（缺一则失败，提示 `make write-identity`）。
3. **`SN=` / `IP=` 仅选板**：与 `push-app` / `write-identity` 相同；**不接受** `PRODUCT_SN=` / `MODEL=` / `BRAND=` 手填身份（缺 identity 则提示先 `make write-identity`）。
4. `model` 原样提交；服务端会做 `LaserCyber` 前缀归一——主机不必预剥。
5. **409**（活跃 sn 已存在）：打印清晰错误；可选 `FORCE` 不在本变更做软删/复活（Worker 复活语义若存在则仅文档说明，默认不自动 DELETE）。

**理由：** 注册字段与板端 identity 同源，避免手抄错误。

### 6. 与 `make publish` 的凭据关系

**选择：**

- 本变更定义共享读取辅助（脚本函数或小库）：`resolve_cloud_access_token`。
- Sibling **`make-publish-ota`** 任务应改为：`PUBLISH_API_TOKEN`（static）优先用于 `PUT /upload`；若未设，则尝试登录落盘的 `access_token`，并在失败时提示「static token 或 `make login`」。
- 本变更 **tasks** 含一条：同步改 `make-publish-ota` 的 design/tasks/凭据段落（或实现时一并改 publish 脚本）。

**理由：** 用户期望「登录一次两处可用」；同时不假装 Worker 已接受用户 JWT 做静态上传。

### 7. 实现形态：shell + curl/python

**选择：** 与仓库其他主机脚本一致——bash 编排 + `curl`（或已有 python JSON 小段）解析 ApiResult；不新增 Node 依赖。

## Risks / Trade-offs

- **[Risk] 用户 JWT 无法通过 `PUT /upload`** → Mitigation：publish 保留 `PUBLISH_API_TOKEN`；文档写明两套凭据；login 仍服务 admin 注册与其它 JWT API。
- **[Risk] 账号非 operator/admin → register 403** → Mitigation：fail-fast 打印 role 提示。
- **[Risk] 凭据文件权限过宽** → Mitigation：写入后 `chmod 600`。
- **[Risk] 板端 model 与 `product.model` 不一致** → Mitigation：打印将提交的 sn/model；失败时指向运营后台 product 表 / `write-identity`。
- **[Risk] Token 过期** → Mitigation：401 时提示重新 `make login`；本变更不做 refresh。

## Migration Plan

1. 落地脚本 + Make + `.gitignore` + `.env.example` 键。
2. 交叉更新 **`make-publish-ota`** 凭据读取说明。
3. 操作员：`make login` → `make register-device`；publish 按 sibling 就绪后使用同一 login 或 static token。

## Open Questions

- 生产默认基址是否也要一键切换（`CLOUD_API_ENV=prod|test`）——**已定**：默认 prod；测试仅靠 `CLOUD_API_BASE=` 覆盖。
- 是否在成功 register 后打印 `device_id` / `is_activated`（ApiResult `DeviceInfo`）——倾向是，便于确认未激活态。
