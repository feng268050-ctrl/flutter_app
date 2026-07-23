## Why

`zero_point` 与 `lens_det`（OpenCV stain detect）的 JNI JSON 均返回 `code`，但同一数字在两模块含义不一致（例如 `-5`：光斑尺寸 vs 过曝；`-1`：zero_point 仅 handle 无效，lens_det 却混用空路径/尺寸错等）。App 与文档难以共用解析、日志与 UX，现场排障也易误判。需要在 native 与 App 层对齐为**一套 OpenCV detect 公共错误码**，细分原因统一走 `reason` 字段。

## What Changes

- 新增 native 共享枚举 **`opencv_detect_codes.h`**（或等价 C++ 头文件），`zero_point` 与 `opencv_stain_detect` 仅返回该表中的 code。
- **统一 JSON 顶层形状**：`ok`、`code`、`reason`（失败时 snake_case token）；成功时 zero_point 带 `offset_x`/`offset_y`，lens_det 带 `files`。
- **迁移 lens_det**：将现 `-1` 中非 handle 类错误迁至 `-2 INVALID_INPUT`；`failed to create outputDir` 迁至 `-4 IO_ERROR`；过曝保持 `-5 FRAME_REJECTED` + `reason=saturated_white_area_exceeds_limit`。
- **迁移 zero_point**：缺 `reference_zero_xy`/空 ROI 迁至 `-6 CONFIG_ERROR`；光斑尺寸 `-5` + `reason=spot_size_below_min|spot_size_above_max`；`-3` 仅表示算法跑完无合格光斑。
- 新增 App **`OpencvDetectCodes`**（与 native 一一对应）；`ZeroPointDetectJson` / stain detect mapper 共用解析与日志格式。
- 更新 `ZERO_POINT_NATIVE_API.md`、`OPENCV_STAIN_DETECT_NATIVE_API.md` 为**同一张 code 表**；`verify-opencv-detect-integration.sh` 可选校验 reason token 稳定性。

## Capabilities

### New Capabilities

- `opencv-detect-error-codes`: OpenCV detect 模块（zero_point、lens_det）共享 JNI `code`/`reason` 契约与迁移规则。

### Modified Capabilities

- `zero-point-detect-on-laser-on`: native JSON `code` 语义对齐公共表；`sample_fail` 日志含统一 `reason`。
- `lens-det-app-inference`: JNI summary `code`/`reason` 对齐公共表；App 解析不再将多种失败归为 `-1`。

## Impact

- **Native**: `zero_point_jni.cpp`、`zero_point_detector.cpp`、`opencv_stain_detect_jni.cpp`、`opencv_stain_detect_analyzer.cpp`、新增共享头文件；**无算法逻辑变更**，仅错误分类与 JSON reason 规范化。
- **App**: `OpencvDetectCodes.java`、`ZeroPointDetectJson`、`OpencvStainDetectResultMapper` / `AiStainDetectResultMapper`；Coordinator 日志格式统一。
- **Docs / CI**: 两篇 `*_NATIVE_API.md` 合并 code 表；单元测试覆盖 code/reason 矩阵。
- **部署**: 需 `make sync`（JNI 行为变更）；不建议仅 `sync-native`（JSON 字段与 code 语义均变）。
