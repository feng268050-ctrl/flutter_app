# Lens Guard 污点 det 几何对齐（App）

> 文件名保留 `ROI640` 为历史路径；**2026-05-22** 引擎已改为 **700×700 ROI @(565,110) → resize 640**，见引擎 [`APP_ALIGNMENT_BRIEF.md`](../../lensinspector/docs/APP_ALIGNMENT_BRIEF.md) 与 [`LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](../LENS_GUARD_APP_ALIGNMENT_2026-05-19.md)。

**JNI 总览**：[`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md)

---

## 1. App 必知（三条）

| 项 | App 侧 |
|----|--------|
| **推帧** | 全分辨率 **I420**；产线 **1920×1080**；**≥ 1265×810**（否则 App 跳过推帧） |
| **预处理** | 引擎 **ROI 700×700 @(565,110)** → **640×640** RKNN；App **不得** letterbox/裁切/缩放 |
| **框坐标** | 回调已是 **全图 xyxy**（`×700/640` + 偏移已在 native 完成）；overlay **直接画全图** |

---

## 2. Mask（native only）

@ **1920×1080** 标定：

| 项 | 值 |
|----|-----|
| 圆心 | **(885, 430)** — `mask_center_x/y` |
| 半径 | **280** — `mask_radius_px` |
| 缩放参考 | `mask_ref_width` × `mask_ref_height` = **1920 × 1080** |

App **不要**用画面中心或 `optical_center` 代替 mask；**不要**根据框重算 level。

---

## 3. 升级 `libai.so`

1. 领取含 **`det_raw_head`** + **700 ROI** 后处理的 `libai_<version>.zip`。
2. 替换 **`libai.so`、`libc++_shared.so`、`librknnrt.so`**（同包）。
3. 同步 **`config.yaml`**（含 mask 885/430、`logits`）→ `files/lens_guard/`。
4. **`nativeDestroy` → `nativeCreate`**。
5. 离线：`nm -D libai.so | grep nativeInferImageToJson`。

模板：`app/src/main/assets/config.yaml`。

---

## 4. App 代码约定

| 模块 | 约定 |
|------|------|
| `LensGuardManager.deliverI420Payload` | 全帧 I420；&lt;1265×810 跳过 + WARN |
| `AiVisionFragment.parseBoxes` | 全图像素；无 ROI/700/640 换算 |
| 离线 `toOverlayBox` | 仅按 **JPG** `imageWidth`/`imageHeight` 归一化 |
| 已移除 | `AiI420Letterbox640`、Dev letterbox 开关 |

---

## 5. 台架验收

- [ ] **1920×1080**：`preview_det` / 生产回调框在全图对准污点
- [ ] logcat：`Stain mask center` 与 **885/430**、r=**280**
- [ ] 离线 AI Vision：JPG / 推理 MP4 与全图对齐
- [ ] 未对 &lt;1265×810 推帧（或已知子码流无检测为预期）
- [ ] det-only + 离线 JNI（见 `lens-guard-engine-alignment-2026-05-19`）
