## Why

`unified-ota-cyber-ota` 约定整机升级共用 **`make ota-package`** 产出的签名 OTA zip，并明确未来 **`make publish`** 必须以该 zip 为前置；但云端发布通道尚未落地。产品设备（`cyber_ota` / Settings / WS `check_update`）需要与 Android `lws-ui` 同形的 **R2 目录 + `staging.json` / `release.json` manifest**，才能按版本拉取 zip。现在应在 OTA 打包契约之后补齐主机侧 `make publish`，并扩展 api-server 上传白名单（当前仅 `ai-library` / `process-library` / `lws-app`，**无** `lws-hmi`）。

## What Changes

- 在 **`unified-ota-cyber-ota` 之后**（依赖其 `make ota-package` 与签名 zip 契约）实现 **`make publish`** / **`make publish-only`**：将 OTA zip 与渠道 manifest 发布到应用 R2 桶。
- R2 对象前缀默认 **`lws-hmi/`**；实际前缀由 **`APP=`** 推导（`lws_hmi` → `lws-hmi`，即下划线改连字符），与多产品 `APP=` 选择一致。
- Manifest 形状对齐现有静态库 / `lws-app` 约定：`version`、`filename`、`published_at`、`sha512`、`url`；默认写 **`staging.json`**，**`RELEASE=1`** 写 **`release.json`**（版本名带 / 不带 `-beta` 与 `lws-ui` 一致）。
- **云侧发布版本号 = 所选 HMI app 版本**：取自 `app/<APP>/pubspec.yaml` 的 `version:`（如 `lws_hmi` 的 `1.0.38+1038` → `1.0.38`），**不**另立 OS/镜像/git 版本号。
- 主机脚本 / Make 目标、help、README / AGENTS 重建表；凭据经 **`PUBLISH_API_TOKEN`**（及 `.env`）鉴权，不把 token 写入仓库。
- **跨仓（实现阶段）**：若 api-server 的 `PUT /upload/:artifact/*` + `GET /view/:artifact/:json_file` 尚不接受 `lws-hmi`（及 APP 派生 artifact），在 **`../api-server`** 走 OpenSpec 增补 artifact 与 basename 规则后再接本仓 publish 客户端。本变更在 lws-hmi 侧定义期望契约与对接任务，不在本仓实现 Worker。

## Capabilities

### New Capabilities

- `host-ota-publish`: 主机 `make publish` / `publish-only`——以 `ota-package` zip 为制品，按 `APP=` / `RELEASE=` 上传到 R2 `{artifact}/` 并更新 `staging.json` 或 `release.json`；文档化与 `lws-ui` publish、api-server 静态上传的对齐点。

### Modified Capabilities

- `host-remote-upgrade`: 将「未来 `make publish` 以 `ota-package` 为前置」从规划表述落成可执行 Make 契约（publish 依赖同一 zip；不改变 SSH `make upgrade` 设备路径语义）。
- `multi-app-build-select`: `APP=` 除构建/推送/rootfs 外，亦决定云发布 R2 artifact 前缀（及 zip/manifest 命名中的产品段）。

## Impact

- **Host（lws-hmi）**：新/扩 `scripts/publish*.py|sh`、Makefile `publish` / `publish-only`、`.env` 示例键（`PUBLISH_API_TOKEN`、`PUBLISH_BASE_URL` 等）；依赖 `make ota-package` 产物路径。
- **Versioning**：云 manifest / zip basename 的版本号 **必须** 等于所选 HMI Flutter app（`app/<APP>/pubspec.yaml`）的 semver（忽略 `+build`）；设备 `check_update` 与该 app 版本比较。渠道规则对齐 `lws-ui`。
- **api-server（sibling repo）**：扩展静态库 registry，至少支持 artifact **`lws-hmi`**（及按 `APP` 派生的 `*-hmi` 产品前缀）；basename / view 路径与 manifest 自动写入；实现时在 api-server 单独 OpenSpec。
- **Device / cyber_ota**：本变更以发布通道为主；设备拉取 URL（`/view/{artifact}/{staging|release}.json`）与 `unified-ota-cyber-ota` 对齐，设备侧接线仍归该变更或其后续，本提案不重复实现 apply。
- **非目标**：不替代 `make upgrade` SSH 热路径；不发布 `factory.img` / RockUSB 制品；不把 Worker 代码合入本仓。
