## Why

`unified-ota-cyber-ota` 约定整机升级共用 **`make ota-package`** 产出的签名 OTA **`tar.gz`**（+ 旁路 `.sig`），并明确未来 **`make publish`** 必须以该包为前置；但云端发布通道尚未落地。产品设备需要与 Android `lws-ui` 同形的 **R2 目录 + `staging.json` / `release.json` manifest**，才能按版本拉取归档。现在应在 OTA 打包契约之后补齐主机侧 `make publish`。

上传路径对齐 **`lws-ui`**：向云服务索取 R2 **presigned PUT** 凭证，由主机 Python 客户端直传对象（**不**走 `PUT /upload/{artifact}/…` Worker 代写）。R2 key 前缀 / 对象类型若需服务端放行，见 sibling api-server 现有 **`/v1/storage/r2/presigned-url`**（及必要时的 HMI key 白名单扩展）；本变更不实现 Worker。

## What Changes

- 实现 **`make publish`** / **`make publish-only`**：将 OTA `tar.gz`、旁路 `.sig` 与渠道 manifest 经 **presigned URL** 直传应用 R2 桶。
- R2 对象前缀默认 **`lws-hmi/`**；实际前缀由 **`APP=`** 推导（`lws_hmi` → `lws-hmi`），与多产品 `APP=` 选择一致。
- Manifest 由主机客户端组装并 PUT：`version`、`filename`、`published_at`、`url`（**不含 `sha512`**——完整性与防篡改由设备对 `tar.gz` 的 Ed25519 `.sig` 验签承担）；默认写 **`staging.json`**，**`RELEASE=1`** 写 **`release.json`**。
- **云侧发布版本号 = 所选 HMI app 版本**：取自 `app/<APP>/pubspec.yaml` 的 `version:` semver 段（忽略 `+build`）。
- 主机 Python 发布脚本 / Make 目标、help、README / AGENTS 重建表；凭据经 **`PUBLISH_API_TOKEN`**（presign Bearer）或 sibling **`make login`** 落盘的 `access_token`（及 `.env`）鉴权。
- **API 基址与 `make login` / `make register-device` 完全一致**：共用 `scripts/cloud-credentials.sh` 的 **`cloud_api_base()`**，默认生产 **`https://api-prod.lasercyber.workers.dev`**；测试仅通过显式 **`CLOUD_API_BASE=`** 覆盖。不另设独立的 publish 默认 host。
- 上传契约对齐 **`lws-ui` `scripts/publish_lws_app.py`**：对上述基址 `GET /v1/storage/r2/presigned-url` → HTTP PUT 到返回的 `upload_url`（R2）；本仓只做客户端与文档对接。

## Capabilities

### New Capabilities

- `host-ota-publish`: 主机 `make publish` / `publish-only`——以 `ota-package` `tar.gz`（+ `.sig`）为制品，按 `APP=` / `RELEASE=` 经 presigned 直传 R2 `{artifact}/` 并更新渠道 manifest。

### Modified Capabilities

- `host-remote-upgrade`: 将「未来 `make publish` 以 `ota-package` 为前置」落成可执行 Make 契约。
- `multi-app-build-select`: `APP=` 亦决定云发布 R2 artifact 前缀。

## Impact

- **Host（lws-hmi）**：publish Python 脚本、Makefile、`.env` 示例键；依赖 `make ota-package` 产物。
- **Versioning**：云 manifest / 归档 basename 版本 = HMI Flutter app pubspec semver。
- **api-server**：默认打 **api-prod** 上已有 R2 presign；若 HMI `.tar.gz` / `.sig` key 需放行则在 sibling 仓扩展（非本仓）。
- **非目标**：不替代 `make upgrade`；不发布 `factory.img`；不走 `PUT /upload/…`；不默认打 api-test；不把 Worker 合入本仓。
