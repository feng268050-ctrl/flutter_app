## Why

现场焊接画面存在三类干扰帧：正常红色熔池、紫色异常色、白色过曝。当前三个 OpenCV 检测管线（zero_point、edgedrawing、opencv_stain_detect）在帧进入算法前缺少统一的颜色/曝光门禁，导致紫色与过曝帧仍触发检测、产生误报并浪费算力。需要在三条管线入口增加**同一套红色帧有效性判断**，只放行 `valid_red`，其余帧以 `FRAME_REJECTED` 丢弃。

## What Changes

- 新增 native 共享模块 **`is_valid_red_frame`**（C++/OpenCV），实现与 Python 原型一致的 ROI 掩膜、腐蚀、时间戳屏蔽与 HSV/灰度指标计算。
- 判定规则（先于各模块检测算法执行）：
  - `overexposed_ratio > 0.5` 或 `gray_mean > 230` → `code=-5`, `reason=overexposed`
  - `red_ratio > 0.4` 且 `sat_mean > 120` 且 `val_mean > 80` → 放行，进入后续检测
  - 其余（含紫色 `purple_ratio > 0.4`）→ `code=-5`, `reason=invalid_non_red`（紫色可额外记录 `purple_filtered` 于 debug 指标，对外 reason 统一为 `invalid_non_red`）
- 在 **zero_point**、**edgedrawing**、**opencv_stain_detect** 三条管线入口调用该门禁；现有 lens_det 全图 `max_saturated_white_area_px` 过曝门可与新逻辑合并或替换为 ROI 级 `overexposed` 判断（以实现为准，见 design）。
- 扩展 `opencv_detect_codes.h` 与 App `OpencvDetectCodes`：`overexposed`、`invalid_non_red`（及内部/调试用的 `no_valid_region`、`empty_roi`）。
- 更新 native API 文档与 `verify-opencv-detect-integration.sh`（如适用）；可选离线工具/单测用样例图验证三色分类。

## Capabilities

### New Capabilities

- `opencv-red-frame-validation`: 三条 OpenCV 检测管线共享的红色帧门禁算法、阈值、reason token 与 JSON 契约。

### Modified Capabilities

- `opencv-detect-error-codes`: 新增 `overexposed`、`invalid_non_red` 等 `FRAME_REJECTED` reason token；文档附录同步。
- `laser-detect-frame-rejected-burst`: `overexposed` 与 `invalid_non_red` 的 `code=-5` 结果须与现有 saturation/spot-size 拒绝一样触发 burst 采样。
- `zero-point-detect-on-laser-on`: 检测前须通过红色帧门禁；未通过时不运行 brightest-in-box。
- `lens-det-app-inference`: stain detect 分析前须通过红色帧门禁；未通过时不运行 fixed ROI pipeline。

## Impact

- **Native**: 新增 `opencv_detect/red_frame_validator.{h,cpp}`；修改 `zero_point_detector.cpp`、`edgedrawing_detector.cpp`、`opencv_stain_detect_analyzer.cpp`；扩展 `opencv_detect_codes.h`；可能调整 `config.yaml` 开关/阈值（可选）。
- **App**: `OpencvDetectCodes`、各 JSON 解析与 burst 采样逻辑（新 reason 已映射为 `FRAME_REJECTED` 即可，无需 UX 变更）。
- **Docs / CI**: `OPENCV_DETECT_ERROR_CODES.md`、各 `*_NATIVE_API.md`；新增或扩展 native 单测。
- **部署**: 需 `make sync`（JNI 帧门禁行为变更）。
