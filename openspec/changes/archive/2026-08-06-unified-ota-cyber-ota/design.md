## Context

P2.5 已落地 A/B 槽位、misc try-boot、以及两套 apply：

| 路径 | 今日行为 | 问题 |
|------|----------|------|
| **Stream**（`make upgrade`） | SSH 直写非活动分区；免签；主机进度≈写盘 | 与产品信任模型不一致；无 HMI 烧录 UI |
| **Staged**（原 shell apply） | `/userdata/ota/` 落盘 → 签 → `dd` | **产品路径：`packages/cyber_ota`**；板端仅 `ab-preflight` + `ab-boot-confirm` |

本变更将 **P4.8** 定义为**统一整机 staged OTA**：云下载与主机 USB-SSH/SSH `make upgrade` 共用落盘/解压/写槽管线与升级页进度，且**均强制整包 Ed25519 验签**（设备下载 `tar.gz` + `.sig`）。RockUSB `di` / `make flash` 仍免签。

约束：不改 GPT / 不远程写 uboot；HMI 随 rootfs；私钥不上设备；Flutter API 3.41.9；`cyber_*` path 包模式对齐 `cyber_pm`。

## Goals / Non-Goals

**Goals:**

- 一条 **Apply 管线（staged）**：收包（`tar.gz` + `.sig`）→ **整包验签** → 解压 → 写非活动分区（+ 可选 oem）→ arm try-boot → 重启 → confirm/rollback。
- **`packages/cyber_ota`**：manifest / 版本比较 / 包传输 / 整包验签 / 解压 / apply / 进度事件；主机 host HTTP 拉取与云下载共用传输/验签/解压/写盘编排。
- **`make ota-package`**：将本次所需分区 `*.img` + 编排 `manifest.json` 打成 **`tar.gz`** 并产出旁路 `.sig`（需 `OTA_SIGNING_KEY`）；`make upgrade` / `make publish` 以前置该目标取得归档与签名。
- **`UPGRADE_PACKAGE=`**：现成归档时，**默认**在同目录查找同名 `.sig`（`<path>.sig`）与归档一并经 host HTTP 供设备下载；缺失则 SSH 失败。
- **进度大统一**：云 HTTP 下载与 `make upgrade` host HTTP 拉取，在 HMI 升级页都映射为 **transferring / 下载**，随后 **verifying → extracting（归档字节）→ writing（每镜像 0–100%）**。
- **安全升级**：传输开始前停止作业并**直达升级页**；升级页无激光作业能力。

**Non-Goals:**

- 远程改写 U-Boot / MiniLoader / GPT（仍 `make flash`）。
- 产品「仅推 App」OTA（`make push-app` 保持开发热路径）。
- 把 OTA 业务塞进 `cyber_hal`。
- 控制板 Modbus 固件 / 工艺库包升级（保持独立协调器；仅互斥整机 apply）。
- 完整实现云端 Worker / `make publish` 发布后台（本变更定义设备/主机契约与 **`ota-package` 前置**）。
- 对各分区 `*.img` 再做旁路签名。
- RockUSB Loader `di` / `make flash` 升为验签路径。

## Decisions

### 1. 统一 staged apply；废弃默认 stream；传输单元为 `tar.gz`；SSH 亦验签

**Choice:** 云与 `make upgrade`（USB-SSH / SSH）一律 **staged 收包 + 整包验签**：

**共用：** 将 OTA **`tar.gz`** 与旁路 **`.sig`** 置于 `/userdata/ota/` → **Ed25519 验整包** → 解压 → `dd` 非活动分区 / 可选 oem → arm try-boot → 重启。

| Ingress | 验签 |
|---------|------|
| **CloudIngress**（Settings / 云下载） | **必须** Ed25519（归档 + `.sig`） |
| **HostHttpIngress**（`make upgrade`：host 临时 HTTP + 设备拉取） | **必须** Ed25519；设备从 host GET `tar.gz` + `.sig` |
| **LocalStagingIngress** | 默认要求验签（与上同）；仅测试可显式关闭 |
| **RockUSB `di` / `make flash`** | **不**验签（非本 staged 路径） |

**BREAKING:** 取消「SSH stdin → 分区」作为默认 `make upgrade`。SSH 路径**升为与云相同的验签门闩**（需 release 私钥打 `.sig`）。

**为何 `tar.gz`：** Linux/嵌入式惯例；压缩降流量。

**为何 SSH 也验签：** 与产品云路径同一信任根（设备 `/etc/ota/ed25519.pub`）；避免「开发免签通道」被误当成可绕过写盘授权。日常开发须配置 `OTA_SIGNING_KEY`（`make ota-release-keys`）或提供带旁路 `.sig` 的 `UPGRADE_PACKAGE`。

**Alternatives rejected:** 保留 stream；主机免签（已否决——易误用）；逐 img 签 / zip。

### 2. `cyber_ota` 包边界（类比 `cyber_pm`）

**Choice:** 纯 Dart path 包，**不是** HAL。

| API 面 | 职责 |
|--------|------|
| `OtaManifest` / fetch | 云 manifest（版本、`tar.gz` URL、`.sig` URL） |
| `compareVersion` | 版本比较 |
| `fetchPackage` | 云 / host HTTP 下载 `tar.gz` + `.sig` |
| `acceptHostTransfer` | （已废止）原 SSH 上传字节映射；现由 HostHttpIngress 走同一 download API |
| `verifyPackage` | **云与主机 HTTP** 整包验签（Dart `OtaVerify` → `openssl`） |
| `extractPackage` / `applyImages` | 解压与写盘（Dart `OtaExtract`/`OtaApply`：chunk → `tar -xz` / `dd of=` stdin；写盘顺序 rootfs → backup→kernel → oem） |
| `OtaProgress` | `transferring → verifying → extracting → writing`（云与主机 HTTP 相同；writing 每镜像独立 0–100%，message=`writing rootfs`/`writing kernel`/`writing oem`） |

**编排闭环在 `cyber_ota`：** `OtaSession` 直接 `Process` 调用 rootfs 工具（`openssl`、`tar`、`dd`、`systemctl`），并即时 `_emit` 到 `Stream<OtaProgress>`；云 WS / 升级页只订阅该流。调试写入 `/userdata/ota/ota.log`。板端 **不**保留 `ab-upgrade-apply.sh` / `ab-upgrade-stream.sh` / `ab-ota-verify.sh`。开机 confirm/rollback 用 `ab-boot-confirm.sh`；主机 preflight 用 `ab-preflight.sh`（共享 `ab-slot-lib.sh`）。

### 3. 安全升级 UX：收工直达专用升级页（统一下载进度）

**Choice:** 整机 OTA（含 `make upgrade` 与云/Settings）收工后**直达专用升级页**。

```text
触发 → 安全收工 → 升级页（下载）→ 验签 → 解压 → 烧录 → 重启或失败
```

- **云 / Settings：** 下载 `tar.gz`+`.sig` → verify → extract → apply。
- **`make upgrade`（SSH 控制面）：** 前置 `ota-package`（或 `UPGRADE_PACKAGE=` + 同目录 `.sig`）；host 临时 HTTP 托管归档；设备 **HTTP GET** `tar.gz` + `.sig`；verify → extract → apply。
- 与控制板固件升级协调器互斥。

### 4. 签名模型（整包旁路 Ed25519）

**Choice:** 对 **`make ota-package` 产出的完整 `tar.gz`** hash-then-sign → `package.tar.gz` + `package.tar.gz.sig`。

| 路径 | 是否要求 `.sig` |
|------|-----------------|
| 云 OTA / Settings / WS update | **是**（设备验签） |
| `make publish` | **是** |
| `make upgrade`（USB-SSH / SSH） | **是**（host HTTP 服务 + 设备下载 + 设备验签） |
| `UPGRADE_PACKAGE=`（SSH） | **是**（默认同目录 `<archive>.sig`） |
| RockUSB `di` / `make flash` | **否** |
| 包内各 `*.img` / uboot | **否** |

- 私钥仅发布机/HSM（`keys/ota/` gitignored 或 HSM）；公钥在设备 **`/etc/ota/ed25519.pub`**。
- 云 `sha512` 仅辅助传输；**不能**替代 Ed25519 作写盘授权。
- `make ota-package`：打 `tar.gz`；**缺 `OTA_SIGNING_KEY` 时失败**（SSH upgrade 与 publish 均需要 `.sig`）。可用 `REQUIRE_OTA_SIG=1` 显式强调；默认有钥即出签，无钥则非零退出。
- **`UPGRADE_PACKAGE=/path/foo.tar.gz`：** 默认查找 **`/path/foo.tar.gz.sig`**；存在则一并经 host HTTP 供设备下载；**缺失则 SSH `make upgrade` 失败**（RockUSB 仅需归档成员，不要求 `.sig`）。

**验签顺序：** 先验完整归档，再解压。

### 5. `make ota-package` 与 `make upgrade` 新序列

**`make ota-package`：** 选成员 → 打 `tar.gz` → 写 `.sig`（需钥）→ 供 upgrade/publish。

**`make upgrade`（SSH）：**

1. 取得归档 + `.sig`（默认跑 `ota-package`；或 `UPGRADE_PACKAGE=` + 同目录同名 `.sig`）。
2. 临时 HTTP 服务归档+`.sig` → 写 `upgrade-ota.cmd` → 设备下载 → 验签 → 解压写盘 → arm-reboot。
3. 缺签或验签失败：**不得**写分区。

**OEM_ONLY：** 包内仅 oem；仍须 `.sig`（SSH）；验签后写 oem + plain reboot。

### 6. 云 / Settings 接线

- Settings / WS：`check_update` / `update_system` → 安全收工 → 升级页 → **下载 + 验签** → 解压写盘。
- 自动检查默认不自动 apply。

### 7. 文档与规划

- P4.8：staged 统一；**云与主机 SSH 均验签**；`tar.gz`；RockUSB/`flash` 免签。
- storage-layout / README：stream 默认退役；写明 host HTTP + 设备下载 `.sig` 与 `UPGRADE_PACKAGE` 旁路发现。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 无私钥无法 `make upgrade`（SSH） | 预期；`make ota-release-keys` + `OTA_SIGNING_KEY`；或提供带 `.sig` 的 `UPGRADE_PACKAGE` |
| 落盘+解压占 userdata | 接受；压缩降流量 |
| HMI 崩溃中断 apply | helper 可独立写盘；中断不 arm |
| 双 FIT 浪费 | 包可含双 FIT；RockUSB/publish 可变体 |

## Migration Plan

1. `ota-release-keys` + `ota-package`（`tar.gz` + `.sig`）+ 公钥 overlay。
2. `cyber_ota` + 升级页；主机 HTTP 服务归档+签，设备下载并验签。
3. 改 `upgrade-remote.sh`：host HTTP + `UPGRADE_PACKAGE` 旁路 `.sig`、触发升级页。
4. 接 Settings + 云 WS。
5. 归档 OpenSpec。

**Rollback：** stream 仅紧急开发手段，不得标产品路径。

## Open Questions

1. ~~**自动 apply：**~~ **已决** 默认否：Settings / 自动检查仅提示；须操作员确认或云 `update_system` 再收工升级。
2. ~~**验签实现：**~~ **已决** Dart `OtaVerify` 调 `openssl`（SHA-512 + Ed25519 pkeyutl，公钥 `/etc/ota/ed25519.pub`）；主机 `scripts/ota-sign.sh`。
3. ~~**工厂无公钥板：**~~ **已决** 须先 `flash`/`upgrade` 带 `/etc/ota/ed25519.pub` 的 rootfs；无公钥 fail-closed。
4. ~~**云 `.sig` 发现：**~~ **已决** manifest 若含 `sig_url` 则用之，否则 `package_url + ".sig"`。
5. ~~zip vs tar.gz~~：**已决** `tar.gz`。
6. ~~逐 img vs 整包签~~：**已决** 整包。
7. ~~主机是否验签~~：**已决** **是**（USB-SSH / SSH `make upgrade`：host HTTP + 设备下载 + 设备验签）；RockUSB/`flash` 否。
8. ~~`UPGRADE_PACKAGE` 旁路 `.sig`~~：**已决** 默认同目录 `<archive>.sig`；SSH 缺失则失败。

## Device contracts (task 1.3)

See [`contracts.md`](contracts.md) for progress Stream / `ota.log`, host `/run/hmi/upgrade-ota.cmd`, per-image write + extract progress, and download-byte → transferring mapping.
