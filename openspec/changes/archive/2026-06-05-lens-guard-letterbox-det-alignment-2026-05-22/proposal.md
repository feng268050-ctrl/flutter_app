## Why

引擎 [`LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](https://github.com/lasercyber/lensinspector/blob/main/docs/LENS_GUARD_APP_ALIGNMENT_2026-05-19.md) **2026-05-22** 更新：污点 det 为 **700×700 ROI @(565,110) → resize 640** → `det_raw_head.rknn` → 全图 xyxy（`×700/640` + 偏移在 native）；固定 mask **(885,430)** r=280。App 禁止 letterbox/中心裁/坐标换算；推帧建议 **1920×1080**（**≥1265×810**）。本变更目录名保留历史 `letterbox` 字样。

## What Changes

- **预处理契约（引擎内）**：App 推 **全分辨率 I420**；引擎 `crop_x=(w-640)/2`、`crop_y=(h-640)/2`（1920×1080 为 640/220）；App **不得**实现裁剪、DFL、NMS 或 crop 偏移还原。
- **框坐标契约**：`onCheckResult` / `preview_det` / `nativeInferImageToJson` 的 `boxes[]` 为**当前帧/JPG 全图像素**；overlay **直接**按全图绘制，**不得**再加 crop 偏移或 letterbox 逆变换。
- **推帧约束**：`nativePushFrame` 帧 **width ≥ 640 且 height ≥ 640**；低于该尺寸应跳过或告警（与引擎一致）。
- **禁止 App 二次几何**：移除/关闭 `AiI420Letterbox640` 与 Dev「切换 AI letterbox640」——避免与引擎中心裁冲突或错误坐标空间。
- **config.yaml**：`stain_score_mode: logits`（raw head 必选）；`stain_conf_thresh` / `stain_nms_thresh`、mask 参数与引擎 zip 同步；升级后 `nativeDestroy` → `nativeCreate`。
- **文档**：更新 `LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`、`docs/LENS_GUARD_APP_INTEGRATION.md`，与 `APP_ALIGNMENT_BRIEF` 及 `check/ROI640_PARITY.md` 一致。
- **无 JNI 变更**；脏污等级仍在 native（mask + 窗口）。

## Capabilities

### New Capabilities

- `lens-guard-det-roi640-coords`: 引擎中心裁 640 + crop 偏移还原后的全图 xyxy；overlay 规则；推帧最小尺寸；禁止 App letterbox/裁切/后处理。
- `lens-guard-engine-config-deploy`: `config.yaml` 部署（`logits`、阈值、mask）与 libai 三件套升级。

### Modified Capabilities

- `ai-vision-live-resolution-profile`: 640×640 为**引擎内**中心裁 ROI，非摄像头默认输出、非 App 推帧前 letterbox。
- `native-infer-image-contract`: 离线 JSON `boxes` 为 JPG 全图像素（引擎已加回 crop 偏移）。

## Impact

- **代码**：`LensGuardManager`（最小尺寸校验）、`AiI420Letterbox640`、`CameraConfig`、`DevActivity`、`AiVisionFragment`、文档。
- **依赖**：含 `det_raw_head` 与 ROI640 后处理的新 `libai.so` + `config.yaml`。
- **验收**：**1280×720**、**1920×1080** 实机 overlay 在全图对准污点（§6）；非仅中心 640 区域。
- **与** `lens-guard-engine-alignment-2026-05-19` 互补（det-only、离线 JNI）。
