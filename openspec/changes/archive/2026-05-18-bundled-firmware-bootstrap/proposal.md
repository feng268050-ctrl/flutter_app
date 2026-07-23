## Why

控制卡固件目前仅能通过 OTA（下载 zip → 解压 `.bin` → Modbus 刷写）更新，与 `make install` 等离线部署路径脱节。AI 库与工艺库已在构建时打入 APK、启动时按需导入；将固件以同样方式内置，可在用户回到首页且 Modbus 就绪、版本落后时弹窗提示升级，减少现场对网络的依赖，并与现有 `ControllerUpgradeHandler` / `BinUtil` 链路复用。

## What Changes

- **构建集成**：在 Gradle 打包前将仓库 `firmware/` 下符合命名约定的 `.bin` 拷贝到 `app/src/main/assets/firmware/`（本地源，不走 Workers manifest）；`assets/firmware/` 加入 `.gitignore`。
- **首页检测与提示**：新增 `BundledFirmwareBootstrap`，**仅在首页（`MainActivity`）** 且 Modbus 可用、已取得有效 `DeviceStatus` 时比较内置固件与控制卡软硬件版本；硬件匹配且软件版本更高时 **弹窗提示**升级，用户确认后刷写（含「保持通电、勿操作」类文案）。**不提供**自动静默刷写、工程师模式或构建开关绕过确认。
- **检测范围**：其他界面（工程师模式、设置、监测等）**不**触发内置固件版本检测与弹窗；离开首页再返回时可再次检测。
- **版本与持久化**：使用 `UpgradeFileReaderUtils` 文件名整数 HW/SW 规则（非 SemVer）；成功后更新 `DeviceInfo.firmwareVersion`；606（版本相同）静默跳过。
- **模拟器 / 无 Modbus**：与 OTA 路径一致，跳过或降级，不在首页弹出阻塞性错误。
- **OTA 保留**：在线 `lws-app` OTA zip 中的 `.bin` 路径不变；内置固件为 **并行交付渠道**，不删除 OTA 固件能力。

## Capabilities

### New Capabilities

- `build-bundled-firmware`: 构建时将 `firmware/` 目录下的控制卡 `.bin` 写入 `assets/firmware/`，校验命名约定，并与 APK 打包衔接。
- `startup-bundled-firmware-upgrade`: 在首页且 Modbus/`DeviceStatus` 就绪时比较内置固件与控制卡版本，弹窗确认后触发 Modbus OTA 并持久化结果。

### Modified Capabilities

- `lws-app-ota-semver`: 补充说明固件更新除 OTA zip 外还可由首页内置固件检测弹窗确认后触发；OTA zip 内 `.bin` 行为与优先级不变。

## Impact

- **构建**：`app/build.gradle.kts`（或等价 Gradle task）、`.gitignore`、`firmware/` 目录约定。
- **运行时**：`MainActivity`（首页检测入口）、`BundledFirmwareBootstrap`（新类）、`ControllerUpgradeHandler` / `BinUtil`（复用）、`DeviceInfo` 持久化、升级确认对话框。
- **测试**：仪器测试或 mock Modbus 场景；模拟器跳过路径。
- **运维**：`make pack` / `make publish` 中的独立 `firmware/*.bin` 仍可保留用于非 APK 渠道；APK 内置固件与 pack zip 中的 bin 应来自同一源目录以保持一致。
