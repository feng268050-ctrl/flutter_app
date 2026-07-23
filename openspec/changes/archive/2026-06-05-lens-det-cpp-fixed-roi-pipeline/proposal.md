## Why

当前 C++ `lens_det` 仍依赖 **蓝线有效区域** 与 **HSV 高亮掩膜** 提取目标，在固定机位/焊接画面下易受蓝线缺失、弧光分布变化影响，与已在 Python 验证通过的 **固定方形 ROI + 亮度增强 → 黑白反转 → 二值化** 路径不一致，导致设备端与离线脚本检测结果偏差（误检底部条纹、漏检 3s 帧等）。需要将 native 管线与已验收的 square-roi 实验对齐，并简化有效区域逻辑为单一固定 ROI。

## What Changes

- **移除** C++ 蓝线检测（`detectBlueLineBounds`）、蓝线排除掩膜、全帧 HSV/V/R/G/B 高亮阈值链与基于 `ref_height` 的纵向有效带缩放。
- **新增** 唯一固定检测 ROI：`x=650`, `y=100`, `width=500`, `height=500`（相对 1080p 输入；越界时 clamp 到图像边界）。
- **重写** ROI 内预处理顺序：ROI 裁剪 → 亮度增强（CLAHE + scale）→ 灰度 → 黑白反转 → 固定阈值二值化 → 形态学开运算去噪 → **椭圆核动态腐蚀**（每步检查连通域，达到 ≥2 个即停止，**最多 6 次**）。
- **保留** JNI 对外契约：`nativeOpencvStainDetectFrom*` 仍写 `target.json` + summary JSON；坐标仍映射回全图像素。
- **更新** `config.yaml` / `ValidRegionParams`（或等价结构）默认值与字段语义，反映新管线参数（增强、反转阈值、腐蚀上限等）。
- **BREAKING**（native 行为）：同一输入帧的 `ok`/`target` 坐标可能与旧蓝线管线不同；依赖旧有效带几何的调试图/文档需同步更新。

## Capabilities

### New Capabilities

- `lens-det-fixed-roi-pipeline`: Native `lens_det` 固定 500×500 ROI 与 enhance-invert-erode 检测管线（含参数、坐标映射、腐蚀停止条件）。

### Modified Capabilities

- `native-infer-image-contract`: OpenCV stain/lens_det 检测前置条件由「蓝线有效带」改为「固定 ROI」；失败原因与可选诊断字段说明更新。
- `ai-vision-lens-dirty-alerts`: 污点判定所依赖的 native 检测语义与旧蓝线路径脱钩（行为以新管线为准，App 侧接口不变）。

## Impact

- **Native C++**: `native/lensinspector/src/lens_det/valid_region.cpp`（重命名/拆分）、`valid_region.h`、`lens_det_analyzer.cpp/.h`；`config.yaml` `lens_det:` 段。
- **工具**: `native/lensinspector/tools/lens_det_infer` CLI 与 `scripts/verify_libai_jni.sh` 回归期望。
- **文档**: `native/lensinspector/docs/LENS_DET_NATIVE_API.md`、`docs/LENS_GUARD_APP_INTEGRATION.md`、`docs/OPENCV_DETECT_APP_INTEGRATION.md`。
- **Java / App**: 无 JNI 签名变更；overlay 仍消费 `target.json` 全图坐标。可选后续：可视化固定 ROI 黄框（属 App 层，本变更以 native 为主）。
- **参考实现**: `scripts/lens_det_dump_stages.py` square-roi 模式（参数与阶段顺序对齐）。
- **部署**: `make sync` 或 native 重建后 `sync-native` + 设备验收。
