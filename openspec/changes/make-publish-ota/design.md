## Context

`unified-ota-cyber-ota` 将整机升级制品收敛为 **`make ota-package`** 签名 **`tar.gz`**（+ 旁路 `.sig`）。Android `lws-ui` 已有 `make publish`：`GET /v1/storage/r2/presigned-url` 取凭证，Python 客户端 HTTP PUT 直传 R2，并自写渠道 manifest。本仓补齐同形主机 `make publish`，制品换成 HMI OTA 归档。

本设计**不以** api-server **`PUT /upload/{artifact}/…`**（静态库 Worker 代写 + 服务端拼 manifest）为生产路径；该路径可继续服务 Android/库类制品，HMI 整机发布走 **presign 直传**。

## Goals / Non-Goals

**Goals:**

- **`make publish`**（确保 ota-package + 上传）与 **`make publish-only`**（仅上传已有包）。
- R2 前缀 = `APP` kebab（默认 `lws_hmi` → **`lws-hmi/`**）；归档 basename 与 artifact 对齐。
- 渠道 / 版本规则对齐 `lws-ui`：默认 `-beta`→staging，`RELEASE=1`→release；版本 = HMI app pubspec semver。
- 上传对齐 **`lws-ui`**：对每个对象（`tar.gz`、`.sig`、渠道 JSON）先向云 API 索取 presigned PUT，再 **HTTP PUT** 到响应 `upload_url`；客户端使用返回的 `public_url` 写入 manifest。
- **云 API 基址与 login / register-device 同源**：调用 **`cloud_api_base()`**（`scripts/cloud-credentials.sh`）。默认 **`https://api-prod.lasercyber.workers.dev`**（生产）；仅当操作者显式设置 **`CLOUD_API_BASE`**（例如 api-test）时改打测试。不引入 `PUBLISH_BASE_URL` 等第二套默认。
- 凭据：`PUBLISH_API_TOKEN`（Worker `STATIC_API_TOKENS`）优先；否则 `CLOUD_ACCESS_TOKEN` / `make login` 落盘的 `output/cloud/credentials.json`（`cloud_resolve_publish_token`）。
- 云侧渠道 manifest **不含 `sha512`**：设备写盘信任为整包 Ed25519 `.sig`（验签同时覆盖下载完整性与防篡改）。

**Non-Goals:**

- 不在本仓实现 Cloudflare Worker；不把 HMI 发布绑到 `PUT /upload/…`。
- 不改设备 apply / `cyber_ota` 核心；不发布 `factory.img`；不替代 `make upgrade`。
- 不在云 manifest 中冗余 `sha512`（与 `lws-ui` zip 路径刻意分歧：HMI 已有 `.sig`）。
- 不默认把 publish 指向 api-test 或独立 host。

## Decisions

### 1. 制品来源：`ota-package` `tar.gz` + `.sig`

**选择：** `make publish` 前置 **`make ota-package`**；`publish-only` 要求归档与 `.sig` 已存在。

**理由：** 与 upgrade/云路径共用同一签名制品，避免漂移。

### 2. R2 artifact 前缀由 `APP=` 推导

**选择：** `artifact = APP` 中 `_` → `-`。仅允许已存在的 `app/<APP>/`。非 `*_hmi` 的 APP **默认拒绝 publish**（可选 `PUBLISH_ARTIFACT=` 逃生阀）。

### 3. 上传路径：生产云 API presign + Python 直传 R2（对齐 lws-ui + login）

**选择：** 参考 `lws-ui/scripts/publish_lws_app.py`，且 API origin 与本仓 **`make login` / `make register-device`** 一致：

1. `base = cloud_api_base()` → 默认 **`https://api-prod.lasercyber.workers.dev`**
2. `GET {base}/v1/storage/r2/presigned-url?key=…&content_type=…`（Bearer）→ `upload_url` / `public_url`
3. 主机 Python **`PUT` 文件字节到 `upload_url`**（R2；匹配 `Content-Type`；无 AWS SDK / boto3）
4. 对 **`{artifact}/{archive-basename}.tar.gz`**、**同 basename `.sig`**、**`{artifact}/staging.json|release.json`** 各做一次 presign + PUT
5. Manifest JSON 由客户端本地组装后 PUT（Worker 不代写）

**Token 解析（与 login / register-device 对齐）：** `PUBLISH_API_TOKEN` → `CLOUD_ACCESS_TOKEN` → `output/cloud/credentials.json` 的 `access_token`（`cloud_resolve_publish_token`）；皆无则失败并提示 `make login` 或设置静态 token。

Basename 形如 `lws-hmi_v1.0.38-beta.tar.gz`（与现有静态制品命名习惯一致）。若服务端对 `key` / 后缀有白名单，在 sibling api-server（**api-prod**，除非操作者覆盖基址）放行 HMI 前缀下的 `.tar.gz` / `.sig` / 渠道 JSON；本仓客户端 fail-fast 打印 HTTP 错误。

**明确不做：** 不使用 `PUT /upload/{artifact}/{basename}`；不另设默认指向 api-test 的 publish host；不依赖 Worker 代写 manifest 的 `artifact_url` / `manifest_url` ApiResult。

### 4. 版本与渠道 = HMI app 版本；manifest 无 sha512

云侧 `version` 与归档版本段一律取自 `app/<APP>/pubspec.yaml` 的 semver（去 `+build`）。默认 `{semver}-beta`→staging；`RELEASE=1`→`{semver}`→release。包内 OTA 编排 `manifest.json` 仍由 `ota-package` 定义。

云侧渠道 manifest 字段：**`version`、`filename`、`published_at`、`url`**。`url` 为 `tar.gz` 的 `public_url`。**不写 `sha512`**：完整性与防篡改由设备下载后对旁路 **`.sig` 做 Ed25519 验签**完成（验签失败即拒绝写盘）。签名对象约定：与归档同目录、同 basename + `.sig`（或 `url + ".sig"` 可解析），实现时写死一种并在文档说明。

### 5. 落地顺序

1. 确认 **api-prod**（或显式 `CLOUD_API_BASE`）上 **`/v1/storage/r2/presigned-url`** 对目标 `key`（`lws-hmi/*.tar.gz`、`.sig`、渠道 JSON）可用；若需白名单扩展则在 api-server 先行。  
2. 本仓 Python publish 脚本 + Make + docs（基址复用 `cloud_api_base`）。

## Risks / Trade-offs

- **[Risk] `ota-package` 未就绪** → fail-fast 提示先完成前置变更。
- **[Risk] api-prod presign 拒绝 HMI key / 体过大** → 依赖 api-server key 策略；主机 fail-fast 打印 HTTP 错误。
- **[Trade-off] 与 `lws-ui` manifest 字段不完全同形**（无 `sha512`）→ 设备/云消费方必须以 `.sig` 为信任根；文档需写明，避免沿用 Android 客户端对 `sha512` 的假设。

## Migration Plan

1. 确认 `ota-package` 可用 + **生产** R2 presign 对 HMI keys 可用。  
2. 本仓落地 `make publish`（默认 api-prod）；staging 用公开 URL 或等价方式核对 `staging.json`（`version` / `filename` / `url`，无 `sha512`）。  
3. 设备侧 manifest URL 指向新 artifact（`unified-ota-cyber-ota` / 后续）。

## Open Questions

- 上传时是否 rename 本地归档以匹配约定 basename（倾向 rename，同 lws-ui pack 命名）。
- 是否需要 `PUBLISH_ARTIFACT=`（实现时按需）。
- `.sig` 的 R2 key：独立对象 `…tar.gz.sig` / `….sig` 与设备发现规则——与 `unified-ota-cyber-ota` open question #4 对齐后写死。
