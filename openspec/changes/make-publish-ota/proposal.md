## Why

`unified-ota-cyber-ota` 约定整机升级共用 **`make ota-package`** 产出的签名 OTA **`tar.gz`**（+ 旁路 `.sig`），并明确未来 **`make publish`** 必须以该包为前置；但云端发布通道尚未落地。产品设备需要与 Android `lws-ui` 同形的 **R2 目录 + `staging.json` / `release.json` manifest**，才能按版本拉取归档。现在应在 OTA 打包契约之后补齐主机侧 `make publish`。

Worker 侧 artifact 白名单扩展见 sibling **`../api-server`** OpenSpec **`hmi-ota-static-upload`**（本变更不实现 Worker；约定扩展名为 **`.tar.gz`**）。

## What Changes

- 实现 **`make publish`** / **`make publish-only`**：将 OTA `tar.gz`（及 `.sig`）与渠道 manifest 发布到应用 R2 桶。
- R2 对象前缀默认 **`lws-hmi/`**；实际前缀由 **`APP=`** 推导（`lws_hmi` → `lws-hmi`），与多产品 `APP=` 选择一致。
- Manifest 形状对齐现有静态库 / `lws-app`：`version`、`filename`、`published_at`、`sha512`、`url`；默认写 **`staging.json`**，**`RELEASE=1`** 写 **`release.json`**。
- **云侧发布版本号 = 所选 HMI app 版本**：取自 `app/<APP>/pubspec.yaml` 的 `version:` semver 段（忽略 `+build`）。
- 主机脚本 / Make 目标、help、README / AGENTS 重建表；凭据经 **`PUBLISH_API_TOKEN`**（及 `.env`）鉴权。
- 上传契约依赖 api-server **`hmi-ota-static-upload`**（`PUT /upload/{artifact}/*` + `GET /view/{artifact}/…`）；本仓只做客户端与文档对接。

## Capabilities

### New Capabilities

- `host-ota-publish`: 主机 `make publish` / `publish-only`——以 `ota-package` `tar.gz`（+ `.sig`）为制品，按 `APP=` / `RELEASE=` 上传到 R2 `{artifact}/` 并更新渠道 manifest。

### Modified Capabilities

- `host-remote-upgrade`: 将「未来 `make publish` 以 `ota-package` 为前置」落成可执行 Make 契约。
- `multi-app-build-select`: `APP=` 亦决定云发布 R2 artifact 前缀。

## Impact

- **Host（lws-hmi）**：publish 脚本、Makefile、`.env` 示例键；依赖 `make ota-package` 产物。
- **Versioning**：云 manifest / 归档 basename 版本 = HMI Flutter app pubspec semver。
- **api-server**：见 **`hmi-ota-static-upload`**；本变更不实现 Worker。
- **非目标**：不替代 `make upgrade`；不发布 `factory.img`；不把 Worker 合入本仓。
