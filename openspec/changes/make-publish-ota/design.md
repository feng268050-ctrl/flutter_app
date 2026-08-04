## Context

`unified-ota-cyber-ota` 将整机升级制品收敛为 **`make ota-package`** 产出的单一签名 zip（内含 `*.img` / `*.img.sig` + 包内编排 `manifest.json`），并约定未来云发布复用该 zip。Android 侧 `lws-ui` 已有成熟的 **`make publish`**：默认打 `-beta` 包并覆盖 R2 `lws-app/staging.json`，`RELEASE=1` 打稳定版并覆盖 `release.json`；manifest 字段为 `version` / `filename` / `published_at` / `sha512` / `url`。

当前 api-server 静态上传白名单仅有 **`ai-library`**、**`process-library`**、**`lws-app`**（`PUT /upload/:artifact/*` + `GET /view/:artifact/{staging|release}.json`）。**没有** `lws-hmi` 前缀，设备/Worker 无法按产品目录发布或查看 HMI 整机 OTA 描述。`lws-ui` 的 publish 脚本实际走 **`GET /v1/storage/r2/presigned-url`** 客户端自写 zip + manifest；库上传则走 **`PUT /upload/...`** 由服务端写 manifest。本设计优先与 **静态库上传同一 PUT 契约**（服务端写 manifest、设备用 `/view/...`），以便 `cyber_ota` 与 `lws-app` OTA 对齐。

本仓变更依赖：`unified-ota-cyber-ota` 已落地（或至少可调用）`ota-package` 输出路径与签名 zip 形状。Worker 改动在 sibling **`../api-server`**，实现阶段单独 OpenSpec。

## Goals / Non-Goals

**Goals:**

- 提供 **`make publish`**（打包/确保 ota-package + 上传）与 **`make publish-only`**（仅上传已有 zip）。
- R2 前缀 = `APP` 的 kebab 形式（默认 `lws_hmi` → **`lws-hmi/`**）；zip basename 与 artifact 对齐（如 `lws-hmi_v1.0.38-beta.zip`）。
- Manifest 与渠道规则对齐 `lws-ui` / 现有静态库 schema，供 `GET /view/{artifact}/staging.json|release.json`。
- 文档化 api-server 缺口与跨仓任务；凭据仅经环境 / `.env`。

**Non-Goals:**

- 不在本仓实现 Cloudflare Worker；不改设备 apply / `cyber_ota` 核心（归 `unified-ota-cyber-ota`）。
- 不发布 `factory.img`、不替代 `make upgrade` SSH 路径、不做 App-only（仅 Flutter bundle）云通道。
- 不强制迁移 `lws-ui` 的 presigned publish 实现。

## Decisions

### 1. 制品来源：`ota-package` zip，不是重新打松散 img

**选择：** `make publish` 前置 **`make ota-package`**（与 `make upgrade` 同一 zip）。`publish-only` 要求该路径上的 zip 已存在。

**理由：** `unified-ota-cyber-ota` 已约定云与主机共用同一压缩制品；重复打包会漂移签名集。

**备选：** publish 时现场 zip 松散 `output/firmware/**`。拒绝：与 upgrade/云路径分叉，易漏 `.sig`。

### 2. R2 artifact 前缀由 `APP=` 推导

**选择：** `artifact = APP` 中 `_` → `-`（`lws_hmi` → `lws-hmi`，`cnc_hmi` → `cnc-hmi`）。仅允许已存在的 `app/<APP>/`（与 `multi-app-build-select` 一致）。非 `*_hmi` 的 APP（如 `factory_test`）**默认拒绝 publish**（整机 OTA 面向 HMI 产品），除非文档化显式覆盖变量（实现时可加 `PUBLISH_ARTIFACT=` 逃生阀，默认仍按 APP 映射）。

**理由：** 用户要求「目录为 lws-hmi，实际按 APP=」；与现有 kebab R2 前缀（`lws-app`）一致。

**备选：** 固定写死 `lws-hmi/`。拒绝：多产品线会撞目录。

### 3. 上传 API：优先扩展 `PUT /upload/:artifact/*`（api-server）

**选择：** 在 api-server 将 `lws-hmi`（及约定的 `*-hmi` 产品 slug）加入 `LIBRARY_UPLOAD_REGISTRY`；basename 规则类比 `lws-app`：`{artifact-slug}_[vV]?{semver}(-alpha|-beta)?.zip`（slug 内连字符保留，如 `lws-hmi_v1.0.0-beta.zip`）。成功后服务端写 `{artifact}/staging.json|release.json`，响应含 `artifact_url` / `manifest_url`。设备/检查更新用 **`GET /view/{artifact}/{json}`**。

主机客户端：对标 `lws-ui` 的 Make 面（`publish` / `publish-only`、`RELEASE=`、token），实现上优先 **单次 PUT 上传 zip**（让服务端生成 manifest），避免双次 presign 与客户端/服务端 manifest 漂移。若实现时 PUT 尚未合并，可临时用 presigned 双传（与 `publish_lws_app.py` 同形）作为过渡，但契约以 PUT + view 为准。

**理由：** 与 `ai-library` / `process-library` / 规范上的 `lws-app` 一致；`/view/` 是设备已 pin 的 Worker 路径模式。

**备选：** 仅用 presigned、任意 key。可行但无 basename 校验、无统一 view 白名单，易与运维约定漂移。

### 4. 版本与渠道 = HMI app 版本

**选择：** 云侧 `staging.json` / `release.json` 的 **`version`**、以及上传 zip basename 中的版本段，**一律**取自所选 HMI app 的 `app/<APP>/pubspec.yaml` `version:` 的 **semver 段**（`1.0.38+1038` → `1.0.38`）。默认 `PACK_VERSION={semver}-beta` → staging；`RELEASE=1` → `{semver}` → release。与 `lws-ui`（用 App `versionName`）同思路，本仓对应物是 Flutter **HMI app** 版本，不是独立 firmware/OS 编号、不是 git tag、也不是包内编排 `manifest.json` 另起一套版本字段（若包内需要版本字符串，应与 app 版本一致或由其派生）。

**理由：** 产品「检查更新」面向用户看到的是 HMI/产品版本；整机 zip 虽含 kernel/rootfs，发布通道仍以 app 版本做门控，避免双版本漂移。

**备选：** 单独维护 `VERSION` / Buildroot 镜像版本。拒绝：与 Settings / pubspec 展示不一致，发布易漏 bump。

包内 OTA 编排 `manifest.json`（分区列表）保持 `ota-package` 定义；**云侧** `staging.json`/`release.json` 只描述「可下载的整包 zip」，不替代包内验签信任根。

### 5. 跨仓落地顺序

1. api-server OpenSpec：扩展 artifact + CLIENT-CURL + 测试。  
2. 合并/部署 Worker。  
3. lws-hmi：`scripts/publish-*.sh|py` + Makefile + docs。

本提案在 tasks 中拆成「api-server（外仓）」与「本仓」两组，避免误以为只改 lws-hmi。

## Risks / Trade-offs

- **[Risk] `unified-ota-cyber-ota` 未完成导致无 zip** → Mitigation：tasks 标明硬依赖；publish 缺 zip 时 fail-fast 提示先 `make ota-package` / 完成前置变更。
- **[Risk] OTA zip 体积大，Worker PUT 体限制** → Mitigation：实现前确认 Worker/R2 PUT 大小上限；若不足，改用 multipart/presigned 直传 R2 并由单独 API 写 manifest（api-server 提案中处理）。
- **[Risk] 多 APP 前缀膨胀白名单** → Mitigation：registry 允许「`*-hmi` 产品 slug」模式或显式列表；拒绝任意字符串 artifact。
- **[Risk] 与 `lws-app` 渠道并存混淆** → Mitigation：文档明确 Android APK OTA 仍用 `lws-app/`；Linux 整机用 `lws-hmi/`（或 APP 派生）。

## Migration Plan

1. 完成/确认 `ota-package` 可用。  
2. api-server 上线 `lws-hmi`（等）上传与 view。  
3. 本仓落地 `make publish`；用 staging 发一版验证 `/view/lws-hmi/staging.json` 与 zip URL。  
4. 设备侧 manifest URL 指向新 artifact（`unified-ota-cyber-ota` / 后续接线）。  

回滚：停止 publish；R2 上保留历史对象；必要时手动回写旧 `staging.json`/`release.json`。

## Open Questions

- OTA zip 公开 basename 是否固定为 `{artifact}_v{ver}.zip`，抑或保留 `ota-package` 本地文件名并在上传时 rename（倾向上传时 rename 以过服务端校验）。
- 是否需要 `PUBLISH_ARTIFACT=` 覆盖映射（多目录调试）；默认可不做，实现时按需加。
- 大文件是否必须从 Day-1 就上 presigned：以实现阶段压测 Worker PUT 后再定。
