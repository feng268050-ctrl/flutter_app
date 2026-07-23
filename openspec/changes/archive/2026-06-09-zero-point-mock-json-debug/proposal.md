## Why

零点自动校正（产线 `ZeroPointDetectCoordinator` 与高级设置 `ZeroPointManualAutoCoordinator`）依赖 native 对实时 I420/视频帧推理，无法在设备上仅通过放置 JSON 模拟检测结果，现场联调 Auto 与 0090H 写入成本高。需要 **staging/debug 专用** 的 mock 文件注入路径，在不改 native 的前提下验证校正链路与弹窗。

## What Changes

- 新增共享 helper：当固定路径 `/sdcard/lws_debug/zero_point_mock.json` 存在且可读时，**跳过** `nativeOpencvZeroPointDetectFromI420`，直接 `ZeroPointDetectJson.parse(文件内容)`。
- 在 `ZeroPointDetectCoordinator.runNativeSample` 与 `ZeroPointManualAutoCoordinator.detectFrame` 接入上述 helper（单点注入，避免重复逻辑）。
- Mock **仅在非 release channel**（`!BuildConfig.RELEASE_CHANNEL`）生效；release APK 忽略该文件。
- 使用 mock 时打明确 log（`ZeroPointMock` TAG），便于 logcat 区分真实检测与注入。
- 文档说明 mock JSON 格式、adb push 示例、与产线/Manual Auto 测试步骤。

## Capabilities

### New Capabilities

- `zero-point-mock-json-debug`: staging/debug 下通过 SD 卡 JSON 文件注入零点检测样本，驱动两条 Auto 校正链路。

### Modified Capabilities

（无。release 行为与 mock 文件不存在时行为与现网一致。）

## Impact

- **Java**: 新 `ZeroPointMockJsonLoader`（或同等工具类）、`ZeroPointDetectCoordinator`、`ZeroPointManualAutoCoordinator`。
- **Native**: 无变更。
- **Build**: 依赖现有 `BuildConfig.RELEASE_CHANNEL`；release 构建不包含 mock 分支逻辑或恒为 no-op。
- **测试**: 单元测试 mock loader（文件存在/不存在/非法 JSON）；可选 instrument 文档化手测。
