# Lens Guard 引擎变更 — App 端对齐说明（摘要）

> 原文：[`../LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](../LENS_GUARD_APP_ALIGNMENT_2026-05-19.md)  
> 更新：2026-05-22 · 目标 App **1.0.25+**

## 一句话

引擎（lensinspector）从 cls+det 改为 **det-only** 后，App 须对齐 **700×700 ROI → 640 模型输入**、**全图 xyxy 检测框**、**固定 mask 圆心 (885,430)**，并接入离线 **`nativeInferImageToJson`**。

## 关键变更

| 变更 | App 影响 |
|------|----------|
| `models.cls.enabled: false` | **BREAKING**：激光 ON 不再出现 `MONITORING(1)` |
| `nativeInferImageToJson` | AI Vision 离线时间轴；缺符号则上传失败 |
| `det_raw_head.rknn` + `stain_score_mode: logits` | 须与引擎后处理一致 |
| 预处理 700 ROI @(565,110) → resize 640 | **禁止** App 侧 letterbox / 中心裁 640 |
| 后处理框 ×700/640 + 偏移 → 全图 xyxy | overlay / JSON **直接画全图** |
| Mask 圆心 (885,430) 半径 280 @ 1920×1080 | App **不重算** level |

## App 禁止做的事

- 对推帧做 letterbox、拉伸或中心裁 640
- 对检测框做 `×700/640` 或 ROI 偏移换算
- 用画面几何中心重算 mask 分级

## 必做：离线推理

```
AiVisionFragment → LensGuardManager.inferJpgToJson → nativeInferImageToJson
```

约 500ms 一帧 JPG；仅 `code == 0` 成功；推理 MP4 在 App 侧 `MediaCodec` 合成。

## 验收要点

1. `nm -D libai.so | grep nativeInferImageToJson`（若需离线）
2. 1920×1080 推流：框在全图对准污点
3. 圆心附近污点易 level 2；边缘易 level 1
4. det-only：无 `MONITORING(1)`
5. `config.yaml`：mask 885/430、`logits`、阈值 0.65/0.55

## 本仓库核对模块

`LensGuardManager`、`AiVisionFragment`、Overlay、`assets/config.yaml`、ai-library 中的 `libai.so`

## 延伸阅读

- [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md)
- [`LENS_GUARD_ROI640_ALIGNMENT.md`](LENS_GUARD_ROI640_ALIGNMENT.md)
- [`AI_VISION_LIBAI_JNI_ALIGNMENT.md`](AI_VISION_LIBAI_JNI_ALIGNMENT.md)
