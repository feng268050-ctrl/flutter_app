## Context

P2.5 已落地 A/B 槽位、misc try-boot、以及两套 apply：

| 路径 | 今日行为 | 问题 |
|------|----------|------|
| **Stream**（`make upgrade`） | SSH 直写非活动分区；免签；主机进度≈写盘 | 与产品信任模型不一致；无 HMI 烧录 UI |
| **Staged**（`ab-upgrade-apply.sh`） | `/userdata/ota/` 落盘 → digest/签 → `dd` | 产品云 OTA / HMI 编排尚未接上 |

规划文档原表述将 `make upgrade` 排除在签名门闩外。本变更将 **P4.8** 定义为**统一整机 staged OTA**：云下载与主机上传共用落盘/解压/写槽管线与升级页进度；**仅云端（产品）下载路径强制整包 Ed25519 验签**；**主机 `make upgrade` 为开发者可信路径，不验签**。

约束：不改 GPT / 不远程写 uboot；HMI 随 rootfs；私钥不上设备；Flutter API 3.41.9；`cyber_*` path 包模式对齐 `cyber_pm`。

## Goals / Non-Goals

**Goals:**

- 一条 **Apply 管线（staged）**：收包（`tar.gz`）→（**云路径：** 整包验签）→ 解压 → 写非活动分区（+ 可选 oem）→ arm try-boot → 重启 → confirm/rollback。
- **`packages/cyber_ota`**：manifest / 版本比较 / 包传输 /（云）整包验签 / 解压 / apply / 进度事件；主机上传与云下载共用传输/解压/写盘编排。
- **`make ota-package`**：将本次所需分区 `*.img` + 编排 `manifest.json` 打成 **`tar.gz`**；为云/publish 产出旁路 `.sig`；`make upgrade` / 未来 `make publish` 以前置该目标取得归档（upgrade **不依赖**验签）。
- **进度大统一**：云 HTTP 下载与 `make upgrade` SSH 上传，在 HMI 升级页都映射为 **transferring / 下载**；云路径随后显示验签/解压/烧录，主机路径显示解压/烧录（跳过验签阶段）。
- **安全升级**：传输开始前停止作业并**直达升级页**；升级页无激光作业能力。
- 更新规划文档与 specs：`make upgrade` 纳入 **staged 管线**，但 **不**纳入产品验签门闩。

**Non-Goals:**

- 远程改写 U-Boot / MiniLoader / GPT（仍 `make flash`）。
- 产品「仅推 App」OTA（`make push-app` 保持开发热路径）。
- 把 OTA 业务塞进 `cyber_hal`。
- 控制板 Modbus 固件 / 工艺库包升级（保持独立协调器；仅互斥整机 apply）。
- 完整实现云端 Worker / `make publish` 发布后台（本变更定义设备/主机契约与 **`ota-package` 前置**）。
- 对各分区 `*.img` 再做旁路签名。
- 要求主机 `make upgrade` 上传或校验 `.sig`。

## Decisions

### 1. 统一 staged apply；废弃默认 stream；传输单元为 `tar.gz`

**Choice:** 云与 `make upgrade` 一律 **staged 收包**，信任按 Ingress 分流：

**共用：** 将 OTA **`tar.gz`** 置于 `/userdata/ota/` → 解压 → `dd` 非活动分区 / 可选 oem → arm try-boot → 重启。

| Ingress | 验签 |
|---------|------|
| **CloudIngress**（Settings / 云下载） | **必须** Ed25519 整包验签（归档 + `.sig`），通过后再解压写盘 |
| **HostUploadIngress**（`make upgrade`） | **不验签**；只上传 `tar.gz`，解压后写盘 |
| **LocalStagingIngress** | 默认同主机（免签），除非显式要求验签 |

**BREAKING:** 取消「SSH stdin → 分区」作为默认 `make upgrade`（改为上传包 + 设备解压写盘）。主机路径**保持开发者免签**，不升为产品验签。

**为何 `tar.gz`：** Linux/嵌入式惯例；与 zip 实测体积几乎相同（≈186 MB vs 逻辑 ≈697 MB）。

**为何云整包签、主机免签：** 产品威胁模型在云分发边界；日常 `make upgrade` 信任本机构建，避免强制本地钥。RockUSB / `make flash` 仍免签。

**Alternatives rejected:** 保留 stream（无统一升级页）；主机也强制验签（开发摩擦）；逐 img 签 / zip（已否决）。

### 2. `cyber_ota` 包边界（类比 `cyber_pm`）

**Choice:** 纯 Dart path 包，**不是** HAL。

| API 面 | 职责 |
|--------|------|
| `OtaManifest` / fetch | 云 manifest（版本、`tar.gz` URL、`.sig` URL） |
| `compareVersion` | 版本比较 |
| `fetchPackage` | 云下载 `tar.gz` + `.sig` |
| `acceptHostTransfer` | 主机上传进度 → transferring（无签） |
| `verifyPackage` | **仅云路径**整包验签 |
| `extractPackage` / `applyImages` | 解压与写盘 |
| `OtaProgress` | 云：`transferring → verifying → extracting → writing`；主机：`transferring → extracting → writing` |

验签实现优先复用 rootfs 已有工具；板端 `dd` 仍可落在 `ab-*.sh`。

### 3. 安全升级 UX：收工直达专用升级页（统一下载进度）

**Choice:** 整机 OTA（含 `make upgrade` 与云/Settings）收工后**直达专用升级页**（非作业页弹窗、不经首页）。

```text
触发 → 安全收工 → 升级页（下载进度）→ 云:验签 / 主机:跳过 → 解压 → 烧录 → 重启或失败
```

- **云 / Settings：** 下载 → verify → extract → apply。
- **`make upgrade`：** 前置 `ota-package`（或 `UPGRADE_PACKAGE=`）；上传 **`tar.gz` only**；设备 extract → apply（**不** verify）。
- 与控制板固件升级协调器互斥。

### 4. 签名模型（整包旁路 Ed25519 — 云/publish）

**Choice:** 对 **`make ota-package` 产出的完整 `tar.gz`** hash-then-sign → `package.tar.gz` + `package.tar.gz.sig`，供 **云下载与 `make publish`**。包内 img 不单独签。

| 路径 | 是否要求 `.sig` |
|------|-----------------|
| 云 OTA / Settings / WS update | **是**（设备验签） |
| `make publish` | **是**（上传归档 + `.sig`） |
| `make upgrade`（SSH 上传） | **否** |
| 包内各 `*.img` / uboot | **否** |

- 私钥仅发布机/HSM；公钥在设备 **`/etc/ota/ed25519.pub`**（平台级路径，**不**放 `/etc/hmi/`——HMI 只是界面 App，未来可有独立升级 App 共用此钥）。
- 云 `sha512` 仅辅助传输；**不能**替代 Ed25519 作产品写盘授权。
- `make ota-package`：始终打 `tar.gz`；有 `OTA_SIGNING_KEY` 时写 `.sig`（publish/云需要）；**本地仅 `make upgrade` 时可在无私钥时只出归档**（或仍出签但 upgrade 忽略）。**Publish/CI 缺钥必须失败。**

**云验签顺序：** 先验完整归档，再解压。

### 5. `make ota-package` 与 `make upgrade` 新序列

**`make ota-package`：** 选成员 → 打 `tar.gz` →（若配置了签名钥）写 `.sig` → 供 upgrade/publish。

**`make upgrade`（SSH）：**

1. 取得归档（默认跑 `ota-package`，或见 `upgrade-package-env` 的 `UPGRADE_PACKAGE=`）。
2. 触发升级页 → 上传 **`tar.gz`（不传 `.sig`）** → 设备解压写盘 → arm-reboot。
3. **不**在设备上做 Ed25519。

**OEM_ONLY：** 包内仅 oem；主机路径免签写 oem + plain reboot。

### 6. 云 / Settings 接线

- Settings / WS：`check_update` / `update_system` → 安全收工 → 升级页 → **下载 + 验签** → 解压写盘。
- 自动检查默认不自动 apply（建议）。

### 7. 文档与规划

- P4.8：staged 统一；**云验签、主机免签**；`tar.gz`。
- storage-layout / README：stream 默认退役；写明信任分流。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 主机免签被误当成产品安全 | 文档明确：仅开发；云路径强制验签 |
| 落盘+解压占 userdata | 接受；压缩降流量 |
| 无私钥时 publish 失败 | 预期；本地 upgrade 仍可用无签归档 |
| HMI 崩溃中断 apply | helper 可独立写盘；中断不 arm |
| 双 FIT 浪费 | upgrade 包只打 inactive FIT；RockUSB/publish 可变体 |

## Migration Plan

1. `ota-package`（`tar.gz`；签给云/publish）+ 公钥 overlay。
2. `cyber_ota` + 升级页；主机上传免签路径先通。
3. 改 `upgrade-remote.sh`：上传归档、触发升级页（不传签）。
4. 接 Settings + 云 WS（强制验签）。
5. 归档 OpenSpec。

**Rollback：** stream 仅紧急开发手段，不得标产品路径。

## Open Questions

1. **自动 apply：** 默认否，仅提示。
2. **验签实现：** Dart vs openssl helper。
3. **工厂无公钥板：** 先 flash 带公钥 rootfs。
4. **云 `.sig` 发现：** `url + ".sig"` vs `sig_url`。
5. ~~zip vs tar.gz~~：**已决** `tar.gz`。
6. ~~逐 img vs 整包签~~：**已决** 整包（云）。
7. ~~主机是否验签~~：**已决** 否；仅云。
