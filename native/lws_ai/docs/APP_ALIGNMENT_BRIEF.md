# Lens Guard App 端对齐说明（简版）

**更新时间**：2026-05-27
**同步自**：[`训练推理后处理对齐说明.md`](训练推理后处理对齐说明.md)（§3 固定 ROI 700→640、§8.3 raw 后处理、§9 参数表）

面向 **lws-ui / 机器端**。**JNI 完整 API** 见 [`NATIVE_UNIFIED_INFER_API.md`](NATIVE_UNIFIED_INFER_API.md)；集成规则与变更清单见 [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md)。

---

## 1. 结论（先看这三条）

| 项 | App 侧 |
|----|--------|
| **实时** | `nativePushFrame` + `onCheckResult`（或 `preview_det` JSON） |
| **单次推理** | **`nativeInfer*`** → `StainInferOutcome`（`code` + `json`）；勿 push+wait |
| **框 / 等级** | 全图像素坐标；`level` 由 native 算，App **不要**重算 |

---

## 2. 预处理（与训练 §3 一致）

```text
1920×1080 全帧
  → 固定裁剪 ROI：左上角 (565, 110)，尺寸 700×700
  → resize 到 640×640 送 det_raw_head.rknn
```

| 步骤 | 说明 |
|------|------|
| 模型 | `det_raw_head.rknn`，单类 `contamination`，`stain_score_mode: logits` |
| App 无需实现 | 裁剪、resize、DFL、NMS、坐标还原 |

---

## 3. 后处理（§8.3）

640 模型坐标 → **`× 700/640`** → 加 **(565, 110)** → 全图 xyxy → NMS。

产线阈值常用 **conf 0.65 / iou 0.55**；训练对比 **0.25 / 0.35**。

---

## 4. Mask 分级（固定圆心）

| 项 | @1920×1080 |
|----|------------|
| 圆心 | **(885, 430)** — `mask_center_x/y` |
| 半径 | **280 px** — `mask_radius_px` |
| 缩放 | 其它推帧按 `mask_ref_width`×`mask_ref_height` 同比缩放 |

- 框中心在圆内 → L2（HEAVY）候选
- 仅在圆外 → L1（`SLIGHT`）候选

---

## 5. 注意事项（App 必守）

1. **不要**在 App 里对框做 letterbox、中心 640、或 `700/640` 换算——引擎回调已是全图坐标。
2. **不要**用画面几何中心或 `optical_center` 代替 mask；圆心已固定为训练标定 **885/430**。
3. **不要**重算 `level`；只展示 `onCheckResult` 或 `StainInferOutcome.json` 内的 `level`、`message`。
4. 离线 / 单次 `boxes` 属于**该帧像素**（JPG、direct RGBA 或 I420 单次），不一定等于推流分辨率。
5. 产线推帧建议 **1920×1080**；固定 ROI 在更小分辨率上可能不可用。
6. 升级 `libai.so` 后须同步 **`files/lens_guard/config.yaml`** 并 **destroy/create** 会话。
7. `stain_score_mode` 必须为 **`logits`**；`stain_max_det` 默认 **100**。
8. det-only 下激光 ON **无** `MONITORING(1)`。
9. 离线能力：`bash scripts/verify_libai_jni.sh libai.so`（含 `nativeInferImage`、`nativeInferRgb`）；旧包可回退 `*ToJson` 字符串 API。

---

## 6. 单次推理快速对照

| 场景 | 推荐 JNI | 返回 |
|------|----------|------|
| 离线 JPG | `nativeInferImage` | `StainInferOutcome`，`source=offline_infer` |
| 离线 RGBA（direct） | `nativeInferRgb` | 同上 |
| 单次 I420（direct） | `nativeInferI420(ByteBuffer, …)` | `source=live_infer` |
| 实时推帧 | `nativePushFrame(ByteBuffer, …)` | `onCheckResult` |

详见 [`NATIVE_UNIFIED_INFER_API.md`](NATIVE_UNIFIED_INFER_API.md)。

---

## 7. `config.yaml` 关键项

| 键 | 说明 |
|----|------|
| `stain_score_mode` | **`logits`** |
| `stain_conf_thresh` / `stain_nms_thresh` | 0.65 / 0.55（产线）；0.25 / 0.35（训练对比） |
| `stain_max_det` | 100（JSON/回调最大框数；0=不截断） |
| `mask_center_x` / `mask_center_y` | 885 / 430 |
| `mask_radius_px` | 280 |
| `mask_ref_width` / `mask_ref_height` | 1920 / 1080 |

---

## 8. 升级检查

1. 替换 `libai.so` + `libc++_shared.so` + `librknnrt.so`。
2. 同步 `config.yaml` → `nativeDestroy` → `nativeCreate`。
3. `verify_libai_jni.sh` 通过。
4. 1920×1080 实机：全图 overlay 对准污点；圆心附近易 level 2。

---

## 9. 文档索引

| 文档 | 内容 |
|------|------|
| [`NATIVE_UNIFIED_INFER_API.md`](NATIVE_UNIFIED_INFER_API.md) | **JNI 完整索引**：全部 `NativeBridge` 方法、返回码、JSON 形状 |
| [`训练推理后处理对齐说明.md`](训练推理后处理对齐说明.md) | 完整训练/部署约定 |
| [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) | JNI、回调、AI Vision、变更与验收 |
