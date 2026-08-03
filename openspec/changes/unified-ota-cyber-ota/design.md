## Context

P2.5 已落地 A/B 槽位、misc try-boot、以及两套 apply：

| 路径 | 今日行为 | 问题 |
|------|----------|------|
| **Stream**（`make upgrade`） | SSH 直写非活动分区；免签；主机进度≈写盘 | 与产品信任模型不一致；无 HMI 烧录 UI |
| **Staged**（`ab-upgrade-apply.sh`） | `/userdata/ota/` 落盘 → digest/签 → `dd` | 产品云 OTA / HMI 编排尚未接上 |

规划文档原表述将 `make upgrade` 排除在签名门闩外。本变更将 **P4.8** 定义为**统一整机 OTA**：云下载与主机上传只是 **Ingress**，之后共用 `cyber_ota` + 板端 apply。

约束：不改 GPT / 不远程写 uboot；HMI 随 rootfs；私钥不上设备；Flutter API 3.24.4；`cyber_*` path 包模式对齐 `cyber_pm`。

## Goals / Non-Goals

**Goals:**

- 一条 **Apply 管线**：验签 → 写非活动分区（+ 可选 oem）→ arm try-boot → 重启 → confirm/rollback。
- **`packages/cyber_ota`**：manifest / 版本比较 / 下载 / 验签 / apply / 进度事件，供 App、云命令、主机触发共用。
- **构建内置签名**：分区 img 旁路 `*.img.sig`（Ed25519）；`uboot.img` 除外。
- **进度**：Ingress（下载或主机上传）有进度；Ingress 完成后 HMI **专用升级页**显示烧录进度；`make upgrade` 主机显示上传进度。
- **安全升级**：apply 前停止作业并回首页，再进升级页；升级页无激光作业能力。
- 更新规划文档与 specs，使 `make upgrade` **纳入**验签。

**Non-Goals:**

- 远程改写 U-Boot / MiniLoader / GPT（仍 `make flash`）。
- 产品「仅推 App」OTA（`make push-app` 保持开发热路径）。
- 把 OTA 业务塞进 `cyber_hal`。
- 控制板 Modbus 固件 / 工艺库包升级（保持独立协调器；仅互斥整机 apply）。
- 实现阶段的云端 Worker 发布后台（本变更定义设备/主机契约；云侧 API 形状对齐现有 WS/HTTP 约定即可）。

## Decisions

### 1. 统一 staged apply；废弃默认 stream 全系统路径

**Choice:** 默认全系统升级（云与 `make upgrade`）一律：

1. 将所需 `*.img` + `*.img.sig`（及编排 `manifest.json`）置于 `/userdata/ota/`；
2. `cyber_ota`（或等价板端 helper，由包编排调用）**验签全部将写入的 img**；
3. 再 `dd` 非活动 rootfs / 对应 FIT / 可选 oem；
4. 写进度到约定状态文件；arm try-boot；重启。

**BREAKING:** 取消「SSH stdin → 分区、免签」作为默认 `make upgrade`。

**Alternatives:** 保留 stream 但主机先验签再流式写入（无完整落盘）。Rejected：烧录进度/断点/与云路径分叉，且难在 HMI 复用同一 apply 状态机。

**Optional escape:** 实现期可不提供免签旁路；若调试需要，仅文档化临时环境变量且默认关闭（规格上产品路径 MUST 验签）。

### 2. `cyber_ota` 包边界（类比 `cyber_pm`）

**Choice:** 纯 Dart path 包，**不是** HAL。

| API 面（概念） | 职责 |
|----------------|------|
| `OtaManifest` / fetch | 拉取并解析 manifest（版本、各分区 URL 或本地路径、尺寸） |
| `compareVersion` | 与设备当前 OS/HMI 版本比较，决定是否有更新 |
| `fetchImages` | 网络下载到 `/userdata/ota/`，进度回调 |
| `verifyImages` | 对每个将写入的 img 用设备公钥验 `*.sig` |
| `applyImages` | 调用板端 apply（写分区），烧录进度回调 |
| `OtaSession` / `OtaProgress` | 阶段：`checking` → `transferring` → `verifying` → `writing` → `arming` → `rebooting` / `failed` |

Ingress 适配：

- **CloudIngress**：HTTP(S) 下载；
- **HostUploadIngress**：文件已由主机 scp/rsync 落盘；App 只跑 verify+apply；
- **LocalStagingIngress**：测试/USB 已放好的目录。

板端低级 `dd` / misc 操作可继续落在 `/usr/libexec/hmi/ab-*.sh`；`cyber_ota` 负责编排、验签（Dart 或调用 `openssl`/`signify` 风格工具）、进度聚合。验签实现优先复用 rootfs 已有加密工具，避免再拉大 Flutter 插件面。

### 3. 安全升级 UX：收工回首页 + 专用升级页

**Choice:** 整机 OTA（含 `make upgrade` 与云/Settings）在写分区前进入 **安全态**，进度 UI 是 **专用升级页面**（全屏路由），不是压在快速/工程师/监视器作业页上的对话框。

```text
触发（主机上传完成 / 云确认更新 / Settings）
    │
    ├─ 1. 安全收工：停止激光/焊接作业会话（关出光、结束进行中的 job）
    ├─ 2. 导航：关闭工作页栈，退回首页（Home）
    ├─ 3. 进入专用升级页（OTA route）
    │       · 展示传输（若仍在下）/ 验签 / 烧录进度
    │       · 写盘中不可取消；无「开始焊接/出光」等作业入口
    └─ 4. apply 成功 → 请求重启；失败 → 可离开升级页并保持活动槽
```

**为何安全：** 升级页不挂载作业 UI / 不启动激光流程；进入前已收工。`make upgrade` 尤其可能在设备正作业时被开发者触发，因此 **MUST** 先收工回首页再进升级页，避免边焊接边写 rootfs。

- **云 / Settings**：检查更新可在 Settings；确认后同样走安全收工 → 升级页（下载进度可在升级页内显示）。
- **`make upgrade`**：主机显示**上传**进度；上传结束后写触发文件（对齐 `/run/hmi/upgrade-*.cmd`）；HMI watcher：**收工 → 首页 → 升级页** → `OtaSession`（HostUploadIngress）烧录进度。主机可轮询 progress 作次要 echo。
- 与控制板固件升级协调器互斥：整机 apply / 升级页活跃时拒绝其它固件写。

**Alternatives:** 仅模态弹窗盖在当前页上。Rejected：作业页仍可能持有出光状态机；专用页强制离开作业上下文更清晰。

### 4. 签名模型

**Choice:** 每个分区完整 img **旁路** Ed25519 签名（hash-then-sign over full image bytes）→ `image.img` + `image.img.sig`。

| 产物 | 签名 |
|------|------|
| `boot.img` / `boot_b.img` | 是（`build-kernel`） |
| `rootfs.img` | 是（`build-rootfs`） |
| `oem.img` | 是（`build-oem`） |
| `uboot.img` / MiniLoader | **否**（供应商；仅 `make flash`） |

- 私钥：发布机 / CI secret / HSM；路径由 `OTA_SIGNING_KEY`（或文档化等价）注入；**不进 git**。
- 公钥：嵌入 rootfs（如 `/etc/hmi/ota-ed25519.pub`）；开发与量产可用不同密钥对，但设备只信镜像内公钥。
- `manifest.json`：版本、文件列表、可选尺寸；**不得**作为信任根（即使被篡改，缺签或错签仍拒绝写入）。
- **不**要求旁路 `.sha256` 作为授权门闩（验签已含完整性）。

构建：签名步骤挂在各 `build-*` 成功写出 img 之后；缺私钥时行为需明确——建议 **CI/发布失败**；本地开发可生成 repo-local **dev key**（文档警告：仅实验室，与量产公钥不同则量产板拒签）。

### 5. `make upgrade` 新序列

1. 主机解析 `APP=` / inactive letter / 可选 oem（保留 `OEM_IMG` / `OEM_ONLY` 语义）。
2. 确认本地存在对应 **已签名** `*.img` + `*.sig`；缺签则失败并提示重建。
3. 上传到 `/userdata/ota/`（显示上传进度）；只传本次需要的文件（如 inactive FIT + rootfs [+ oem]；云路径可能传双 FIT，apply 仍只写 inactive）。
4. 写 apply 触发；HMI：**安全收工 → 回首页 → 专用升级页**，再由 `cyber_ota` 验签+写入+arm（推荐 **HMI 编排**；主机仅上传+触发）。
5. 重启请求后主机即可返回（与今日「arm-reboot 即返回」一致）；不在主机侧等健康确认。

**OEM_ONLY：** 只上传/验签/写 oem，plain reboot，不 arm A/B。

### 6. 云 / Settings 接线

- Settings「检查更新」→ `cyber_ota` check（manifest）→ 有更新则确认 → **安全收工 → 升级页** → fetch → verify → apply。
- WS：`command.check_update` / `command.update_system` 走同一会话（update 同样经安全收工 + 升级页）；`device.update_progress` 映射 `OtaProgress`（替代 `ota_not_supported`）。
- 自动检查：复用 Settings 开关；仅 check，不自动写盘除非产品另定（默认 **不自动 apply**，需确认——与 lws-ui 对齐时在实现任务中核对）。

### 7. 文档与规划

- `docs/flutter-linux-hmi-plan.md` P4.8 已改为「统一整机 OTA」（本变更一部分）。
- `docs/storage-layout.md` / README：删除「stream vs OTA 分叉」的默认描述，改为「统一 staged + 验签；Ingress = 云或 make upload」。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 上传+落盘比 stream 多一次 userdata 占用与时间 | 接受；大 rootfs 需确保 userdata 空间；可传完一镜像验签一镜像再删临时以省空间（可选优化） |
| 无私钥时本地 `build-*` 失败 | 提供 `make ota-dev-keys` + 文档；量产板不用 dev 公钥 |
| HMI 崩溃导致 apply 中断 | apply 脚本可在无 HMI 时由主机直接调用同一 helper；升级页为 UX，写盘权威在 helper；中断不 arm |
| 双 FIT 全传浪费带宽 | `make upgrade` 只传 inactive FIT；云 manifest 可按槽裁剪 |
| 与旧板 stream-only 不兼容 | 需先 rootfs/App 含 `cyber_ota` + 新 helper；文档写明升级桥梁（一次旧 stream 或 flash） |
| 升级页阻塞操作 | 写盘中禁止取消离开写流程；失败可退出升级页并保留活动槽 |
| `make upgrade` 时设备正在出光 | 触发后强制收工再导航；未完成安全收工则不得开始写分区 |

## Migration Plan

1. 落地签名工具链 + 公钥进 overlay；`build-*` 产出 `.sig`。
2. 落地 `cyber_ota` + 板端 progress + 安全收工/专用升级页（可先 LocalStaging 测）。
3. 改 `upgrade-remote.sh` 为上传+触发；更新 README / AGENTS / storage-layout。
4. 接 Settings + 云 WS。
5. 归档 OpenSpec；规划表 P4.8 标完成需另一次验收。

**Rollback：** 恢复 stream 脚本仅作紧急开发手段时须显式文档，且不得标为产品路径。

## Open Questions

1. **自动 apply：** 「自动检查更新」勾选后是否允许无人确认写盘？（建议默认否，仅提示。）
2. **验签实现：** Dart 纯实现 vs 调用 rootfs `openssl pkeyutl` / 小 C helper——实现期按包体积与 FIPS 需求选定，规格只要求 Ed25519 语义。
3. **工厂尚未灌公钥的板：** 首次带签升级前是否允许一次性 flash 带公钥的 rootfs——是，走正常 `build-rootfs`/`flash`/`upgrade` 桥梁。
4. **云 manifest URL / Worker 契约：** 与 lws-ui OTA API 字段对齐细节，实现切片前对照 `network-api-reference` 定一版设备侧 schema。
