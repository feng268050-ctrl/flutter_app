## Why

连续焊与点焊在相机上的零点成像不同：点焊为中央小圆斑，连续焊为横向激光亮线。现有点焊 `zero_point` 算法（最大黑斑、30×30 上限）无法稳定检测连续焊零点，且 L1 Pro 仍按 OpenSpec 走 `EdgeDrawing` / RadialCircleFit，与产品决策「统一 ZERO_POINT」不一致。需要在同一 JNI 路径下按工艺模式分派点/线检测，并同步规格与实现。

## What Changes

- **统一零点 Native 路径**：激光 ON 生产检测对所有机型仅调用 `nativeOpencvZeroPointDetectFromI420`；**停用** `ZeroPointDetectAlgorithmSelector` 的 RadialCircleFit 优先与 EdgeDrawing 回退（RadialCircleFit 代码暂保留，不删除 JNI）。
- **连续焊线检测（B7）**：在 `zero_point` 内新增水平最亮行带 + median 坐标；点焊保留现有最亮斑（B6）。
- **App 工艺路由**：`CONTINUOUS_WELDING` → Line 模式；`POINT_WELDING` → Point 模式（经 `WeldModeHost.getActiveWeldModelType()`）。
- **红帧门控简化**：保留熔池亮区 mask 存在性检查（A1–A3、A5）；移除 OSD 时间戳 mask（A4）与颜色/过曝判拒（A7）。
- **OpenSpec 对齐**：更新 `zero-point-detect-on-laser-on` 等规格，删除「L1 Pro → EdgeDrawing JNI」要求，改为统一 zero_point + 工艺分模式。
- **文档**：以 [`docs/ZERO_POINT_CONTINUOUS_SPOT_WELD_DESIGN.md`](../../../docs/ZERO_POINT_CONTINUOUS_SPOT_WELD_DESIGN.md) 为实现依据；补充 `line_not_found` 等 reason 至错误码文档。

**BREAKING（行为）**：L1 Pro 设备激光 ON 零点检测不再调用 `nativeOpencvEdgeDrawingDetectFromI420`；连续焊帧不再尝试 RadialCircleFit 圆拟合。

## Capabilities

### New Capabilities

- `zero-point-line-detect`: 连续焊 ROI 内水平最亮线带检测与中值零点坐标；Native `DetectTargetMode::Line` 与 `line_not_found` 等失败语义。

### Modified Capabilities

- `zero-point-detect-on-laser-on`: 统一 zero_point JNI；按工艺类型选择 Point/Line 检测目标；移除机型→EdgeDrawing 路由场景。
- `machine-model-zero-point-routing`: 激光 ON 零点对所有机型固定 `ZERO_POINT`；删除 L1 Pro → `ScanVChannelRadialAdaptive` 生产路径。
- `opencv-red-frame-validation`: 简化 `validateRedFrame` 判拒逻辑（去掉 A4 OSD mask 与 A7 颜色门控）。
- `opencv-detect-error-codes`: 新增 `line_not_found`（`code=-3`）语义。
- `zero-point-mock-json-debug`: Mock 与生产路径仅经 zero_point JNI（L1 Pro 不再经 EdgeDrawing coordinator 场景）。

## Impact

- **Native**: `brightest_line_in_box.cpp`, `roi_preprocess.cpp`, `zero_point_detector.cpp`, `red_frame_validator.cpp`, `opencv_detect_codes.h`, `zero_point_infer`（`--mode line|point` 已部分落地）。
- **Java**: `ZeroPointDetectAlgorithmSelector`, `ZeroPointDetectNativeSession`, `ZeroPointDetectCoordinator`, `ZeroPointManualAutoCoordinator`（工艺 mode 传入）。
- **Specs**: `openspec/specs/zero-point-detect-on-laser-on/spec.md` 及本 change delta specs。
- **Tests**: `ZeroPointDetectAlgorithmSelectorTest`、新增 line/point 路由与 Native reason 单测。
- **Out of scope（本期）**: 删除 `edgedrawing_core` / CMake；设备级学习 `reference_zero_xy`。
