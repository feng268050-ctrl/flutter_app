## Why

云端运营动作（OTA `make publish`、向 Worker 注册新板）都需要 **api-server 用户会话**，但主机侧尚无统一登录与凭据落盘；设备入库还要先从板子读出 **SN / model**。现在补齐 `make login` 与 `make register-device`，让发布与注册共用同一次登录拿到的 `access_token`。

## What Changes

- 实现 **`make login`**：交互提示账号/密码，调用 sibling **`../api-server`** 的 **`POST /v1/login`**，将返回的 **`access_token`**（及必要元数据）持久化到本机凭据文件，供后续 Make 目标读取。
- 实现 **`make register-device`**：按现有 `SN=` / `IP=` 设备选择规则 SSH 到板子，用 **`read-identity`** 读取 **sn** 与 **model**，再以登录 JWT 调用 **`POST /v1/admin/devices`**（body `{ sn, model }`）完成运营侧设备注册。
- Makefile `help`、README / `docs/make-commands.md` / AGENTS 重建表；API 基址与凭据路径经环境 / `.env` 配置。
- 与进行中的 **`make-publish-ota`** 对齐：publish 在未显式设置静态上传 token 时，**优先使用** `make login` 落盘的 `access_token`（或文档约定的共享键）；本变更不实现 R2 上传本身。

## Capabilities

### New Capabilities

- `host-cloud-login`: 主机 `make login`——对接 api-server 用户登录，交互输入凭据，持久化 `access_token` 供 publish / register-device 等目标使用。
- `host-register-device`: 主机 `make register-device`——SSH 读取板端 identity，以运营 JWT 调用 admin 设备注册接口。

### Modified Capabilities

- （无已归档 living spec 的需求变更；与 sibling change **`make-publish-ota`** / capability **`host-ota-publish`** 的凭据读取约定在本变更 design + tasks 中交叉更新。）

## Impact

- **Host（lws-hmi）**：登录/注册脚本、Makefile 目标、`.env.example`、文档；复用现有 USB-SSH / `device-target` 选择与板端 `read-identity`。
- **api-server（只读契约）**：`POST /v1/login`（`{ account, password }` → `data.access_token`）；`POST /v1/admin/devices`（operator/reviewer/admin JWT；`{ sn, model }`）。本仓不实现 Worker。
- **Sibling**：`make-publish-ota` 应消费同一凭据落盘路径（或 `CLOUD_ACCESS_TOKEN` / 等价 env）；若 Worker **`PUT /upload`** 仍仅认 `STATIC_API_TOKENS`，publish 可继续用 `PUBLISH_API_TOKEN` 覆盖，登录 JWT 主路径服务 admin 类 API。
- **非目标**：不实现设备端 Ed25519 activate / token mint；不替代 `make write-identity`；不实现用户注册 `POST /v1/register`；不在本仓改 api-server。
