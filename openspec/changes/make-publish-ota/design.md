## Context

`unified-ota-cyber-ota` 将整机升级制品收敛为 **`make ota-package`** 签名 **`tar.gz`**（+ 旁路 `.sig`）。Android `lws-ui` 已有 `make publish`（staging/release + manifest 字段）。本仓补齐主机 `make publish`，复用同一归档。

Worker 契约（artifact 白名单、basename、`PUT`/`GET /view`、大文件 fallback）由 sibling **`../api-server`** change **`hmi-ota-static-upload`** 拥有；本设计只约定主机如何对接该契约。Worker **尚未落地**，basename 约定为 **`.tar.gz`**（可同步改 api-server OpenSpec）。

## Goals / Non-Goals

**Goals:**

- **`make publish`**（确保 ota-package + 上传）与 **`make publish-only`**（仅上传已有包）。
- R2 前缀 = `APP` kebab（默认 `lws_hmi` → **`lws-hmi/`**）；归档 basename 与 artifact 对齐。
- 渠道 / 版本规则对齐 `lws-ui`：默认 `-beta`→staging，`RELEASE=1`→release；版本 = HMI app pubspec semver。
- 凭据仅经环境 / `.env`。
- 上传 **`tar.gz` 与旁路 `.sig`**（签名发现约定与 `unified-ota-cyber-ota` 一致）。

**Non-Goals:**

- 不在本仓实现 Cloudflare Worker（见 api-server **`hmi-ota-static-upload`**）。
- 不改设备 apply / `cyber_ota` 核心；不发布 `factory.img`；不替代 `make upgrade`。

## Decisions

### 1. 制品来源：`ota-package` `tar.gz` + `.sig`

**选择：** `make publish` 前置 **`make ota-package`**；`publish-only` 要求归档与 `.sig` 已存在。

**理由：** 与 upgrade/云路径共用同一签名制品，避免漂移。

### 2. R2 artifact 前缀由 `APP=` 推导

**选择：** `artifact = APP` 中 `_` → `-`。仅允许已存在的 `app/<APP>/`。非 `*_hmi` 的 APP **默认拒绝 publish**（可选 `PUBLISH_ARTIFACT=` 逃生阀）。

### 3. 上传 API：对接 api-server 静态库 PUT

**选择：** 主机客户端对 **`PUT /upload/{artifact}/{archive-basename}`**（Bearer `PUBLISH_API_TOKEN` / `STATIC_API_TOKENS`），期望 ApiResult 含 **`artifact_url`** / **`manifest_url`**；设备用 **`GET /view/{artifact}/{json}`**。Basename 与白名单以 api-server **`hmi-ota-static-upload`** 为准（形如 `lws-hmi_v1.0.38-beta.tar.gz`）。旁路签名以同 basename + `.sig` 上传（或等价约定），供设备整包验签。

若 PUT 尚未部署，可临时用 presigned 双传作桥，但契约以 PUT + view 为准。

### 4. 版本与渠道 = HMI app 版本

云侧 `version` 与归档版本段一律取自 `app/<APP>/pubspec.yaml` 的 semver（去 `+build`）。默认 `{semver}-beta`→staging；`RELEASE=1`→`{semver}`→release。包内 OTA 编排 `manifest.json` 仍由 `ota-package` 定义；云侧 manifest 只描述可下载整包 `tar.gz`（`sha512` 辅助传输出错检测；**写盘信任仍为设备 Ed25519 整包验签**）。

### 5. 落地顺序

1. api-server **`hmi-ota-static-upload`** 按 **`.tar.gz`**（+ `.sig`）合并/部署。  
2. 本仓 publish 脚本 + Make + docs。

## Risks / Trade-offs

- **[Risk] `ota-package` 未就绪** → fail-fast 提示先完成前置变更。
- **[Risk] Worker 未接受 artifact / 体过大** → 依赖 api-server change；主机 fail-fast 打印 HTTP 错误。

## Migration Plan

1. 确认 `ota-package` 可用 + api-server HMI artifact 已上线（`.tar.gz`）。  
2. 本仓落地 `make publish`；staging 验证 `/view/lws-hmi/staging.json`。  
3. 设备侧 manifest URL 指向新 artifact（`unified-ota-cyber-ota` / 后续）。

## Open Questions

- 上传时是否 rename 本地归档以过服务端 basename 校验（倾向 rename）。
- 是否需要 `PUBLISH_ARTIFACT=`（实现时按需）。
- `.sig` 是否单独 PUT 对象，或由 Worker 约定 `url + ".sig"`——与 `unified-ota-cyber-ota` open question #4 对齐。
