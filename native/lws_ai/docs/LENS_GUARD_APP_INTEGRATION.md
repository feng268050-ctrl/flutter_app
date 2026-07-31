# Lens Guard / libai.so — App 对接与对齐说明

| 项 | 值 |
|----|-----|
| **文档更新时间** | **2026-05-27** |
| 初版合入 | 2026-05-19（由原 `LENS_GUARD_APP_INTEGRATION.md` 与 `LENS_GUARD_APP_ALIGNMENT_2026-05-19.md` 合并） |
| 目标 App | 建议 **1.0.25+**（含离线 JNI 声明） |
| 引擎交付物 | `libai_<version>.zip` → `jniLibs/arm64-v8a/libai.so` + `assets/config.yaml` |

Android App 消费 YOLO 交付的 **`libai_<version>.zip`**，固定加载 **`libai.so`**（`System.loadLibrary("ai")`）。本文合并原 App 集成总览、变更清单、注意事项与验收；构建见根目录 **`README.md`**。

> **合入记录**：原 `AI_VISION_LIBAI_JNI_ALIGNMENT.md`、`AI_VISION_NATIVE_OFFLINE_INFERENCE_CONTRACT.md` 已并入 **§9**。

**相关**

| 文档 | 用途 |
|------|------|
| [`NATIVE_UNIFIED_INFER_API.md`](NATIVE_UNIFIED_INFER_API.md) | `NativeBridge` 全部方法、签名、返回码、JSON |
| [`APP_ALIGNMENT_BRIEF.md`](APP_ALIGNMENT_BRIEF.md) | 预处理/后处理/mask 简版 |
| [`SUBSTREAM_REALTIME_FEATURE_AND_API.md`](SUBSTREAM_REALTIME_FEATURE_AND_API.md) | 子码流实时调用链 |
| [`训练推理后处理对齐说明.md`](训练推理后处理对齐说明.md) | 训练/导出/后处理权威 |
| [`native-infer-image-to-json.md`](native-infer-image-to-json.md) | Legacy `*ToJson` |
| [`native-infer-image-and-save.md`](native-infer-image-and-save.md) | 单图诊断 |
| [`../config.yaml`](../config.yaml) | 引擎默认配置（打包进 zip） |

---

## 1. 变更总览（截至 2026-05-27）

| # | 变更 | App 影响 |
|---|------|----------|
| A | **det-only 默认**：`models.cls.enabled: false` | **BREAKING**：激光 ON 不再 `MONITORING(1)` |
| B | 离线单次 **`nativeInfer*`** → `StainInferOutcome` | **推荐**；兼容 `nativeInfer*ToJson` |
| C | 检测模型 **`det_raw_head.rknn`**（raw P2/P3/P4） | `stain_score_mode` 必须为 **`logits`** |
| D | 预处理：**700×700 ROI @(565,110) → resize 640** | **非**整帧/中心 640 裁剪 |
| E | 后处理：框 **`×700/640` + 偏移 (565,110)** → 全图 xyxy | overlay / JSON **直接画全图** |
| F | **Mask 圆心 (885, 430)** @ 1920×1080，半径 **280** | App **不重算** `level` |
| G | 集成文档收敛 | 异常辅助等**非 App 必接** |

---

## 2. 交付物与工程布局

```text
libai_v1.0.0.zip
├── assets/config.yaml    # 与仓库根 config.yaml 一致；须含 algorithm.stain_max_det（勿 0）
└── jniLibs/arm64-v8a/
    ├── libai.so
    ├── libc++_shared.so
    └── librknnrt.so
```

**`NativeBridge.java`** 由 lensinspector 维护（`java/com/lasercyber/lws/ai/`），App 拷贝至 `app/src/main/java/...`。

| 类 | 职责 |
|----|------|
| `NativeBridge` | JNI 与 `guarded*` |
| `LensGuardManager` | 生命周期、监听、EventBus |
| `AssetDeployer` | `config.yaml` → `files/lens_guard` |
| `AiLibraryDirectory` | RKNN 变体目录 |

---

## 3. 加载 native 与 RKNN / BSP

```java
static {
    System.loadLibrary("c++_shared");
    System.loadLibrary("rknnrt");
    System.loadLibrary("ai");
}
```

- **默认**：`files/bundled-libraries/ai-library/<storageDir>/jniLibs/arm64-v8a/`
- **旧 BSP**：`ai.library.variant=legacy` → `.../ai-library/<core>__legacy/`

`librknnrt.so` 须与设备 BSP 匹配。

---

## 4. 运行时、预处理与对接注意事项

```text
/data/data/<package>/files/lens_guard/
├── config.yaml
└── debug_data/
```

`nativeCreate(configPath, projectRoot)`：`configPath` 为 `config.yaml` 绝对路径。

**推帧**：产线标定 **1920×1080 I420**。污点 det：**固定裁 700×700 @(565,110)** → **resize 640**；框按 **700/640** 缩放并加 ROI 偏移回全图。见 [`训练推理后处理对齐说明.md`](训练推理后处理对齐说明.md) §3、§8.3。

### 4.1 检测框坐标

| 路径 | 坐标系 | App 必须 |
|------|--------|----------|
| `onCheckResult` / `preview_det` | **当前推帧全图**像素 | 同一帧宽高上画框；**禁止** letterbox / 640 / `700/640` 变换 |
| `nativeInfer*` / `*ToJson` | **该帧像素**（JPG/RGBA/I420） | 用 `imageWidth`/`imageHeight` |

框整体偏移时，优先查 **libai.so 是否含 700 ROI 逻辑的新包**，勿改 App 坐标公式。

### 4.2 预处理（App 不要做）

- **禁止** App 侧 letterbox、中心裁 640 或改帧再送检。
- 标定 **1920×1080**：`crop=(565,110,700,700)` → 模型输入 640。
- 推帧 **&lt; 1265×810** 时固定 ROI 可能越界 → 空检测；产线应保持标定分辨率或联系引擎扩展 ROI。

### 4.3 激光与子码流

- **激光开/关**：App 判定 → **`nativeSetLaserOn`**；native **不**读焊机 GPIO。
- **实时污点**：**`nativePushFrame`**（I420）+ **`nativeSetAiVisionPreviewDetectionEnabled`** → `preview_det` JSON 或生产 `onCheckResult`。
- 检测仅用引擎内固定 ROI；**不新增**第二套 ROI/mask 配置键。

### 4.4 Mask 与配置

- 圆心 **(885, 430)**、半径 **280** @1920×1080（`stain_detection.*`）；其它分辨率按 `mask_ref_*` 缩放。
- **`level`/`status`/`message` 仅展示 native 结果**；App 不重算等级。
- **`stain_score_mode: logits`**（`det_raw_head` 必填）。
- 改 yaml 后 **`nativeDestroy` → `nativeCreate`**；部署须同步 `files/lens_guard/config.yaml`。

### 4.5 det-only 与其它

| 类别 | 要求 |
|------|------|
| **det-only** | 默认无 cls；激光 ON **无** `MONITORING(1)` |
| **libai 能力** | `bash scripts/verify_libai_jni.sh libai.so`；版本号 ≠ 能力 |
| **单次 vs 推帧** | 实时：`nativePushFrame` + `onCheckResult`；离线/采样：`nativeInfer*`（**勿** push+wait） |

**阈值说明**：仓库根 [`config.yaml`](../config.yaml) 当前示例为训练 parity（如 `stain_conf_thresh: 0.25`）；产线常覆盖为 **0.65 / 0.55**、**`stain_max_det: 100`**。**以设备上实际 yaml 为准**。

---

## 5. JNI 生命周期

完整 API 见 [`NATIVE_UNIFIED_INFER_API.md`](NATIVE_UNIFIED_INFER_API.md)。

| 顺序 | 接口 |
|------|------|
| 1 | `nativeCreate` |
| 2 | `nativeSetListener` |
| 3 | `nativeStart` |
| 运行 | `nativePushFrame`；`nativeSetLaserOn`；`nativeSetAiVisionPreviewDetectionEnabled` |
| 可选单次 | `nativeInferImage` / `nativeInferRgb` / `nativeInferI420` → `StainInferOutcome` |
| 4 | `nativeStop` → `nativeDestroy` |

帧来源：解码回调（如 `onI420Data`）；回调可能在 native 线程，**UI 切主线程**。

---

## 6. 脏污检测（det）— 规则与 UI

规则在 native 计算（`rknn_stain_detect_pp.cpp`、`main.cpp`、`config.yaml`），App **不重算**。

### 6.1 回调语义

`onCheckResult(int level, String status, String message)`

| level | status | App 建议 |
|-------|--------|----------|
| 0 | `CLEAN` | 正常 |
| 1 | `SLIGHT` | 轻度污染 |
| 2 | `HEAVY` | 重度污染 |

**`level >= 2`** → `isLensDirty()`；可 **LOCKED**（`preview_det` **不**走生产 LOCKED）。告警音由 **App** 播放。

### 6.2 native 规则摘要

单类 **`contamination`**；**圆形 mask** + 滑动窗口：

| 条件 | `frame_level` |
|------|----------------|
| 无检出 | 0 |
| 至少一框中心在 mask **内** | 2 |
| 仅框中心在 mask **外** | 1 |

窗口：`level2_min_frames` / `level1_min_frames` / `consecutive_frames_thresh`。

> **BREAKING（2026-05）**：已移除烧蚀类、`rule1`、全图面积占比、core 区等旧规则。

### 6.3 App 落点

- `LensGuardManager` → `LensCheckResultEvent`
- `AiVisionFragment`：overlay；`preview_det` 时解析 JSON `message`
- AI Vision Tab：**不**弹生产阻断弹窗

---

## 7. 分类（cls）— 只读 JNI

默认 **det-only** 可跳过本节。

```java
String nativeGetLastClsResult(long handle);
```

- det：`onCheckResult` push；cls：`nativeGetLastClsResult` pull → 独立 Event
- **禁止**把 cls JSON 塞进 `onCheckResult.message`

恢复 cls：`models.cls.enabled: true` + 重启 native 会话。

---

## 8. 职责边界

| App | Native |
|-----|--------|
| 激光状态 → `nativeSetLaserOn` | 按 App 标志调度 |
| `nativePushFrame`、预览开关 | `infer_stain` + mask **level** |
| overlay、告警、联锁 UI | `onCheckResult` / `preview_det` JSON |

---

## 9. AI Vision Tab（预览 + 离线推理）

### 9.0 det-only

- `nativeGetLastClsResult` 长期 **`valid:false`**；激光 ON **无** `MONITORING(1)`。

### 9.1 生产 vs 预览

| | 生产 | AI Vision 预览 |
|--|------|----------------|
| 污点 | 周期/焊后；`level>=2` 可联锁 | 每推帧 `preview_det` JSON；**不**生产 LOCKED |
| det | `onCheckResult` 文本 | `message` 含 `"source":"preview_det"` + `boxes` |

### 9.2–9.3 生命周期与 UI

`nativeStart` + 持续 `nativePushFrame`；进 Tab 开 preview cls/det；离开关闭。`nativeSetLaserOn` 反映真实激光。

### 9.4 离线单次推理（`StainInferOutcome`）

| 场景 | 调用链 |
|------|--------|
| RGBA 时间轴 | `guardedInferRgb` → `nativeInferRgb` |
| JPG | `guardedInferImage` → `nativeInferImage` |
| 单次 I420 | `guardedInferI420` → `nativeInferI420`（**勿** push+wait） |

- 成功：`code==0`；`source=offline_infer` 或 `live_infer`；`boxes[]` 为该帧像素（上限 `stain_max_det`）
- Legacy：`*ToJson` 字符串；无符号时回退并 log 一次
- 详见 [`NATIVE_UNIFIED_INFER_API.md`](NATIVE_UNIFIED_INFER_API.md) §5–§6

### 9.5–9.6 其它离线 API

- **`nativeInferVideoAndSave`**：仅画框 MP4；**无** `onCheckResult` / 窗口 level → [`native-infer-video-and-save.md`](native-infer-video-and-save.md)
- **`nativeInferImageAndSave`**：写标注图；等级在 `onCheckResult` → [`native-infer-image-and-save.md`](native-infer-image-and-save.md)

### 9.7 离线 JNI 验收

```bash
bash scripts/verify_libai_jni.sh libai.so
nm -D libai.so | grep nativeInferImage
nm -D libai.so | grep nativeInferRgb
```

**Engine started / 实时推帧不能代替**离线能力。缺符号 → 更新 ai-library zip 并重导 bundled 库。

---

## 10. 必做：更新 bundled `libai.so`

```bash
bash scripts/verify_libai_jni.sh /path/to/libai.so
```

| 结果 | 动作 |
|------|------|
| OK（含 `nativeInferImage` 等） | 可配对离线能力 |
| 缺符号 | 更新 zip；OTA `bundled-libraries/ai-library/` |

典型失败：`UnsatisfiedLinkError: nativeInferImage` →「推理视频尚未准备好」。

### 10.1 App 检查项（离线）

- [ ] `NativeBridge` 声明 `nativeInferImage` / `nativeInferRgb` / `nativeInferI420`
- [ ] `isNativeStainInferLinked()` 或分项 probe
- [ ] RKNN 单线程 `guarded*`
- [ ] overlay 按 `imageWidth`×`imageHeight`
- [ ] **勿** `inferFromI420` 用 push+wait

---

## 11. `config.yaml` 部署（App 相关）

| 键 | 仓库示例 / 产线常见 | 注意 |
|----|---------------------|------|
| `models.cls.enabled` | `false` | det-only |
| `models.det.enabled` | `true` | `det_raw_head.rknn` |
| `algorithm.stain_score_mode` | `logits` | 必填 |
| `algorithm.stain_conf_thresh` | `0.25` / 产线 **0.65** | 以设备 yaml 为准 |
| `algorithm.stain_nms_thresh` | `0.45` / 产线 **0.55** | 同上 |
| `algorithm.stain_max_det` | `25` / 产线 **100** | **勿为 0**（0=不截断） |
| `stain_detection.mask_center_x/y` | `885` / `430` | |
| `stain_detection.mask_radius_px` | `280` | |
| `stain_detection.mask_ref_width/height` | `1920` / `1080` | |

---

## 12. 验收清单与 Code Review

### 12.1 台架验收

1. `verify_libai_jni.sh` 通过。
2. **1920×1080** 推流：`preview_det` 与生产 `onCheckResult` 框/level 一致。
3. AI Vision 预览：激光 OFF + preview det ON → 无生产 LOCKED（见 [`SUBSTREAM_REALTIME_VERIFICATION.md`](SUBSTREAM_REALTIME_VERIFICATION.md)）。
4. 圆心附近污点 → level 2；仅边缘 → level 1。
5. 离线时间轴：`nativeInferRgb` 含 `level`。
6. det-only：无 `MONITORING(1)`；cls 长期 `valid:false`。

### 12.2 Code Review 对照

| 模块 | 核对 |
|------|------|
| Overlay | 全图坐标；无 App 640/700 变换 |
| `AiVisionFragment` | `guardedInferRgb`；按帧宽高画框 |
| `LensGuardManager` | `nativeInfer*` → `StainInferOutcome` |
| 焊中 UI | 不依赖 `MONITORING(1)` |
| ai-library | 含 `det_raw_head` + 700 ROI 的 `libai.so` |

---

## 13. 常见问题

| 现象 | 可能原因 |
|------|----------|
| RKNN 崩溃 | `librknnrt` 与 BSP 不匹配 |
| 离线上传「推理视频尚未准备好」 | 无 `nativeInferImage` / `nativeInferRgb` |
| cls 长期 `valid:false` | det-only 预期 |
| 有框但 level=CLEAN | 框在 mask 外或窗口未满 |
| 框位置偏移 | 旧 so 用 letterbox/中心 640 |
| overlay 框偏大/偏小 | App 误二次缩放 |

---

## 14. 代码索引

| 路径 |
|------|
| `lensinspector/java/com/lasercyber/lws/ai/NativeBridge.java` |
| App：`LensGuardManager`、`AiVisionFragment`、`AssetDeployer` |
| `lensinspector/config.yaml` |

历史真机记录：[`DEVICE_VERIFICATION_2026-05-19.md`](DEVICE_VERIFICATION_2026-05-19.md)（**libai 1.1.8** 场景，仅供参考）。
