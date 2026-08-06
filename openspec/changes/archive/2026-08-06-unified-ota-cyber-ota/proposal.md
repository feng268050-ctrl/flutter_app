## Why

P2.5 已交付 A/B 槽位与 `make upgrade`，但开发流式写分区与未来云 OTA 的 staged apply 仍是两条路径：前者无统一 HMI 进度；后者尚未实现。产品需要**同一套 staged 管线**（落盘 → 验签 → 解压 → 写槽 → 升级页进度）；**云端下载与主机 USB-SSH/SSH `make upgrade` 均强制整包 Ed25519 验签**（`tar.gz` + `.sig`），并以 **`tar.gz`** 降低传输流量。

## What Changes

- 抽象 **`packages/cyber_ota`**：manifest、版本比较、包传输、**整包验签**、解压、apply、进度；Cloud 与 HostHttpIngress（host HTTP + 设备拉取）均验签。
- **统一 staged apply**：云与 `make upgrade`（SSH）共用落盘/验签/解压/写槽与升级页进度。
- **BREAKING（相对当前 stream `make upgrade`）**：主机改为临时 HTTP 服务 OTA `tar.gz` **与**旁路 `.sig`，设备下载后验签解压写盘；**取消**默认 SSH 流式直写。
- **`make ota-package`**：打 `tar.gz` + 旁路 `.sig`（需 `OTA_SIGNING_KEY`）；`make upgrade` / `make publish` 以前置取得归档与签名。
- **`UPGRADE_PACKAGE=`**：使用现成 `tar.gz` 时，**默认**在同目录查找同名 `.sig`（`<archive>.sig`）一并经 host HTTP 供设备下载；缺失则 SSH 路径失败。
- **进度 UX**：传输统一为升级页「下载」；随后验签 / 解压（归档字节）/ 烧录（每镜像 0–100%，文案区分 rootfs / kernel / oem）。
- **安全升级**：收工直达专用升级页。
- 更新规划 P4.8：staged 统一；**云与主机 SSH 均验签**（RockUSB `di` / `make flash` 仍免签）。
- 接线 Settings / 云 WS OTA 命令。

## Capabilities

### New Capabilities

- `cyber-ota`: 编排 API；Cloud 与 HostHttpIngress 均强制整包验签；进度含 verifying / extracting / writing。
- `ota-package-signing`: `tar.gz` 打包 + 整包 Ed25519；设备公钥；SSH upgrade / publish **均**依赖 `.sig`。
- `ota-upgrade-ui`: 安全收工直达升级页；下载/验签/解压/烧录进度。

### Modified Capabilities

- `ab-firmware-slots`: 默认全系统升级改为 staged；**云与主机 HTTP 拉取**均整包验签后写非活动分区（顺序：rootfs → backup → kernel FIT → oem）；保留 A/B 不变量。
- `host-remote-upgrade`: `make upgrade` 前置 `ota-package`（或 `UPGRADE_PACKAGE=`），host HTTP 服务 `tar.gz` **+** `.sig`，设备下载验签后解压写盘；`UPGRADE_PACKAGE` 默认同目录旁路 `.sig`。
- `device-cloud-websocket`: 真实 OTA 命令；云下载会话含验签。
- `settings-ui`: 检查更新接到 `cyber_ota`。
- `buildroot-lws-hmi-image`: 嵌入 OTA 公钥；board retainers + 验签门闩在 `cyber_ota`。

## Impact

- **Dart**：`packages/cyber_ota/`；App 编排；与控制板升级互斥。
- **Host**：`make ota-package`（归档+签）、`upgrade-remote.sh`（host HTTP + 设备拉取）；`UPGRADE_PACKAGE` 旁路同名 `.sig`。
- **Board**：`/userdata/ota/` staged apply；SSH 与云均验签。
- **Docs**：规划、storage-layout、README。
- **非目标**：不远程写 uboot/GPT；不做 App-only OTA；RockUSB `di` / `make flash` 不升为验签路径。
