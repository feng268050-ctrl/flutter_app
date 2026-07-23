# Zero Point 连续焊 / 点焊分模式检测 — 方案设计

本文档汇总零点检测（`zero_point`）在连续焊与点焊成像差异下的产品决策、算法方案、Pipeline 与落地计划。  
与 App 集成 checklist 配合阅读：[`OPENCV_DETECT_APP_INTEGRATION.md`](OPENCV_DETECT_APP_INTEGRATION.md)。

**相关 Native 文档**

- [`native/lensinspector/docs/ZERO_POINT_NATIVE_API.md`](../native/lensinspector/docs/ZERO_POINT_NATIVE_API.md)
- [`native/lensinspector/docs/OPENCV_DETECT_ERROR_CODES.md`](../native/lensinspector/docs/OPENCV_DETECT_ERROR_CODES.md)

---

## 1. 背景与问题

### 1.1 成像差异

| 工艺模式 | 典型成像 | 零点特征 |
|----------|----------|----------|
| **点焊** (`POINT_WELDING`) | 暗场 + 中央小亮斑 | 近似圆斑，宽高 ≤ 数十像素 |
| **连续焊** (`CONTINUOUS_WELDING`) | 熔池圆盘 + **横向激光亮线** | 细长水平高亮带，宽度可达数百像素 |

现有点焊算法在 ROI 内做「增强 → 反色 → 最大黑斑 → bbox 中心」，并限制斑点 **宽高 ≤ 30px**（`kMaxSpotDimensionPx`）。连续焊亮线会触发 `spot_size_above_max` 或质心偏离光路中心。

### 1.2 与 RadialCircleFit 的关系

历史上 L1 Pro 曾通过 `EdgeDrawing` / `ScanVChannelRadialAdaptive`（RadialCircleFit）做零点，并在连续失败时回退 `zero_point`。

**产品决策（当前）：**

- 激光 ON 零点检测 **无条件统一使用 `ZERO_POINT`**
- **RadialCircleFit 暂时屏蔽**，代码可保留，后期可能废弃
- 连续焊 / 点焊的差异在 **`zero_point` 内部**用 **Point / Line** 两种目标模式解决，不再依赖圆拟合

---

## 2. 目标

1. **点焊**：保持现有最亮斑（B6）逻辑，输出 `offset_x/y` 相对 `reference_zero_xy`
2. **连续焊**：新增最亮水平线带 + **中值坐标**（B7），JSON 字段与下游聚合/校正不变
3. **App 路由**：按当前工艺类型 `CONTINUOUS_WELDING` / `POINT_WELDING` 选择 Native 模式
4. **红帧门控**：简化为「熔池亮区存在性」检查（见 §5）
5. **离线验证**：`zero_point_infer --mode line|point` 导出完整 OpenCV stages

---

## 3. 总体架构

```
激光 ON (Quick / Engineer)
  └─ PR1 I420 @ 500ms (burst 100ms on code=-5)
       └─ ZeroPointDetectCoordinator
            ├─ 工艺类型: CONTINUOUS_WELDING → DetectTargetMode::Line
            ├─ 工艺类型: POINT_WELDING      → DetectTargetMode::Point
            └─ nativeOpencvZeroPointDetectFromI420  (固定 ZERO_POINT，无 RadialCircleFit)
                 └─ detectZeroPointFrame(mode)
                      ├─ Line → detectBrightestLineInBox
                      └─ Point → detectBrightestPointInBox
                           └─ compareZeroToReference → JSON
                                └─ ClusterReducer → 容差 → H034 / 0090H
```

**不变部分**

- ROI：`assets/zero_point_roi.json`（`box_xywh` + `reference_zero_xy`）
- 采样门控：`AiFrameSamplingInterval.ZERO_POINT_ON_LASER`（500ms）
- 聚合：`ZeroPointDetectClusterReducer`（16px 聚类、10px anchor 过滤）
- 校正：`ZeroPointCorrectionMapper`（1 UI 单位 = 3px，`offset` 符号取反写 0090H）
- 告警：`WeldAlertScope` 限定连续焊 / 点焊；H034 零点偏移告警

---

## 4. Native 单帧 Pipeline

### 4.1 公共前缀

| 步骤 | 说明 | stages（dump 时） |
|------|------|-------------------|
| 输入 | BGR 全帧 | `00_input_bgr.jpg` |
| ROI 框 | 黄框 + 参考十字 | `04_roi_outline.jpg` |
| 红帧门控 | `validateRedFrame`（可 `config.yaml` 或 `--no-red-gate` 关闭） | `01_gray.jpg` … `03_roi_mask_eroded.jpg`, `00_red_gate.txt` |
| 曝光统计 | ROI 内饱和比、均值 V | （无单独文件） |

### 4.2 公共 ROI 预处理（B1–B5）

两种模式共用 `roi_preprocess`：

1. 按 `box_xywh` 裁剪 ROI → `05_roi_bgr.jpg`
2. HSV-V CLAHE(2.5, 8×8) + `×1.15 + 12` → `06_roi_enhanced.jpg`
3. 转灰度 → `07_roi_gray.jpg`

### 4.3 点焊 — B6 最亮斑（已实现）

**方法名：** `roi_enhance_invert_brightest_peak_blob`  
**实现：** `brightest_in_box.cpp`

| 步骤 | 操作 | stages |
|------|------|--------|
| B6a | 灰度反色 | `08_roi_inverted.jpg` |
| B6b | 阈值 80，`THRESH_BINARY_INV` | `09_roi_binary_thresh.jpg` |
| B6c | 连通域，在各 blob 内取**原始灰度**峰值，选峰值最高者 | `10_roi_blob_mask.jpg` |
| B6d | 峰值像素坐标 → `peak_x/y` | |
| 门限 | 宽高任一侧 > **30px** → `spot_size_above_max` | |

### 4.4 连续焊 — B7 最亮水平线 + 中值（已实现）

**方法名：** `roi_enhance_bright_horizontal_line_min_rect`  
**实现：** `brightest_line_in_box.cpp`

| 步骤 | 操作 | stages |
|------|------|--------|
| B7a | 在增强灰度上，每行统计 `gray ≥ 250` 的像素数 | |
| B7b | 保留每行亮像素数 ∈ **[15, 400]** 的行（排除全宽过曝行） | |
| B7c | 取得分最高（亮像素累计最多）的**连续行带** | |
| B7d | 最大连通域 → `minAreaRect` 长边作长度门限；**矩形中心** → 零点 | `09_roi_line_band_mask.jpg`, `10_roi_line_mask.jpg`, `10_roi_line_min_rect.jpg` |
| 门限 | 旋转外接矩形长边 < 20px 或 > 450px → `line_not_found`；短边 ∉ [3, 45]px 或行带厚度 > 60 行 → 拒绝 | |

**标定样例**（`lianxu.jpg`，`reference_zero_xy = (959, 456)`）：

```json
{"ok":true,"code":0,"offset_x":33.00,"offset_y":-44.00}
```

检测零点 ≈ **(1023, 507)**。

### 4.5 公共后缀（B8 之后）

```
compareZeroToReference:
  offset_x = detected_x - reference_x   ← 容差/告警/写 0090H 仅比较此项
  offset_y = detected_y - reference_y   ← 仅日志/叠加显示
→ frameResultToJson
→ [dump] 11_detect_overlay.jpg
```

---

## 5. 红帧门控简化（计划）

当前 `validateRedFrame` 步骤：

| 代号 | 步骤 | 简化后 |
|------|------|--------|
| A1 | `gray > 20` mask | 保留 |
| A2 | 最大外轮廓填熔池 mask | 保留 |
| A3 | 21×21 腐蚀 | 保留 |
| A4 | 去掉左上角 OSD 区 (650×120) | **删除**（与 A2 冗余；极暗场+仅 OSD 亮时需评估风险） |
| A5 | mask 为空 → `empty_roi` | 保留 |
| A6 | 统计 sat/val/red/purple | 仅 log/stages，不参与判拒 |
| A7 | 过曝 / 非红拒绝 | **删除** |

简化后语义：**有有效熔池亮区 mask 即通过**；暗场仅中央亮线、无大面积熔池轮廓的帧，仍建议 **`enable_red_frame_gate: false`** 或 `--no-red-gate` 做连续焊离线/产线调试。

配置：`config.yaml` → `opencv_detect.enable_red_frame_gate`（当前 bundled 为 `false`）。

---

## 6. App 层路由（待接）

### 6.1 算法选择

| 维度 | 决策 |
|------|------|
| 机型 / RadialCircleFit | **停用**；`ZeroPointDetectAlgorithmSelector` 固定 `ZERO_POINT` |
| 工艺类型 | `WeldModeHost.getActiveWeldModelType()` |
| `CONTINUOUS_WELDING` (0) | `DetectTargetMode::Line` |
| `POINT_WELDING` (1) | `DetectTargetMode::Point` |

接入点建议：

- `ZeroPointDetectNativeSession.detect()`：传入 mode 或内部读工艺类型
- Native：`detectZeroPointFrame(..., DetectTargetMode)`（C++ 已支持）
- 创建 detector 时继续读同目录 `config.yaml` 应用红帧门控

### 6.2 生产路径（不变）

- 触发：激光 OFF→ON 启动 round；激光 OFF + 3s grace 后 finalize
- 范围：Quick Mode / Engineer Mode；连续焊与点焊均采样（`WeldAlertScope`）
- 开关：高级设置 `zeroPointOffsetDetectionEnabled`

---

## 7. 标定与组装公差（参考）

基于现场标定：**79.5 px ↔ 0.2 mm**（≈ 2.5 µm/px）；高级设置 Zero Offset **约 16 px/格**（实测光斑移动，与代码 3px/格写寄存器映射不同）。

| 等级 | 像素（约） | 物理量（约） | 含义 |
|------|-----------|-------------|------|
| 软件容差（不写 0090H） | \|offset_x\| ≤ 16 px | ≤ 0.04 mm | `POSITION_TOLERANCE_PX`；**offset_y 不参与容差** |
| 理想组装 | ≤ 16 px | ≤ 0.04 mm | 约 1 格 UI |
| 良好 | ≤ 32 px | ≤ 0.08 mm | 约 2 格 UI |
| 可接受 | ≤ 48 px | ≤ 0.12 mm | 约 3 格 UI |
| 需校正 | ≥ 60 px | ≥ 0.15 mm | 弹 H034 / 手动调零 |
| UI 满量程 | ±30 格 × 16 px | ±1.2 mm/轴 | 软件可调上限（实测换算） |

`reference_zero_xy` 为设备标定零点，**不等于**图像几何中心 (960, 540)。

---

## 8. 错误码与 reason

| reason | 场景 | 模式 |
|--------|------|------|
| `empty_roi` | 红帧门控 mask 为空 | 公共 |
| `black_blob_not_found` | 点焊无合格斑 | Point |
| `spot_size_above_max` | 点焊斑 > 30×30 | Point |
| `line_not_found` | 连续焊无合格水平亮带 | Line |
| `missing_reference_zero` | ROI JSON 缺参考点 | 公共 |

完整表见 [`OPENCV_DETECT_ERROR_CODES.md`](../native/lensinspector/docs/OPENCV_DETECT_ERROR_CODES.md)。

---

## 9. 离线工具

```bash
# 连续焊（长条 + 中值）
native/lensinspector/build-host/zero_point_infer \
  --image /path/to/continuous.jpg \
  --roi-json app/src/main/assets/zero_point_roi.json \
  --out-dir ~/Desktop/zero_point_line_out \
  --mode line \
  --no-red-gate

# 点焊（默认）
zero_point_infer ... --mode point
```

输出：`{stem}.json`、`{stem}_overlay.jpg`、`stages/00–11`。

构建：`cmake -DBUILD_ZERO_POINT_INFER=ON` + `cmake --build build-host --target zero_point_infer`。

---

## 10. 实现状态

| 项 | 状态 | 位置 |
|----|------|------|
| `DetectTargetMode` Point/Line | ✅ | `zero_point_types.h`, `zero_point_detector.cpp` |
| B7 连续焊线检测 + minAreaRect 中心 | ✅ | `brightest_line_in_box.cpp` |
| B6 点焊（重构共用 preprocess） | ✅ | `brightest_in_box.cpp`, `roi_preprocess.cpp` |
| `zero_point_infer --mode line\|point` | ✅ | `tools/zero_point_infer/main.cpp` |
| `line_not_found` reason | ✅ | `opencv_detect_codes.h` |
| lianxu.jpg 桌面验证 | ✅ | `~/Desktop/zero_point_lianxu_line/` |
| App 按工艺类型路由 mode | ⏳ | `ZeroPointDetectNativeSession` / Coordinator |
| 固定 ZERO_POINT、屏蔽 RadialCircleFit | ⏳ | `ZeroPointDetectAlgorithmSelector` |
| 红帧门控 A4/A7 删除 | ⏳ | `red_frame_validator.cpp` |
| OpenSpec 更新（L1 Pro → EdgeDrawing） | ⏳ | `openspec/specs/zero-point-detect-on-laser-on/` |

---

## 11. 测试计划

1. **离线**：连续焊图集 `--mode line`；点焊图集 `--mode point`；对比 minAreaRect 中心与人工标注
2. **门控**：暗场连续焊帧在简化门控 / `--no-red-gate` 下的通过率
3. **App**：Quick/Engineer 切换连续焊/点焊，logcat `module=zero_point`、`offset_x/y` 稳定
4. **回归**：点焊帧不因 Line 模式误路由；`ClusterReducer` / 0090H / H034 行为不变
5. **边界**：线宽过厚、全宽过曝、仅 OSD 亮等负例 reason 正确

---

## 12. 后续可选

- 连续焊专用 `zero_point_line_roi.json`（若光斑系统性偏离默认 ROI 中心）
- 按设备学习 `reference_zero_xy`（多帧聚类替代固定标定值）
- 摆动焊竖直亮线：增加竖直线分支或按主轴自适应
- 彻底移除 `edgedrawing_core` / RadialCircleFit JNI 与 CMake 依赖

---

*文档版本：2026-07-02 · 对应 native 分支含 `brightest_line_in_box` 与 `zero_point_infer --mode`。*
