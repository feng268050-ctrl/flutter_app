## Context

控制卡固件（`LSW01H####S####.bin`）目前仅经 `lws-app` OTA zip 解压后，由 `UpgradeActivity` 调用 `BinUtil.binFileConvert` → `ControllerUpgradeHandler.sendControllerUpgradeInfo` 经 Modbus 刷写。AI 库与工艺库已在构建期写入 `assets/`、`BundledLibraryBootstrap` 于启动导入；固件仍依赖网络 OTA 与用户进入升级页，与 `make install` 等离线部署脱节。

固件与 AI/工艺库本质不同：更新对象是 **外设控制卡**，依赖 Modbus 连接、`DeviceStatus` 轮询、异步分包传输（可达数分钟），且刷写失败或断电有风险。现有 OTA 路径要求用户确认「保持通电、勿操作」。

仓库已有 `firmware/` 目录（例：`LSW01H1000S1013.bin`，约 63KB），`Makefile` 的 `FIRMWARE_BIN` 用于 `make pack`，与 APK 构建未关联。

## Goals / Non-Goals

**Goals:**

- 构建时将 `firmware/` 下符合命名约定的 `.bin` 拷贝到 `app/src/main/assets/firmware/`，随 APK 打包；`assets/firmware/` 不提交 Git。
- 新增 `BundledFirmwareBootstrap`：**仅在首页 `MainActivity`** 且 Modbus 可用、已取得有效 `DeviceStatus` 时，比较内置固件与控制卡 HW/SW；HW 匹配且 bundled SW **高于** 设备 SW 时 **弹窗提示**，用户确认后刷写。
- 复用 `BinUtil` / `ControllerUpgradeHandler` / `DeviceUpgradeEvent`；成功后更新 `DeviceInfo.firmwareVersion`；606（版本相同）静默跳过。
- 模拟器、Modbus 不可用、无 bundled 资产时安全跳过，不阻塞首页与其它界面。

**Non-Goals:**

- 修改 Modbus OTA 寄存器协议或 `ControllerUpgradeHandler` 分包逻辑。
- 用 SemVer 解析固件版本（固件沿用 `UpgradeFileReaderUtils` 文件名整数规则）。
- 从 Workers API 拉取固件 manifest（固件源为仓库本地 `firmware/`）。
- 替换或删除 `lws-app` OTA zip 中的 `.bin` 路径。
- **自动静默刷写**（无弹窗、无用户确认）。
- 工程师模式、`BuildConfig` 或其它开关绕过确认对话框。
- 在工程师模式、设置、监测等非首页界面检测或提示固件升级。

## Decisions

1. **构建源与触发点**
   - **选择**：Gradle `preBuild` 依赖新 task `bundleFirmwareAssets`：扫描 `firmware/*.bin`，校验 `LSW01H####S####.bin` 命名，清空并写入 `app/src/main/assets/firmware/`；若目录无合法 bin 则 warn 并跳过（不 fail build），便于无固件的开发机构建。
   - **理由**：固件已在仓库维护，`make pack` 同源；无需外网；体积极小。
   - **备选**：扩展 `fetchBundledLibraries` 从 Workers 拉固件 — 已排除（固件非云端库产物）。

2. **检测时机与界面范围（与 AI/工艺库分离）**
   - **选择**：**不**在 `LaserApplication` / `BundledLibraryBootstrap` 路径检测固件。由 `MainActivity` 在 `onResume`（或等价首页可见生命周期）调用 `BundledFirmwareBootstrap.checkAndPromptIfNeeded(Activity)`：若 Modbus 不可用或尚无有效 `DeviceStatus`，则本次跳过、不弹窗；用户离开首页再返回时可再次尝试。
   - **理由**：用户明确要求仅在首页提示；避免在其它界面打断操作；`sendControllerUpgradeInfo` 仍依赖 `DeviceStatus`。
   - **备选**：Application 级全局检测 — 已排除（不符合产品要求）。

3. **版本比较规则**
   - **选择**：从 assets 中唯一 `.bin` 文件名用 `UpgradeFileReaderUtils.getFileHardwareVersion` / `getFileSoftwareVersion`；与 `DeviceStatus.getHardwareVersion()` / `getSoftwareVersion()` 比较。HW 必须相等；SW bundled **>** device 才视为待升级。
   - **理由**：与 OTA 及 `ControllerUpgradeHandler` 一致。

4. **用户确认（唯一升级入口）**
   - **选择**：检测到待升级固件时，**必须**弹出 `GlobalDialogUtil`（或等价）对话框：说明版本跃迁与「保持通电、勿操作」；用户确认后调用 `BinUtil.binFileConvert`；取消则本次不刷写。用户再次进入首页且版本仍落后时 **可再次弹窗**（无静默自动刷写路径）。
   - **理由**：统一交互、降低误刷风险；符合「检测到新版本都弹窗」。
   - **备选**：工程师/BuildConfig 自动刷 — 已排除。

5. **升级过程与 UI**
   - **选择**：bundled 路径 **不** 启动完整 `UpgradeActivity`；首页或 Application 级 `EventBus` 订阅 `DeviceUpgradeEvent`（`MAIN_ORDERED`），刷写过程中展示轻量进度/状态；引入 `FirmwareUpgradeCoordinator` 互斥，避免与 OTA 并发刷写。
   - **理由**：用户留在首页上下文；复用事件语义。

6. **成功/失败持久化**
   - **选择**：`UPGRADE_SUCCESS` 时更新 `DeviceInfo.firmwareVersion`（与 `UpgradeActivity` 一致）。`606` 静默跳过。模拟器走 `isProbablyEmulator()` 同类逻辑跳过。

7. **临时文件**
   - **选择**：从 assets 拷贝到 `cacheDir/bundled-firmware-import.bin`，传给 `ControllerUpgradeDataCache`；结束后删除。

8. **与 `make pack` 一致性**
   - **选择**：`firmware/` 为单一事实来源；`Makefile` `FIRMWARE_BIN` 与构建 task 对齐。

## Risks / Trade-offs

- **[Risk] 用户长时间不回到首页** → 固件提示延迟；可接受（产品选择）。
- **[Risk] 首页弹窗时用户立即点其它入口** → 取消或确认前不启动刷写；确认后展示进行中状态。
- **[Risk] Modbus 未就绪时进首页** → 不弹窗，下次 `onResume` 再检。
- **[Risk] 与 OTA 同时触发** → `FirmwareUpgradeCoordinator` 互斥。
- **[Trade-off] 每次回首页可能重复弹窗（若未升级）** → 符合「有新版就提示」；升级成功后不再提示。

## Migration Plan

1. 实现 `bundleFirmwareAssets` 与 `.gitignore`。
2. 实现 `BundledFirmwareBootstrap` + 首页接线 + coordinator。
3. 更新 `docs/ota-upgrade-flow.md`。
4. 发布说明：安装新 APK 后，在首页可能看到固件升级提示。

## Open Questions

- 首页弹窗 UI 复用 OTA 文案资源还是新增 strings（实现时与现有 `GlobalDialogUtil` 对齐）。
- `Makefile` `FIRMWARE_BIN` 是否改为自动选取 `firmware/` 唯一 bin（tasks 阶段处理）。
