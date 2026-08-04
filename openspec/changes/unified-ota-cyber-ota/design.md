## Context

P2.5 已落地 A/B 槽位、misc try-boot、以及两套 apply：

| 路径 | 今日行为 | 问题 |
|------|----------|------|
| **Stream**（`make upgrade`） | SSH 直写非活动分区；免签；主机进度≈写盘 | 与产品信任模型不一致；无 HMI 烧录 UI |
| **Staged**（`ab-upgrade-apply.sh`） | `/userdata/ota/` 落盘 → digest/签 → `dd` | 产品云 OTA / HMI 编排尚未接上 |

规划文档原表述将 `make upgrade` 排除在签名门闩外。本变更将 **P4.8** 定义为**统一整机 OTA**：云下载与主机上传只是 **Ingress**，之后共用 `cyber_ota` + 板端 apply；传输阶段在升级页统一呈现为**下载进度**。

约束：不改 GPT / 不远程写 uboot；HMI 随 rootfs；私钥不上设备；Flutter API 3.24.4；`cyber_*` path 包模式对齐 `cyber_pm`。

## Goals / Non-Goals

**Goals:**

- 一条 **Apply 管线**：收包（zip）→ 解压 → 验签 → 写非活动分区（+ 可选 oem）→ arm try-boot → 重启 → confirm/rollback。
- **`packages/cyber_ota`**：manifest / 版本比较 / zip 传输 / 解压 / 验签 / apply / 进度事件，供 App、云命令、主机触发共用。
- **构建内置签名 + `make ota-package`**：分区 img 旁路 `*.img.sig`（Ed25519）；多个已签名产物打成一个 OTA zip；`make upgrade` / 未来 `make publish` 前置该目标；`uboot.img` 除外。
- **进度大统一**：云 HTTP 下载与 `make upgrade` SSH 上传，在 HMI 升级页都映射为 **transferring / 下载** 进度；随后同一页显示解压/验签/烧录。
- **安全升级**：apply 传输开始前停止作业并**直达升级页**（不经首页中转）；升级页无激光作业能力。
- 更新规划文档与 specs，使 `make upgrade` **纳入**验签。

**Non-Goals:**

- 远程改写 U-Boot / MiniLoader / GPT（仍 `make flash`）。
- 产品「仅推 App」OTA（`make push-app` 保持开发热路径）。
- 把 OTA 业务塞进 `cyber_hal`。
- 控制板 Modbus 固件 / 工艺库包升级（保持独立协调器；仅互斥整机 apply）。
- 完整实现云端 Worker / `make publish` 发布后台（本变更定义设备/主机契约与 **`ota-package` 前置**；云侧 API 形状对齐现有 WS/HTTP 约定即可）。

## Decisions

### 1. 统一 staged apply；废弃默认 stream 全系统路径；传输单元为 zip

**Choice:** 默认全系统升级（云与 `make upgrade`）一律：

1. 将 **一个 OTA zip**（内含所需 `*.img` + `*.img.sig` 及编排 `manifest.json`）置于 `/userdata/ota/`（下载或主机上传）；
2. 解压到 staging 目录；
3. `cyber_ota`（或等价板端 helper，由包编排调用）**验签全部将写入的 img**；
4. 再 `dd` 非活动 rootfs / 对应 FIT / 可选 oem；
5. 写进度到约定状态文件；arm try-boot；重启。

**BREAKING:** 取消「SSH stdin → 分区、免签」作为默认 `make upgrade`。

**为何 zip：** 多文件各自传输浪费连接与主机侧存储副本；单包压缩降低 userdata 暂存与链路流量；云与 make 共用同一制品形状，便于未来 `make publish` 直接上传该 zip。

**Alternatives:** 保留 stream 但主机先验签再流式写入（无完整落盘）。Rejected：烧录进度/断点/与云路径分叉，且难在 HMI 复用同一 apply 状态机。逐文件 scp 不打 zip。Rejected：与 publish/云制品不一致，流量与落盘更差。

**Optional escape:** 实现期可不提供免签旁路；若调试需要，仅文档化临时环境变量且默认关闭（规格上产品路径 MUST 验签）。

### 2. `cyber_ota` 包边界（类比 `cyber_pm`）

**Choice:** 纯 Dart path 包，**不是** HAL。

| API 面（概念） | 职责 |
|----------------|------|
| `OtaManifest` / fetch | 拉取并解析 manifest（版本、zip URL 或本地路径、尺寸） |
| `compareVersion` | 与设备当前 OS/HMI 版本比较，决定是否有更新 |
| `fetchPackage` | 网络下载 zip 到 `/userdata/ota/`，进度回调（下载） |
| `acceptHostTransfer` | 主机上传过程中消费传输字节进度，映射为同一 transferring 事件 |
| `extractPackage` | 解压 zip，得到 `*.img` + `*.sig` (+ manifest) |
| `verifyImages` | 对每个将写入的 img 用设备公钥验 `*.sig` |
| `applyImages` | 调用板端 apply（写分区），烧录进度回调 |
| `OtaSession` / `OtaProgress` | 阶段：`checking` → `transferring` → `extracting` → `verifying` → `writing` → `arming` → `rebooting` / `failed` |

Ingress 适配：

- **CloudIngress**：HTTP(S) 下载 zip；
- **HostUploadIngress**：主机 scp/rsync 上传 zip；App 在传开始前已进升级页，将主机/本地上报的字节进度映射为 `transferring`（下载语义）；
- **LocalStagingIngress**：测试/USB 已放好的 zip 或已解压目录。

板端低级 `dd` / misc 操作可继续落在 `/usr/libexec/hmi/ab-*.sh`；`cyber_ota` 负责编排、解压、验签（Dart 或调用 `openssl`/`signify` 风格工具）、进度聚合。验签实现优先复用 rootfs 已有加密工具，避免再拉大 Flutter 插件面。

### 3. 安全升级 UX：收工直达专用升级页（统一下载进度）

**Choice:** 整机 OTA（含 `make upgrade` 与云/Settings）在传输/写分区前进入 **安全态**，进度 UI 是 **专用升级页面**（全屏路由），不是压在快速/工程师/监视器作业页上的对话框。**不**再以「退回首页 → 再进升级页」为计划路径；收工后**直接导航到升级页**。

```text
触发（make upgrade 开始传包 / 云确认更新 / Settings）
    │
    ├─ 1. 安全收工：停止激光/焊接作业会话（关出光、结束进行中的 job）
    ├─ 2. 关闭工作页栈，直接进入专用升级页（OTA route）
    │       · 展示传输＝下载进度（云 HTTP 或 make 上传映射）
    │       · 解压 / 验签 / 烧录进度
    │       · 写盘中不可取消；无「开始焊接/出光」等作业入口
    └─ 3. apply 成功 → 请求重启；失败 → 可离开升级页并保持活动槽
```

**为何安全：** 升级页不挂载作业 UI / 不启动激光流程；进入前已收工。`make upgrade` 尤其可能在设备正作业时被开发者触发，因此 **MUST** 先收工再进升级页，避免边焊接边写 rootfs。

**为何映射上传→下载：** 产品语义只有「包正在到达设备」一种传输态；云与开发共用同一进度条文案与 `OtaProgress.transferring`，实现真正大统一。主机控制台仍可显示 SSH 上传百分比作开发者 echo。

- **云 / Settings**：检查更新可在 Settings；确认后同样走安全收工 → 升级页 → 下载 zip → 解压 → verify → apply。
- **`make upgrade`：** 前置 `make ota-package`；**开始上传 zip 前**写触发文件（对齐 `/run/hmi/upgrade-*.cmd`），HMI：**收工 → 升级页**并进入 `transferring`；主机上传时持续更新进度（状态文件或旁路通道）；传完后同一会话 `extracting` → `verifying` → `writing`。主机可轮询 progress 作次要 echo。
- 与控制板固件升级协调器互斥：整机 apply / 升级页活跃时拒绝其它固件写。

**Alternatives:** 仅模态弹窗盖在当前页上。Rejected：作业页仍可能持有出光状态机；专用页强制离开作业上下文更清晰。先回首页再进升级页。Rejected：多余中转，且 `make upgrade` 上传阶段无法立即占用统一进度 UI。

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
- `manifest.json`：版本、文件列表、可选尺寸；**不得**作为信任根（即使被篡改，缺签或错签仍拒绝写入）。zip 本身不要求额外整包签名——信任落在包内各 `*.img.sig`。
- **不**要求旁路 `.sha256` 作为授权门闩（验签已含完整性）。

构建：签名步骤挂在各 `build-*` 成功写出 img 之后；缺私钥时行为需明确——建议 **CI/发布失败**；本地开发可生成 repo-local **dev key**（文档警告：仅实验室，与量产公钥不同则量产板拒签）。

### 5. `make ota-package` 与 `make upgrade` 新序列

**`make ota-package`：**

1. 解析 `APP=` / 本次要包含的分区集合（默认：inactive FIT + rootfs [+ oem]；OEM_ONLY 仅 oem；云/publish 可用双 FIT 等变体由 manifest 描述）。
2. 确认各 `*.img` + `*.img.sig` 存在；缺则失败。
3. 写入/嵌入编排 `manifest.json`，将文件压缩为单一 zip（如 `output/firmware/<APP>/ota-package.zip` 或文档化路径）。
4. 该 zip 亦为未来 **`make publish`** 的上传制品前置。

**`make upgrade`：**

1. **自动执行** `make ota-package`（或等价依赖，确保 zip 新鲜）。
2. 主机解析 inactive letter / 可选 oem（保留 `OEM_IMG` / `OEM_ONLY` 语义）并与包内容一致。
3. **触发 HMI 进入升级页**（安全收工 + `transferring`）。
4. 上传 **zip** 到 `/userdata/ota/`（主机 echo 上传进度；设备映射为下载进度）。
5. 设备解压 → `cyber_ota` 验签+写入+arm（推荐 **HMI 编排**；主机仅打包+上传+触发）。
6. 重启请求后主机即可返回（与今日「arm-reboot 即返回」一致）；不在主机侧等健康确认。

**OEM_ONLY：** 包内仅 oem；只验签/写 oem，plain reboot，不 arm A/B。

### 6. 云 / Settings 接线

- Settings「检查更新」→ `cyber_ota` check（manifest）→ 有更新则确认 → **安全收工 → 升级页** → 下载 zip → extract → verify → apply。
- WS：`command.check_update` / `command.update_system` 走同一会话（update 同样经安全收工 + 升级页）；`device.update_progress` 映射 `OtaProgress`（替代 `ota_not_supported`）。
- 自动检查：复用 Settings 开关；仅 check，不自动写盘除非产品另定（默认 **不自动 apply**，需确认——与 lws-ui 对齐时在实现任务中核对）。

### 7. 文档与规划

- `docs/flutter-linux-hmi-plan.md` P4.8 已改为「统一整机 OTA」（本变更一部分）。
- `docs/storage-layout.md` / README：删除「stream vs OTA 分叉」的默认描述，改为「统一 staged + 验签；Ingress = 云下载 zip 或 make 上传 zip；传输进度在升级页统一为下载」。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| zip 落盘+解压比 stream 多占用 userdata 与时间 | 接受；压缩降低流量；传完可删 zip 只留解压产物，或边验签边删临时（可选优化） |
| 无私钥时本地 `build-*` 失败 | 提供 `make ota-dev-keys` + 文档；量产板不用 dev 公钥 |
| HMI 崩溃导致 apply 中断 | apply 脚本可在无 HMI 时由主机直接调用同一 helper；升级页为 UX，写盘权威在 helper；中断不 arm |
| 双 FIT 全打进包浪费 | `make upgrade` 的 ota-package 只打 inactive FIT；云/publish manifest 可按槽裁剪 |
| 与旧板 stream-only 不兼容 | 需先 rootfs/App 含 `cyber_ota` + 新 helper；文档写明升级桥梁（一次旧 stream 或 flash） |
| 升级页阻塞操作 | 写盘中禁止取消离开写流程；失败可退出升级页并保留活动槽 |
| `make upgrade` 时设备正在出光 | 触发后强制收工再导航升级页；未完成安全收工则不得开始写分区（传输可在收工完成后开始） |
| 上传已开始但 HMI 未进页 | 触发文件必须在首字节上传前被 HMI ack（或短超时重试）；否则失败退出 |

## Migration Plan

1. 落地签名工具链 + 公钥进 overlay；`build-*` 产出 `.sig`；落地 `make ota-package`。
2. 落地 `cyber_ota` + 板端 progress + 安全收工/专用升级页（可先 LocalStaging 测）。
3. 改 `upgrade-remote.sh`：依赖 ota-package、上传 zip、上传前触发升级页；更新 README / AGENTS / storage-layout。
4. 接 Settings + 云 WS。
5. 归档 OpenSpec；规划表 P4.8 标完成需另一次验收。

**Rollback：** 恢复 stream 脚本仅作紧急开发手段时须显式文档，且不得标为产品路径。

## Open Questions

1. **自动 apply：** 「自动检查更新」勾选后是否允许无人确认写盘？（建议默认否，仅提示。）
2. **验签实现：** Dart 纯实现 vs 调用 rootfs `openssl pkeyutl` / 小 C helper——实现期按包体积与 FIPS 需求选定，规格只要求 Ed25519 语义。
3. **工厂尚未灌公钥的板：** 首次带签升级前是否允许一次性 flash 带公钥的 rootfs——是，走正常 `build-rootfs`/`flash`/`upgrade` 桥梁。
4. **云 manifest URL / Worker 契约：** 与 lws-ui OTA API 字段对齐细节，实现切片前对照 `network-api-reference` 定一版设备侧 schema（含 zip URL）。
5. **zip 压缩级别 / 工具：** `zip` vs `tar.gz`——规格要求单一归档包即可；实现期选 rootfs 已有解压工具链。
