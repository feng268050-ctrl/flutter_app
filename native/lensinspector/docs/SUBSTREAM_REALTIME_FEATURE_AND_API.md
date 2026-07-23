# 子码流实时污点检测 — 功能说明与调用归档

| 项 | 值 |
|----|-----|
| **文档时间** | **2026-05-25** |
| **OpenSpec 变更** | `substream-realtime-stain-rules` |
| **适用分支** | `rknn`（含离线录像 JNI；实时规则与 `dev` 对齐） |
| **权威契约** | [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) |
| **单次推理（离线/采样）** | [`NATIVE_UNIFIED_INFER_API.md`](NATIVE_UNIFIED_INFER_API.md)（**非** `nativePushFrame`） |
| **台架验收** | [`SUBSTREAM_REALTIME_VERIFICATION.md`](SUBSTREAM_REALTIME_VERIFICATION.md) |

---

## 1. 本次归档范围（突出重点）

### 1.1 做了什么

| 重点 | 说明 |
|------|------|
| **子码流实时 = 检测 + 等级规则** | App `nativePushFrame` 推 I420 后，周期/焊后/AI Vision 预览路径均走 `infer_stain` + **既有** mask 窗口等级（`level` 0/1/2），不是只给裸框。 |
| **不新增 ROI / mask 配置** | 检测预处理仍用引擎内 **固定 ROI** 700×700@(565,110)→640；等级圆仍用 `config.yaml` 的 `stain_detection.*`（非本阶段新建）。 |
| **推帧改分辨率** | 宽高变化时 **重建** `stain_logic_`（log：`re-init stain level rules`）。 |
| **`preview_det` JSON** | 预览污点 `onCheckResult.message` 为 JSON：`source`、`level`、`status`、`message`、`boxes[]`（含 `classId`、`score`）。 |
| **职责边界写清** | **激光**由 App 判 → `nativeSetLaserOn`；**检测与 JSON**由 native；**UI/联锁/告警**由 App。 |

### 1.2 没做什么（避免误解）

| 能力 | 行为 |
|------|------|
| **`nativeInferVideoAndSave`** | 仅逐帧画框写 MP4，**无** `onCheckResult`、**无** 窗口 `level`。 |
| **App 生成检测 JSON** | **禁止** App 重算 `level` 或自造与 native 同内容的检测 JSON。 |
| **类别名称文件** | 无单独「类别表 json」；框上 `label` 为 `"cls=0"`，展示名可由 App 映射 `contamination`。 |

### 1.3 工程改动索引（实现侧）

| 路径 | 作用 |
|------|------|
| `src/main.cpp` | 推帧尺寸变化时 `initFrameParams` 重建等级规则 |
| `src/det_callback_json.{h,cpp}` | `preview_det` / 离线 infer JSON 序列化 |
| `scripts/verify_libai_jni.sh` | 校验推帧、激光、预览 det 等 JNI 导出 |
| `src/rknn_stain_detect_pp_smoke_test.cpp` | 窗口 L1/L2 回归 |
| `src/preview_det_json_smoke_test.cpp` | `preview_det` JSON 字段回归 |

---

## 2. 职责一览（调用前必读）

```
┌─────────────────────────────────────────────────────────────┐
│ App                                                          │
│  · 判激光开/关 (DeviceStatus 等) → nativeSetLaserOn          │
│  · 子码流解码 → nativePushFrame (I420)                       │
│  · AI Vision 开/关预览 det → nativeSetAiVisionPreviewDetectionEnabled │
│  · 解析 onCheckResult / 画 overlay / 告警 / 联锁             │
│  · 可选：classId=0 → 界面文案「污染」                         │
└───────────────────────────┬─────────────────────────────────┘
                            │ JNI
┌───────────────────────────▼─────────────────────────────────┐
│ libai (native)                                               │
│  · infer_stain（固定 ROI 预处理）                             │
│  · RknnStainContaminationDetector → level/status/message          │
│  · 回调 JSON（preview_det）或文本（生产周期/焊后）            │
│  · 不读激光硬件；不以 preview 单独 LOCKED 产线               │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 如何调用

### 3.1 生命周期（子码流实时）

```text
nativeCreate(configPath, projectRoot)
nativeSetListener(handle, listener)
nativeStart(handle)

// 运行中每帧（子码流 I420，建议 1920×1080）
nativePushFrame(handle, i420DirectByteBuffer, width, height)

// App 判定激光后同步（非 native 判激光）
nativeSetLaserOn(handle, laserOn)

// 离开 AI Vision Tab 务必关闭
nativeSetAiVisionPreviewDetectionEnabled(handle, false)

nativeStop(handle)
nativeDestroy(handle)
```

### 3.2 AI Vision 预览污点（`preview_det`）

**条件（App 保证）**

- 已 `nativeStart` 且持续 `nativePushFrame`
- **激光 OFF**：`nativeSetLaserOn(false)`（与真实焊机状态一致）
- 进入 Tab：`nativeSetAiVisionPreviewDetectionEnabled(true)`
- 离开 Tab：`nativeSetAiVisionPreviewDetectionEnabled(false)`

**native 行为**

- **每收到一帧**子码流且在 Tab 内时触发一次 `Preview-Det`（`nativePushFrame` 经主循环更新 `latest_frame_` 后即 `trigger_check`）。**节奏由 App 推帧决定**；`scheduler.substream_infer_interval_sec` **不**节流预览。
- `onCheckResult(level, status, message)` 中 **`message` 为 JSON**（见 §4.2）
- **不**因预览 alone 走生产 `LOCKED`（`flag_lens_dirty_` 不因 preview 更新）

### 3.3 生产子码流（周期 / 焊后）

**条件**

- App `nativeSetLaserOn(false)`
- 焊后：`nativeSetLaserOn` 从 true→false 触发 **Post-Weld** 检测
- 周期：激光 OFF、**未**开预览污点检测，且距上次周期检测超过 `substream_infer_interval_sec`（默认 **0.5s**，见下表）；`check_interval_sec` 仅在 `substream_infer_interval_sec <= 0` 时作回退（默认 8s）

**回调**

- `onCheckResult` 的 **`message` 为普通文案**（非 JSON），`level` / `status` 与 §4.1 一致
- `level >= 2` 时 native 可能 `LOCKED`；**是否阻断焊接 UI 由 App 产品逻辑决定**

### 3.4 离线能力（与子码流区分）

| JNI | 用途 | `level` / JSON |
|-----|------|----------------|
| `nativeInferImage` / `nativeInferRgb`（推荐）或 legacy `*ToJson` | 离线时间轴单帧 | `StainInferOutcome` 或 JSON 字符串；`source=offline_infer`，含 `boxes[]` |
| `nativeInferI420` | 单次 I420 推理（非推帧队列） | `source=live_infer`；**勿**与 `nativePushFrame` 混用 |
| `nativeInferVideoAndSave` | 设备 MP4 带框导出 | **仅画框**，无 `onCheckResult`、无窗口等级 |
| `nativeInferImageAndSave` | 单图诊断 | 成功时另走 `onCheckResult` 文本 |

### 3.5 JNI 交付自检

```bash
bash scripts/verify_libai_jni.sh build_android/libai.so
```

须包含（节选）：`nativePushFrame`、`nativeSetLaserOn`、`nativeSetAiVisionPreviewDetectionEnabled`、`nativeInferImage`、`nativeInferRgb`、`nativeInferVideoAndSave`（完整列表见 `scripts/verify_libai_jni.sh`）。

---

## 4. 回调与 JSON 格式

### 4.1 污点等级（native 算，App 只展示）

| level | status | 含义（摘要） |
|-------|--------|----------------|
| 0 | `CLEAN` | 洁净 |
| 1 | `SLIGHT` | mask 圆外检出为主 |
| 2 | `HEAVY` | mask 圆内检出为主 |

规则：单类 `contamination`；框中心在圆内→候选 L2，圆外→候选 L1；`window_time_ms` 窗口聚合（见 `config.yaml` `stain_detection`）。

### 4.2 `preview_det` — `message` JSON（native 生成）

```json
{
  "source": "preview_det",
  "level": 2,
  "status": "HEAVY",
  "message": "立即更换 (mask 内检出)",
  "boxes": [
    {
      "x1": 100.0, "y1": 200.0, "x2": 150.0, "y2": 250.0,
      "classId": 0,
      "label": "cls=0",
      "score": 0.88
    }
  ]
}
```

| 字段 | 来源 | App 注意 |
|------|------|----------|
| `score` | native 后处理置信度 | **勿重算**；与 `confidence` 同值 |
| `confidence` | 与 `score` 相同（显式置信度字段） | **勿重算** |
| `maxConfidence` | 本帧 `boxes` 最高置信度 | 无框为 0 |
| `classId` | 模型（nc=1 时为 0） | 展示名可用 App 映射 `contamination` |
| `label` | native 固定 `"cls=" + classId` | 非独立类别名称配置文件 |
| `x1`…`y2` | 全图像素，已 ROI 还原 | **禁止** 再 letterbox / 700/640 变换 |
| `boxesTruncated` / `boxesTotal` | 超过 `stain_max_det` 时可选 | 默认 cap 100 |

### 4.3 离线 `offline_infer` JSON（native 生成）

结构类似：`code`、`source":"offline_infer"`、`level`、`status`、`message`、`boxes[]`（坐标属**该帧图像**像素，可能与推流分辨率不同）。

### 4.4 分类 cls JSON（det-only 时通常无效）

`nativeGetLastClsResult` → `valid:false` 占位。启用 cls 时由 **native** 提供 `className` / `score` / `topk`，**勿**与 `onCheckResult.message` 混用。

---

## 5. 配置要点（`config.yaml`）

改 yaml 后须 **`nativeDestroy` → `nativeCreate`**。

| 键 | 默认 | 说明 |
|----|------|------|
| `algorithm.stain_conf_thresh` | 0.65 | 检测阈值 |
| `algorithm.stain_score_mode` | `logits` | det_raw_head 必填 |
| `algorithm.stain_max_det` | 100 | JSON/回调最大框数 |
| `stain_detection.mask_center_x/y` | 885 / 430 | 等级圆心 @1920×1080 |
| `stain_detection.mask_radius_px` | 280 | 圆内 L2 候选 |
| `scheduler.substream_infer_interval_sec` | 0.5 | **仅 Periodic**（激光 OFF 且预览污点关）的最小间隔（秒）；预览见上「每推一帧」 |
| `scheduler.check_interval_sec` | 8 | `substream_infer_interval_sec <= 0` 时的周期回退 |

预处理 ROI **不在 yaml 新增**，代码内固定 (565,110,700)。

---

## 6. 相关文档

| 文档 | 内容 |
|------|------|
| [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) | App 对接总览 §1/§5/§7/§9/§12 |
| [`SUBSTREAM_REALTIME_VERIFICATION.md`](SUBSTREAM_REALTIME_VERIFICATION.md) | 台架步骤 |
| [`native-infer-video-and-save.md`](native-infer-video-and-save.md) | 离线 MP4（无 level 回调） |
| [`native-infer-image-to-json.md`](native-infer-image-to-json.md) | 离线时间轴 JSON |
| `openspec/changes/substream-realtime-stain-rules/` | 变更提案与设计 |

---

## 7. 修订记录

| 日期 | 说明 |
|------|------|
| **2026-05-25** | 初版：子码流实时规则对齐、调用链、`preview_det` JSON、App/native 职责、与离线 MP4 区分 |
