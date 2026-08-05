## Why

P2.5 已交付 A/B 槽位与 `make upgrade`，但开发流式写分区与未来云 OTA 的 staged apply 仍是两条路径：前者无统一 HMI 进度；后者尚未实现。产品需要**同一套 staged 管线**（落盘 → 解压 → 写槽 → 升级页进度）；**云端下载强制整包 Ed25519 验签**，**主机 `make upgrade` 保持开发者免签**（信任本机构建），并以 **`tar.gz`** 降低传输流量。

## What Changes

- 抽象 **`packages/cyber_ota`**：manifest、版本比较、包传输、解压、apply、进度；**仅 CloudIngress 强制整包验签**。
- **统一 staged apply**：云与 `make upgrade` 共用落盘/解压/写槽；仅来源与是否验签不同。
- **BREAKING（相对当前 stream `make upgrade`）**：主机改为上传 OTA `tar.gz` 再设备解压写盘；**取消**默认 SSH 流式直写。主机路径**不**要求 `.sig`。
- **`make ota-package`**：打 `tar.gz`；为云/`make publish` 产出旁路 `.sig`；`make upgrade` 以前置取得归档（可忽略签名）。
- **进度 UX**：传输统一为升级页「下载」；云含验签阶段，主机跳过。
- **安全升级**：收工直达专用升级页。
- 更新规划 P4.8：staged 统一；**云验签 / 主机免签**。
- 接线 Settings / 云 WS OTA 命令（产品路径验签）。

## Capabilities

### New Capabilities

- `cyber-ota`: 编排 API；HostUpload 免签；Cloud 强制验签；进度阶段按 ingress 区分。
- `ota-package-signing`: `tar.gz` 打包；整包 Ed25519 供云/publish；设备公钥；主机 upgrade **不**依赖验签。
- `ota-upgrade-ui`: 安全收工直达升级页；下载/（云）验签/解压/烧录进度。

### Modified Capabilities

- `ab-firmware-slots`: 默认全系统升级改为 staged；**云路径**整包验签；**主机上传路径**免签仍写非活动分区；保留 A/B 不变量。
- `host-remote-upgrade`: `make upgrade` 前置 `ota-package`（或外部包），上传 `tar.gz`（无强制 `.sig`），触发设备解压写盘。
- `device-cloud-websocket`: 真实 OTA 命令；云下载会话含验签。
- `settings-ui`: 检查更新接到 `cyber_ota`。
- `buildroot-lws-hmi-image`: 嵌入 OTA 公钥；helper 支持云验签门闩与主机免签 apply。

## Impact

- **Dart**：`packages/cyber_ota/`；App 编排；与控制板升级互斥。
- **Host**：`make ota-package`、`upgrade-remote.sh`（上传归档、不传签）；publish 另传 `.sig`。
- **Board**：`/userdata/ota/` staged apply；云路径验签。
- **Docs**：规划、storage-layout、README。
- **非目标**：不远程写 uboot/GPT；不做 App-only OTA；主机 upgrade 不升为产品验签。
