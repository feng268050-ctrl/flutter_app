## Context

- 零点检测 native 返回内存 JSON：`{"ok":true,"code":0,"offset_x":...,"offset_y":...}`，由 `ZeroPointDetectJson.parse` 解析。
- **产线路径**：`ZeroPointDetectCoordinator` 在激光上升沿 +500/+1000/+1500/+2000 ms 采样，超容差写 0090H；产线弹窗在激光下降沿。
- **Manual Auto**：`ZeroPointManualAutoCoordinator` 在用户点 Auto 后在线/离线采样，汇总后写 0090H。
- 两条路径均在 worker 线程调用 `nativeOpencvZeroPointDetectFromI420`；无磁盘结果 JSON 读取。

## Goals / Non-Goals

**Goals:**

- 允许在设备上 `adb push` 固定路径 JSON，触发与真实检测相同的后续流程（样本聚合、`ZeroPointCorrectionWriter`、产线 pending 弹窗）。
- 单文件、单路径、格式与 `ZeroPointDetectJson` 一致。
- Release channel 构建完全禁用 mock（即使文件存在也不读）。

**Non-Goals:**

- 不改 native、不增加 HTTP/adb 动态切换接口。
- 不支持多样本 JSON 数组（每次 detect 调用读同一文件；产线 4 次采样会得到相同 mock，足以测写入/弹窗）。
- 不 mock ROI（仍用 `zero_point_roi.json` 创建 handle；mock 时可不创建 detector 以省 native，见决策 3）。

## Decisions

### 1. 固定路径与 JSON 格式

- **路径**：`/sdcard/lws_debug/zero_point_mock.json`（绝对路径常量，不配置化）。
- **格式**：与 `ZeroPointDetectJson.parse` 兼容的最小对象：
  ```json
  {"ok":true,"code":0,"offset_x":-9.0,"offset_y":0.0}
  ```
- **失败样本**：`{"ok":false,"code":-5,"offset_x":0,"offset_y":0}` 用于测「无有效样本、不写 0090H」。

### 2. Release 门控

- **Decision**：`ZeroPointMockJsonLoader` 在 `BuildConfig.RELEASE_CHANNEL == true` 时恒返回 empty，不访问文件系统。
- **Rationale**：避免产线设备误放 mock 文件导致错误校正。
- **Alternative**：`BuildConfig.DEBUG` only → 否决（staging APK 非 debug 也需联调）。

### 3. 注入点与跳过 native

- **Decision**：新增 `ZeroPointMockJsonLoader.tryLoadSample()`：
  - 若 release → `Optional.empty()`
  - 若文件不存在或读失败 → `Optional.empty()` → 调用方走原有 native
  - 若解析成功 → 返回 `ZeroPointDetectJson.Sample`，**不调用** native
- **接入**：
  - `ZeroPointDetectCoordinator.runNativeSample`：在 `nativeOpencvZeroPointDetectFromI420` 之前尝试 mock
  - `ZeroPointManualAutoCoordinator.detectFrame`：同上
- **Rationale**：两处是唯一生成 `Sample` 的入口；集中 helper 避免分叉。

### 4. Detector 生命周期

- **Decision**：mock 命中时 **仍可跳过** `ensureDetector` / `createDetectorIfReady` 的 native 创建（Manual Auto 的 `detectFrame` 在 mock 时不必 `zpHandle != 0`）。
- **Rationale**：无相机/无 libai 时也能测 Java 校正链；减少联调依赖。
- **Implementation note**：`detectFrame` 先 `tryLoadSample()`，有则 return；无则现有 `ensureDetector` + native。

### 5. 日志

- TAG `ZeroPointMock`：`mock_hit path=... offset_x=...` / `mock_miss reason=...`（verbose 级 miss 可 debug）。

## Risks / Trade-offs

- **[Risk] 误在 staging 设备长期留 mock 文件** → 文档要求测完 `adb shell rm`；log 标明 `mock_hit`。
- **[Risk] 四次采样相同 mock 导致校正幅度偏大** → 可接受（联调目的）；文档说明 `offset_x=-9` 单次 uiDelta=+3，四次平均仍为 -9。
- **[Risk] `/sdcard` 权限** → 使用应用可读路径；RK 设备通常可读 `/sdcard/`；若失败 log `mock_miss reason=unreadable`。
- **[Trade-off] 不 mock 激光/相机** → 产线路径仍需激光上升沿与活动在前台；Manual Auto 仍需点 Auto + 激光时序（或仅离线阶段有 mock 样本）。

## Migration Plan

1. 实现 helper + 两处注入 + 单元测试。
2. 在 `docs/OPENCV_DETECT_APP_INTEGRATION.md` 或变更 tasks 内联「Mock 联调」小节：push 命令、示例 JSON、logcat 过滤。
3. Release `make build RELEASE=1` 验证 mock 文件被忽略。
4. 无 DB/Modbus 迁移；删除 mock 文件即恢复真实检测。

## Open Questions

- 无。路径与 release 门控已按用户输入固定。
