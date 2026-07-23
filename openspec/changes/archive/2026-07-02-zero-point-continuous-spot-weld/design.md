## Context

零点检测在激光 ON 期间由 `ZeroPointDetectCoordinator` 驱动 PR1 子码流采样（500ms，`ZERO_POINT_ON_LASER`），Native 返回 `offset_x/y` 相对 `reference_zero_xy`，Java 侧聚类后写 0090H / H034。

当前状态：

- **点焊**：`brightest_in_box`（B6）最大黑斑 + bbox 中心，30×30 上限。
- **连续焊**：横向亮线，B6 易 `spot_size_above_max` 或质心偏移。
- **机型路由**：`ZeroPointDetectAlgorithmSelector` 默认 RadialCircleFit，`machine-model-zero-point-routing` 要求 L1 Pro 走 `nativeOpencvEdgeDrawingDetectFromI420`。
- **红帧门控**：`validateRedFrame` 含 OSD 裁剪（A4）与颜色/过曝判拒（A7）；暗场连续焊帧易 `empty_roi`。

Native 侧 **B7 线检测**、`DetectTargetMode`、`zero_point_infer --mode line|point` 已在工作区部分落地（见 `docs/ZERO_POINT_CONTINUOUS_SPOT_WELD_DESIGN.md` §10）。本 change 完成 App 接线、规格对齐与门控简化。

## Goals / Non-Goals

**Goals:**

- 所有机型、所有激光 ON 零点样本 **仅** 调用 `nativeOpencvZeroPointDetectFromI420`。
- 按 **工艺类型**（非机型）选择 Native `DetectTargetMode::Point` 或 `::Line`。
- 简化红帧门控为熔池亮区存在性（去掉 A4、A7 判拒）。
- 更新 OpenSpec，消除 L1 Pro → EdgeDrawing 零点路径与实现分歧。
- 保持 JSON 形状、ClusterReducer、0090H、H034 语义不变。

**Non-Goals:**

- 删除 `edgedrawing_core`、RadialCircleFit JNI 或 CMake 目标（暂保留代码）。
- 工艺视频离线 zero_point（仍不走生产 Coordinator）。
- 设备级学习 `reference_zero_xy`、摆动焊竖直线。
- 修改 `POSITION_TOLERANCE_PX`（仍为 3px）或 UI 3px/格写寄存器映射。

## Decisions

### D1 — 路由维度：工艺类型优先于机型

**选择**：`WeldModeHost.getActiveWeldModelType()` → `CONTINUOUS_WELDING` = Line，`POINT_WELDING` = Point。

**备选**：继续 L1 Pro → EdgeDrawing。**否决**：与产品「统一 ZERO_POINT」冲突，且连续焊成像不适合圆拟合。

**实现**：`ZeroPointDetectCoordinator` / `ZeroPointDetectNativeSession` 在 `detect()` 前解析工艺类型，传入 Native（JNI 扩展 `detectTargetMode` 或在 Context 构造时设置，二选一；推荐 **每帧 detect 前 setMode** 或 **Context 字段** 避免双 JNI）。

### D2 — 固定 `ZERO_POINT`，移除 RadialCircleFit 生产路径

**选择**：`ZeroPointDetectAlgorithmSelector.getActiveAlgorithm()` 恒返回 `ZERO_POINT`；`onDetectRoundFinalized` 不再计数 fallback；`ZeroPointDetectNativeSession` 不再 create/call EdgeDrawing handle。

**备选**：保留 fallback。**否决**：产品明确要求暂时屏蔽。

**保留**：`nativeOpencvEdgeDrawingDetectFromI420` 符号与离线 `edgedrawing_infer` CLI。

### D3 — B7 线检测算法（连续焊）

**选择**（已实现于 `brightest_line_in_box.cpp`）：

1. 共用 B1–B5：`roi_preprocess`（CLAHE + 灰度）。
2. 每行统计 `gray ≥ 250` 像素数；有效行：15–400 px/行。
3. 取得分最高的连续行带；带内亮像素 **median(x), median(y)**。
4. 水平跨度 20–450px；行带 ≤ 60 行；失败 `line_not_found`。

**备选**：连通域长宽比筛选。**否决**：连续焊 ROI 内熔池连通域过大，median 行带更稳（`lianxu.jpg` 验证 ≈ (1023,507)）。

### D4 — 红帧门控简化

**选择**：保留 A1→A2→A3→A5；删除 A4（OSD 清零）、A7（过曝/非红拒绝）；A6 指标仅写 stages/log。

**备选**：全局 `enable_red_frame_gate: false`。**部分采用**：bundled config 已为 false；简化后即使开启 gate 也不因颜色拒绝暗场+亮线帧。

### D5 — OpenSpec 与主规格

**选择**：本 change delta 修改 `zero-point-detect-on-laser-on`、`machine-model-zero-point-routing`（激光 ON 零点段落）、`opencv-red-frame-validation`、`zero-point-mock-json-debug`；新增 `zero-point-line-detect`。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 去掉 A4 后 OSD 成为最大亮区 | 产线帧多为熔池主导；异常帧靠 `no_valid_region` / `empty_roi` |
| 暗场连续焊无熔池轮廓 | `enable_red_frame_gate: false` 或门控仅 mask 存在性仍可能 `empty_roi` → 依赖配置关闭门控 |
| L1 Pro 失去 RadialCircleFit 兜底 | 点焊仍用 B6；连续焊用 B7；离线对比保留 edgedrawing_infer |
| 工艺类型读错（清洗/切割） | 仅 `WeldAlertScope` 内连续/点焊启动 round；其他模式不 finalize 告警 |
| JNI 签名变更 | 优先 Context 内 `setDetectTargetMode` 避免改 `nativeOpencvZeroPointDetectFromI420` 签名；若改签名则更新 `verify_libai_jni.sh` |

## Migration Plan

1. 合并 Native（线检测 + 门控 + `line_not_found`）→ `make ai`。
2. Java：Selector 固定 ZERO_POINT + 工艺路由 → **`make sync`**（JNI 若变更）。
3. 设备验证：L1 / L1 Pro 各跑连续焊、点焊各 10 轮，logcat `module=zero_point`、`mode=line|point`。
4. 回滚：恢复 `ZeroPointDetectAlgorithmSelector` fallback + EdgeDrawing session（git revert）；config `enable_red_frame_gate: false` 不变。

## Open Questions

- JNI 是否增加 `nativeSetOpencvZeroPointDetectTargetMode(handle, mode)` 还是在 create 时传入？**建议**：create 后首次 detect 前由 Java 按工艺 set，减少每帧 JNI。
- `ZeroPointManualAutoCoordinator` 是否强制点焊工艺？**建议**：保持点焊 Point 模式，与现有 `AUTO_LASER_WELD_MODEL = POINT_WELDING` 一致。
