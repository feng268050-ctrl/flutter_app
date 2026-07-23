## Context

三条 OpenCV 检测管线均在 native C++ 中处理 BGR 帧：

| 模块 | 入口 | 现有帧级门禁 |
|------|------|--------------|
| `zero_point` | `detectZeroPointFrame` | 无颜色门禁；`exposureMetrics` 仅写 debug 字段 |
| `edgedrawing` | `detectEdgeDrawingFrame` | 同上 |
| `opencv_stain_detect` | `analyzeFrame` | 全图灰度 255 像素计数 `max_saturated_white_area_px` |

现场需区分：**红色熔池（放行）**、**紫色异常（丢弃）**、**白色过曝（丢弃）**。Python 原型已在 1920×1080 样例上验证：通过最大轮廓 ROI、21×21 腐蚀、屏蔽左上角时间戳区域 `(0:120, 0:650)`，再计算 HSV/灰度指标。

约束：须沿用 `opencv-detect-error-codes` 的 `code=-5 FRAME_REJECTED` + `reason` 契约；App burst 采样对 `-5` 已通用处理。

## Goals / Non-Goals

**Goals:**

- 实现可复用的 `opencv_detect::validateRedFrame(const cv::Mat& bgr)`，三条管线在检测算法前统一调用。
- 阈值与 Python 原型对齐：`overexposed_ratio>0.5` 或 `gray_mean>230`；`red_ratio>0.4 && sat_mean>120 && val_mean>80` 放行。
- 拒绝帧返回 `code=-5`，`reason` 为 `overexposed` 或 `invalid_non_red`；ROI 构建失败返回 `no_valid_region` / `empty_roi`（同为 `-5` 或 `-2`，见决策）。
- 扩展 `OpencvDetectCodes` 与文档；单测覆盖三色样例分类。

**Non-Goals:**

- 不修改 RKNN 污点检测路径。
- 不改变各模块检测算法本体（brightest-in-box、ScanV、fixed ROI pipeline）。
- 不新增 App UI 提示；仅日志与既有 burst 行为。
- 不做自适应阈值学习或机型差异化（后续可配置化）。

## Decisions

### 1. 共享模块位置与 API

在 `native/lensinspector/src/opencv_detect/red_frame_validator.{h,cpp}` 实现：

```cpp
struct RedFrameMetrics {
    double gray_mean = 0;
    double overexposed_ratio = 0;
    double red_ratio = 0;
    double purple_ratio = 0;
    double sat_mean = 0;
    double val_mean = 0;
};

enum class RedFrameVerdict { ValidRed, Overexposed, InvalidNonRed, NoValidRegion, EmptyRoi };

struct RedFrameValidation {
    RedFrameVerdict verdict;
    const char* reason_token;  // maps to opencv_detect_codes
    RedFrameMetrics metrics;
};

RedFrameValidation validateRedFrame(const cv::Mat& bgr);
```

**理由**：与 `opencv_detect_codes.h` 同目录，三条管线及离线工具均可链接，避免在 zero_point/edgedrawing 间复制 `exposureMetrics`。

**备选**：各模块内联实现 — 否决，维护成本高且易漂移。

### 2. ROI 掩膜算法（对齐 Python）

1. `gray = cvtColor(BGR2GRAY)`；`mask = gray > 20`
2. `findContours(RETR_EXTERNAL)` → 取最大轮廓填充 `roi_mask`
3. `erode(roi_mask, 21×21, iterations=1)`
4. `roi_mask[0:120, 0:650] = 0`（固定像素，与 Python 一致；1920×1080 参考分辨率）
5. 在 `roi_mask>0` 像素上统计 gray/HSV 指标

红色 Hue：OpenCV `H∈[0,179]`，`red_ratio = mean((h<10)|(h>170))`  
紫色：`purple_ratio = mean((h>125)&(h<165))` — 仅用于内部分类日志，对外 `reason=invalid_non_red`

**理由**：与用户提供 Python 一致，便于离线对比。

**备选**：使用各模块已有 `center_box` ROI — 否决，红色判断需整帧圆形有效区而非检测 ROI 方框。

### 3. 判定顺序

```
if no contour / empty roi → FRAME_REJECTED (no_valid_region / empty_roi)
if overexposed_ratio > 0.5 OR gray_mean > 230 → overexposed
if red_ratio > 0.4 AND sat_mean > 120 AND val_mean > 80 → pass (继续检测)
else → invalid_non_red
```

与 Python 一致；**不**单独对外返回 `purple_filtered`（紫色落入 `invalid_non_red`），可在 debug 日志输出 `purple_ratio`。

### 4. 集成点（各管线最先执行）

| 模块 | 插入位置 | 通过后行为 |
|------|----------|------------|
| `zero_point_detector.cpp` | `detectZeroPointFrame` 开头，`exposureMetrics` 之前 | 调用 `detectBrightestPointInBox` |
| `edgedrawing_detector.cpp` | `detectEdgeDrawingFrame` 开头 | 调用 `detectScanVChannelRadialAdaptiveInBox` |
| `opencv_stain_detect_analyzer.cpp` | `analyzeFrame` 中，替换/先于 `countSaturatedGray255Pixels` | 调用 `runFixedRoiTargetPipeline` |

**理由**：最早短路，避免无效帧进入重计算。

### 5. lens_det 旧过曝门处理

移除（或默认禁用）全图 `max_saturated_white_area_px` 计数门，由共享 `overexposed` 判断替代。

**理由**：新逻辑基于 ROI 内 `overexposed_ratio` 与 `gray_mean`，比全图 255 计数更贴合圆形熔池；避免同一帧两种过曝拒绝 reason 并存。

**迁移**：`config.yaml` 中 `max_saturated_white_area_px` 可保留但忽略，或实现中 `<=0` 时跳过旧逻辑；文档注明 deprecated。

### 6. Reason token 与 code

| Verdict | code | reason |
|---------|------|--------|
| Valid red | — | （不返回，继续检测） |
| Overexposed | -5 | `overexposed` |
| Non-red / purple | -5 | `invalid_non_red` |
| No contour | -5 | `no_valid_region` |
| Empty ROI after mask | -5 | `empty_roi` |

均使用 `FRAME_REJECTED (-5)`，与 burst 采样契约一致。`no_valid_region` / `empty_roi` 亦用 `-5`（帧内容不可用，非调用参数错误）。

**备选**：`empty_roi` 用 `-2 INVALID_INPUT` — 否决，空 ROI 属帧质量问题而非 API 误用。

### 7. App 层变更

- `OpencvDetectCodes` 增加 reason 常量：`OVEREXPOSED`, `INVALID_NON_RED`, `NO_VALID_REGION`, `EMPTY_ROI`
- 现有 `FRAME_REJECTED` 分支与 burst 逻辑无需改；确认 `EdgeDrawingDetectJson` 同样解析 `reason`
- 可选：在 `detect_result` 日志中输出 `red_frame_metrics`（仅 debug build）

### 8. 测试策略

- C++ 单元测试：`red_frame_validator_test.cpp`，三类固定样例图（红/紫/过曝）+ 边界阈值
- 扩展 `opencv_detect_codes_smoke_test.cpp` 断言新 reason JSON
- 离线工具 `tools/opencv_stain_detect_infer` 可加 `--dump-red-metrics` 便于现场调参

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 固定时间戳屏蔽 `(0:120,0:650)` 在非 1920×1080 分辨率失效 | 首版与 Python 一致；后续可按 `source_width` 比例缩放 |
| 21×21 腐蚀在小分辨率帧上蚀空 ROI | 单测覆盖 720p；`empty_roi` 明确拒绝 |
| 替换 lens_det 全图过曝门行为变化 | 文档标注；用样例图回归对比 |
| edgedrawing 无独立 OpenSpec，易被遗漏 | tasks 明确三模块 + JNI 冒烟 |

## Migration Plan

1. 合入 native 共享 validator + 三管线调用 + reason 常量
2. 更新 App `OpencvDetectCodes` 与文档
3. `make sync` 部署；现场用红/紫/白样例验证 JSON `reason`
4. 回滚：revert 提交即可恢复旧行为（无 schema 迁移）

## Open Questions

- 是否在 `config.yaml` 暴露阈值（`red_ratio_min` 等）供现场微调？首版硬编码与 Python 一致，config 化可 follow-up。
- `saturated_white_area_exceeds_limit` reason 是否保留仅作历史文档，还是 lens_det 在 validator 未启用时 fallback？建议首版完全替换。
