## Context

- **当前 native**：`lens_det::runValidRegionTargetPipeline`（`valid_region.cpp`）在全帧上解析蓝线上下界 → 纵向有效带掩膜 → 排除蓝线 → HSV/V/R/G/B 高亮与 → 开运算 → 椭圆核动态腐蚀（默认最多 3 次）→ 连通域 → `lens_det_analyzer` 选最小达标 blob 写 `target.json`。
- **已验证 Python 参考**：`scripts/lens_det_dump_stages.py` 的 `square-roi` 模式使用固定 ROI `(650,100,500×500)`，管线为 ROI 裁剪 → `brightness_enhance` → 灰度 → `bitwise_not` → `THRESH_BINARY_INV(80)` → `MORPH_OPEN(3)` → 椭圆腐蚀直至 `min_split_regions`（用户要求 native 上限 **6** 次）。
- **约束**：JNI 签名与 summary/`target.json` 字段不变；App 仅读全图坐标；输入仍为 BGR/I420 解码后的全分辨率帧（典型 1920×1080）。
- **利益相关**：设备 AI Vision / 工艺视频 lens_det overlay、离线 `lens_det_infer` CLI、Python 批量对齐验收。

## Goals / Non-Goals

**Goals:**

- 用 **单一固定 ROI** 替代蓝线有效带与蓝线排除逻辑。
- 在 ROI 内实现与 Python square-roi **同序** 的 enhance → invert → binary → open → dynamic erode 管线。
- 腐蚀停止条件：连通域数（`area ≥ min_blob_area`）≥ `min_split_regions`（默认 2），或达到 `erode_max_iterations`（默认 **6**）。
- 将 ROI 内 blob 坐标映射回全图后，继续写 `target.json` 与现有 summary JSON。
- 更新 `config.yaml`、`LENS_DET_NATIVE_API.md` 与 CLI 回归。

**Non-Goals:**

- JNI / Java API 重命名或新增 debug 阶段 dump（可后续独立变更）。
- App 侧固定 ROI 黄框 overlay（可视化仍可用现有 target 点；ROI 框为可选 follow-up）。
- 将 Python `contamination_mode` 启发式（拒弧光/底边条纹、选 ROI 中心最近）完整移植到 C++（本变更聚焦 **预处理管线**；目标选取暂保留「最小达标面积」策略，见 Open Questions）。
- RKNN 污点模型或 `zero_point` 模块改动。

## Decisions

### 1. 固定 ROI 常量与 clamp 语义

**Decision:** 默认 ROI 为 `x=650`, `y=100`, `width=500`, `height=500`；对任意输入尺寸执行：

```
w = min(roi_width, image_width)
h = min(roi_height, image_height)
x = clamp(roi_x, 0, image_width - w)
y = clamp(roi_y, 0, image_height - h)
```

**Rationale:** 与 Python `SquareRoiConfig(anchor=fixed)` 一致；避免非 1080p 源崩溃。

**Alternative:** 按分辨率比例缩放 ROI — 增加标定复杂度，且用户明确要求固定像素坐标。

### 2. 模块结构：重命名 valid_region 为 fixed_roi_pipeline

**Decision:** 将 `valid_region.cpp/.h` 重构为 `fixed_roi_pipeline.cpp/.h`（或保留文件名但替换实现）；删除 `detectBlueLineBounds`、`buildBlueLineExcludeMask`、`resolveValidRegionY`、HSV 高亮链。`lens_det_analyzer` 改调 `runFixedRoiTargetPipeline`。

**Rationale:** 避免「valid_region」命名误导；减少全帧 HSV 分配，仅在 ROI 子矩阵上运算以降低 RK3566 延迟。

**Alternative:** 保留旧管线为 `legacy` 分支 — 增加维护与测试矩阵；用户要求取消蓝线，不保留双路径。

### 3. 预处理参数默认值（对齐 Python）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `enhance_clahe_clip` | 2.5 | CLAHE on V channel |
| `enhance_alpha` | 1.15 | `convertScaleAbs` |
| `enhance_beta` | 12 | 同上 |
| `invert_thresh` | 80 | `THRESH_BINARY_INV` on inverted gray |
| `open_kernel` | 3 | `MORPH_ELLIPSE` open |
| `erode_kernel` | 5 | `MORPH_ELLIPSE` erode |
| `erode_max_iterations` | **6** | 用户指定上限 |
| `min_split_regions` | 2 | 腐蚀停止 |
| `min_blob_area` | 40 | 连通域计数与 blob 过滤 |

**Rationale:** 与 `DetectParams` / 8.6s 帧验收一致。

### 4. 动态腐蚀实现

**Decision:** 复用现有 `erodeBrightMaskDynamic` 逻辑，但输入改为 open 后的二值 ROI 掩膜；每轮 `erode` 后用 `connectedComponentsWithStats` 统计 `area ≥ min_blob_area` 的连通域数，≥ `min_split_regions` 即 break。

**Rationale:** 与 Python `erode_until_split` 一致；用户实验表明主 blob 约 6 次分裂。

**Alternative:** 腐蚀前仅保留最大连通域 — 仅用于孤立噪点实验；square-roi 主路径未强制，native v1 不引入以免与 Python 主路径分叉。

### 5. 目标选取与坐标映射

**Decision:** 腐蚀后 blobs 仍在 **ROI 局部坐标**；选目标时继续 `lens_det_analyzer::pickSingleTarget`（最小达标面积）；写 JSON 前将 `cx/cy/bbox` 加上 `(roi_x, roi_y)` 偏移。

**Rationale:** 最小 JNI 行为变更；Python contamination 启发式可单独立项。

### 6. 配置与 Options 字段迁移

**Decision:** `Options` / `ValidRegionParams` 移除 `bright_*`、`valid_region_ref_*`；新增 `roi_x/y/width/height` 与 enhance/invert 字段。`config.yaml` `lens_det:` 段同步；旧字段在 YAML 中标记废弃或忽略并打日志（一次）。

**Rationale:** 防止运维误用已失效的蓝线阈值。

### 7. 测试与验收

**Decision:**

- 新增 C++ 单元测试或 `lens_det_infer` 黄金帧：至少 `xiaoheidian_frames_200ms` 中 3.0s OK、5.0s/8.8s FAIL 与 Python batch 趋势一致。
- `scripts/verify_libai_jni.sh` 保持 JNI 符号表不变。
- 可选：`scripts/ci/verify-opencv-detect-integration.sh` 增加 fixed-roi 子命令对比。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 固定 ROI 不适配其他机位/分辨率 | 文档标明 1080p 标定；后续可将 ROI 配置化（已支持 yaml） |
| 行为 BREAKING 导致历史 OK/FAIL 翻转 | 用同一数据集跑 Python vs native diff 报告；保留 git 标签对比 |
| 仍用「最小 blob」选取导致 3.0s 漏检 | Open Questions：评估是否跟进 contamination 启发式 |
| ROI 外污点漏检 | 产品确认污点仅出现在 ROI 内（焊接光斑区） |
| 性能：CLAHE 每帧成本 | 仅在 500×500 子图运行，预期低于全帧 HSV 链 |

## Migration Plan

1. 实现 `fixed_roi_pipeline` 并接线 `lens_det_analyzer`。
2. 更新 `config.yaml` 默认值与文档。
3. 本地 `lens_det_infer` + Python `lens_det_dump_stages.py --mode square-roi` 同帧对比。
4. `make sync` 部署设备；AI Vision / 工艺视频 spot-check 3.0s、8.6s 帧。
5. **Rollback:** 回退 native 提交；App/Java 无需变更。

## Open Questions

- 是否在 C++ v1 同步 Python `pick_contamination_target`（拒弧光/底边条纹）？若 3.0s 帧仍 FAIL，建议在 follow-up 变更中移植。
- 是否在 native summary JSON 中可选返回 `roi_x/y/w/h` 与 `erosion_count` 供调试（非阻塞 v1）？
