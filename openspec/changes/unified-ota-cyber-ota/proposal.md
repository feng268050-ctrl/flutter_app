## Why

P2.5 已交付 A/B 槽位与 `make upgrade`，但开发流式写分区与未来云 OTA 的「落盘 → 验签 → apply」仍是两条路径：前者免签、无 HMI 烧录进度；后者尚未实现。产品需要**同一套**整机升级管线——无论镜像来自云下载还是主机 `make upgrade`——都走验签与写分区，并在 HMI 上展示进度；同时把签名前移到构建产物，避免发布后再手工补签。

## What Changes

- 抽象 **`packages/cyber_ota`**（path 包，非 HAL）：manifest 拉取与版本比较、OTA 包/镜像下载、逐分区 Ed25519 验签、写非活动分区、进度回调（传输 + 烧录）。
- **统一 apply**：云 OTA 与 `make upgrade` 仅镜像**来源**不同；落盘 `/userdata/ota/` 之后的验签 → 写槽 → try-boot / 回滚契约相同。
- **BREAKING（相对当前 stream-to-partition `make upgrade`）**：主机升级改为上传已签名 `*.img` + `*.img.sig`（及编排用 manifest），再触发与产品 OTA 相同的 staged apply；**取消**「SSH 流式直写分区、免签」作为默认全系统升级路径。
- **构建内置签名**：`build-kernel` / `build-rootfs` / `build-oem`（及产出对应分区 img 的同类目标）在发布产物旁写出 `*.img.sig`；`uboot.img` 仍为供应商提供、**不**纳入本仓库签名链。
- **进度 UX**：网络下载经 `cyber_ota` 回调推送进度；`make upgrade` 主机控制台显示**上传**进度；传输完成后设备进入 **专用升级页面** 显示验签/烧录进度（非作业页上的浮层弹窗）。
- **安全升级**：整机 apply 前进入安全态——停止当前激光/焊接作业会话、关闭相关工作页并退回首页，再进入专用升级页；该页不提供激光出光/作业入口，因此升级过程中不会进行激光作业。
- 更新主规划 `docs/flutter-linux-hmi-plan.md` §P4.8：明确 `make upgrade` 纳入验签门闩；`make push-app` 仍为免整机验签的开发热路径。
- 接线 Settings「检查更新」、云 WS `command.check_update` / `command.update_system` / `device.update_progress`（此前为 `ota_not_supported` 占位）。

## Capabilities

### New Capabilities

- `cyber-ota`: Dart `cyber_ota` 包契约——manifest、版本门控、下载/落盘、验签、apply、进度事件与错误码；App / 主机触发的编排共用同一语义。
- `ota-image-signing`: 构建期对分区 img（boot / boot_b / rootfs / oem 等）Ed25519 旁路签名、设备公钥布局、发布机私钥策略；排除 uboot。
- `ota-upgrade-ui`: 安全收工回首页、专用升级页、传输/烧录进度；与 Settings 检查更新、自动检查及 `make upgrade` 上传完成后的触发对齐；升级页禁止激光作业。

### Modified Capabilities

- `ab-firmware-slots`: 取消「stream apply 免签门闩」的产品/默认契约；全系统升级统一为 staged + 逐 img Ed25519 验签后再写非活动分区（保留 A/B / try-boot / userdata 不变量）。
- `host-remote-upgrade`: `make upgrade` 改为上传已签名产物 + 触发统一 apply；主机显示上传进度；不再以 stream-to-partition 为默认全系统路径。
- `device-cloud-websocket`: 实现真实 OTA 相关命令与 `device.update_progress`（替代 `ota_not_supported` 占位）。
- `settings-ui`: Device Information 的检查更新 / 自动检查接到 `cyber_ota`，不再仅 deferred/unavailable。
- `buildroot-lws-hmi-image`: rootfs 嵌入 OTA 验签公钥（及 apply 所需最小 helper）；与签名产物约定一致。

## Impact

- **Dart**：新建 `packages/cyber_ota/`；`app/lws_hmi` path 依赖；Settings / 云命令 / 上传完成 IPC 调用同一编排器；与现有控制板固件升级协调器互斥（不并发整机 apply）。
- **Host**：`scripts/upgrade-remote.sh`、Makefile `upgrade`、可选进度 UI；构建脚本在 `build-kernel` / `build-rootfs` / `build-oem` 链路上签名。
- **Board**：强化 `/userdata/ota/` staged apply + 烧录进度上报（供 HMI / 主机轮询）；设备公钥路径（如 `/etc/hmi/ota-ed25519.pub`）。
- **Docs**：`docs/flutter-linux-hmi-plan.md`（已在本变更中修订规划表述）、`docs/storage-layout.md`、README Make 命令说明。
- **非目标（本变更规划边界）**：不远程改写 U-Boot/MiniLoader/GPT；不做产品「仅推 App」通道；不把 Worker/云业务塞进 `cyber_hal`；控制板 Modbus 固件升级仍独立于整机 OTA。
