# nativeInferImageToJson / nativeInferRgbToJson

**推荐（2026-05-27）**：`nativeInferImage` / `nativeInferRgb` / `nativeInferI420` 返回 `StainInferOutcome`（typed 字段），见 [`NATIVE_UNIFIED_INFER_API.md`](NATIVE_UNIFIED_INFER_API.md) §5。本文档描述 Legacy `*ToJson`。

离线录像时间轴 JNI 与 JSON 契约见 **[`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) §9.4、§9.6**。

单图写标注图诊断见 [`native-infer-image-and-save.md`](native-infer-image-and-save.md)。

## Path infer (`nativeInferImageToJson` / `nativeInferImage`)

- **输入**：设备上可读 JPG/PNG 路径；native `imread` → BGR → 与实时相同的 stain 管线。
- **成功**：顶层 `"code":0`，`"source":"offline_infer"`，`level` / `status` / `message` 与 §5 一致。
- **失败 `code`**：`-1` 参数/路径，`-2` 读图或空图，`-3` 推理异常。

## Buffer infer (`nativeInferRgbToJson` / `nativeInferRgb`) — 推荐离线热路径

- **输入**：**direct** `ByteBuffer`，`RGBA_8888`，`rowStrideBytes`（紧密排列时用 `width * 4`）。
- **输出 JSON**：与 path infer **相同**；不写文件、不触发 `onCheckResult`。
- **能力探测**：`NativeBridge.isNativeInferRgbLinked()`（或兼容 `isNativeInferRgbToJsonLinked()`）。
- **线程**：须在 App 侧 `guardedInferRgb` / `guardedInferRgbToJson`（RKNN 单线程）上调用。

```bash
bash scripts/verify_libai_jni.sh libai.so
```

## `boxes` 与置信度

- 每个框：`score` 与 `confidence` 相同，均为 NMS 后该类概率/分数（与 `stain_score_mode` 一致）。
- 顶层 `maxConfidence`：当前 `boxes` 中最高置信度；无框时为 `0`。

## `boxes` 与截断

- 框坐标属于**该帧像素**（JPG 或 buffer 尺寸）；勿按推流分辨率二次缩放。
- 数量上限由 `config.yaml` → `algorithm.stain_max_det`（默认 **100**）；NMS 后按 score 降序截断。
- 当 NMS 后框数大于上限时，JSON 增加：

```json
"boxesTruncated": true,
"boxesTotal": 142
```

`boxes` 数组长度为 `min(boxesTotal, stain_max_det)`。

## 台架对照（path vs buffer）

同一帧：先 `nativeInferImage(path)`，再将同一 Bitmap 像素拷入 direct RGBA buffer 调 `nativeInferRgb`（或 legacy `*ToJson` 对照）；`code`、`level`、`boxes` 长度与 top 框 score 应一致（允许浮点末位差异）。

仓库内参考图：`assets/bus.jpg`（需设备或带 RKNN 的 Android 构建环境）。
