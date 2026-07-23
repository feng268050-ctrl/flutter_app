# Lens Guard / libai.so — NativeBridge JNI API（完整索引）

| 项 | 值 |
|----|-----|
| **文档更新时间** | **2026-05-27** |
| **Java 声明（权威源码）** | [`java/com/lasercyber/lws/ai/NativeBridge.java`](../java/com/lasercyber/lws/ai/NativeBridge.java) |
| **JNI 实现** | [`src/jni_bridge.cpp`](../src/jni_bridge.cpp) |
| **集成总览（职责 / 规则 / FAQ）** | [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) |

本文是 **`com.lasercyber.lws.ai.NativeBridge` 全部对外 JNI 的单页索引**。实现细节、训练几何、App 落点见文末「相关文档」；本文侧重**签名、线程/缓冲约定、返回值与 JSON 形状**。

---

## 目录

1. [API 总表](#1-api-总表)
2. [库加载与句柄](#2-库加载与句柄)
3. [生命周期](#3-生命周期)
4. [实时推帧](#4-实时推帧)
5. [单次污点推理（推荐 typed）](#5-单次污点推理推荐-typed)
6. [Legacy `*ToJson`](#6-legacy-tojson)
7. [诊断：写标注图 / 写标注视频](#7-诊断写标注图--写标注视频)
8. [激光与 AI Vision 预览](#8-激光与-ai-vision-预览)
9. [设备 / 相机上下文（可选）](#9-设备--相机上下文可选)
10. [状态查询](#10-状态查询)
11. [分类只读](#11-分类只读)
12. [监听器 `NativeListener`](#12-监听器-nativelistener)
13. [数据类型](#13-数据类型)
14. [能力探测 `isNative*`](#14-能力探测-isnative)
15. [返回码对照](#15-返回码对照)
16. [JSON 载荷形状](#16-json-载荷形状)
17. [发布验收 `verify_libai_jni.sh`](#17-发布验收-verify_libai_jnish)
18. [lws-ui 映射建议](#18-lws-ui-映射建议)
19. [集成检查清单](#19-集成检查清单)
20. [相关文档](#20-相关文档)

---

## 1. API 总表

| 分类 | 方法 | 返回 | 说明 |
|------|------|------|------|
| 生命周期 | `nativeCreate` | `long` | 创建调度器；`0` 失败 |
| | `nativeStart` | `void` | 后台主循环 |
| | `nativeStop` | `void` | 停止并等待工作线程 |
| | `nativeDestroy` | `void` | 释放资源（先 `nativeStop`） |
| 实时 | `nativePushFrame` | `void` | direct I420 入队；结果走 `onCheckResult` |
| 单次推理 | `nativeInferImage` | `StainInferOutcome` | JPG/路径，**推荐** |
| | `nativeInferRgb` | `StainInferOutcome` | direct RGBA，**推荐** |
| | `nativeInferI420` | `StainInferOutcome` | direct I420 单次，**推荐** |
| Legacy | `nativeInferImageToJson` | `String` | 同语义 JSON |
| | `nativeInferRgbToJson` | `String` | 同语义 JSON |
| | `nativeInferI420ToJson` | `String` | 同语义 JSON |
| 诊断 | `nativeInferImageAndSave` | `int` | 写标注图；等级在 `onCheckResult` |
| | `nativeInferVideoAndSave` | `int` | 写带框 MP4；无 per-frame 回调 |
| 激光 / 预览 | `nativeSetLaserOn` | `void` | App 判激光开/关 |
| | `nativeSetAiVisionPreviewClassificationEnabled` | `void` | 激光 OFF 时预览分类 |
| | `nativeSetAiVisionPreviewDetectionEnabled` | `void` | 激光 OFF 时 `preview_det` |
| 上下文（可选） | `nativeSetDeviceContext` | `void` | SN / 工位 |
| | `nativePushCameraParams` | `void` | 曝光 / 增益 / 光强 / fps |
| | `nativePushFrameMeta` | `void` | 时间戳 / frameId |
| | `nativeNotifyModelSwitched` | `void` | 模型版本切换 |
| 查询 | `nativeGetState` | `int` | 0 IDLE / 1 MONITORING / 2 LOCKED |
| | `nativeGetStainLevel` | `int` | 0 clean / 1 slight / 2 heavy |
| | `nativeIsLensDirty` | `boolean` | `level >= 2` |
| | `nativeGetLastClsResult` | `String` | 分类快照 JSON（pull） |
| 回调 | `nativeSetListener` | `void` | 注册 / 清除 `NativeListener` |
| 探测 | `isNativeStainInferLinked` 等 | `boolean` | 见 [§14](#14-能力探测-isnative) |

---

## 2. 库加载与句柄

```java
static {
    System.loadLibrary("c++_shared");
    System.loadLibrary("rknnrt");
    System.loadLibrary("ai");   // libai.so
}

long handle = NativeBridge.nativeCreate(configPath, projectRoot);
```

| 参数 | 说明 |
|------|------|
| `configPath` | 设备上 `config.yaml` 绝对路径（如 `files/lens_guard/config.yaml`） |
| `projectRoot` | 引擎工作根目录（如 `files/lens_guard/`） |
| 返回值 | 不透明句柄；`0` 表示创建失败 |

`librknnrt.so` 须与设备 **BSP NPU** 匹配。RKNN 相关单次推理须在 App 的 **RKNN 守护线程** 串行调用（如 `guardedInfer*`）。

---

## 3. 生命周期

```java
long handle = NativeBridge.nativeCreate(configPath, projectRoot);
NativeBridge.nativeSetListener(handle, listener);  // 可选，建议早于 Start
NativeBridge.nativeStart(handle);

// … 运行期推帧 / 推理 / 设激光 …

NativeBridge.nativeStop(handle);
NativeBridge.nativeDestroy(handle);
```

| 方法 | 说明 |
|------|------|
| `nativeCreate(String configPath, String projectRoot)` | 加载配置与模型；**不**自动开线程 |
| `nativeStart(long handle)` | 启动调度器主循环（后台线程） |
| `nativeStop(long handle)` | 停止主循环并 join |
| `nativeDestroy(long handle)` | 释放 native 资源；**在** `nativeStop` 之后调用 |

**不要求** `nativeStart` 的 API：`nativeInferImage*`、`nativeInferRgb*`、`nativeInferI420*`、`nativeInferImageAndSave`、`nativeInferVideoAndSave`（复用同一 `handle` 上的 RKNN 上下文）。

---

## 4. 实时推帧

```java
public static native void nativePushFrame(
        long handle,
        ByteBuffer i420,
        int width,
        int height);
```

| 项 | 约定 |
|----|------|
| 来源 | 解码回调（如 `EasyPlayerClient.onI420Data`） |
| 格式 | **I420 (YUV420P)**，`capacity >= width * height * 3 / 2` |
| 缓冲 | **`i420` 必须为 direct `ByteBuffer`**；禁止 `buffer.get(byte[])` |
| 线程 | 可从任意线程调用；内部 I420→BGR 入队，**不**在调用线程阻塞 RKNN |
| 结果 | `NativeListener.onCheckResult`（生产路径 / 周期检测）；预览见 [§8](#8-激光与-ai-vision-预览) |

产品标定推帧分辨率常为 **1920×1080**；检测框坐标已是**该推帧分辨率下的全图像素**（引擎内 ROI 还原），App **禁止**再做 letterbox / `700/640` 变换。见 [`APP_ALIGNMENT_BRIEF.md`](APP_ALIGNMENT_BRIEF.md)。

---

## 5. 单次污点推理（推荐 typed）

与实时路径区分：**不写盘、不走 `onCheckResult`、不入推帧队列**。成功时 native 已算好 `level` / `status`，App **禁止**重算。

### 5.1 签名

```java
public static native StainInferOutcome nativeInferImage(long handle, String imagePath);

public static native StainInferOutcome nativeInferRgb(
        long handle, ByteBuffer rgb, int width, int height, int rowStrideBytes);

public static native StainInferOutcome nativeInferI420(
        long handle, ByteBuffer i420, int width, int height);
```

| 方法 | 输入 | 成功时 `source` |
|------|------|-----------------|
| `nativeInferImage` | 可读图片路径 | `offline_infer` |
| `nativeInferRgb` | direct **RGBA_8888** | `offline_infer` |
| `nativeInferI420` | direct **I420**（同 `nativePushFrame`） | `live_infer` |

| 缓冲 | 约定 |
|------|------|
| RGBA | direct；`rowStrideBytes == 0` 表示 `width * 4`；容量 ≥ `stride * (height - 1) + width * 4` |
| I420 | 同 [§4](#4-实时推帧) |

### 5.2 设计原则

| 原则 | 说明 |
|------|------|
| **少 marshalling** | JNI 直接填充 `StainInferOutcome` / `StainBox[]`，热路径无 JSON |
| **动词方法名** | `nativeInferImage` / `Rgb` / `I420`（与 `nativeInferImageAndSave`、`*ToJson` 同族） |
| **实时 vs 单次** | 子码流：`nativePushFrame` + `onCheckResult`；单次：**勿** push 再 wait |

### 5.3 使用示例

```java
StainInferOutcome out = NativeBridge.nativeInferI420(handle, i420Direct, w, h);

if (!out.isSuccess()) {
    Log.w(TAG, "infer failed code=" + out.code + " msg=" + out.errorMessage);
    return;
}

int level = out.level;
for (NativeBridge.StainBox b : out.boxes) {
    drawRect(b.x1, b.y1, b.x2, b.y2);  // 按 out.imageWidth/Height 1:1
}
```

lws-ui 可将 `StainInferOutcome` 映射为 `AiStainDetectResult`，**不必** Gson 解析。

### 5.4 成功字段（`code == 0`）

| 字段 | 说明 |
|------|------|
| `source` | `offline_infer` 或 `live_infer` |
| `level` / `status` / `detailMessage` | native 已定级；英文 `detailMessage` |
| `imageWidth` / `imageHeight` | 该帧像素尺寸 |
| `boxes[]` | 全图 xyxy；含 ROI 还原 |
| `boxesTruncated` / `boxesTotal` | NMS 后超过 `algorithm.stain_max_det`（默认 100）时 |

### 5.5 失败（`code != 0`）

| `code` | 含义 |
|--------|------|
| `0` | 成功 |
| `-1` | 参数 / buffer 错误 |
| `-2` | 读图失败（**仅** `nativeInferImage`） |
| `-3` | RKNN / 后处理异常 |

失败时：`errorMessage` 非空；`source`、`status`、`boxes` 等为 null / 0 / 空数组。

### 5.6 与 C++ 的关系

```
C++ StainInferOutcome  ←── 核心推理结果（唯一真源）
        │
        ├─ JNI → StainInferOutcome（推荐）
        └─ stain_infer_outcome_to_json() → String（仅 *ToJson）
```

---

## 6. Legacy `*ToJson`

旧 App 或缺 typed 符号时的过渡；**新代码优先** [§5](#5-单次污点推理推荐-typed)。

```java
public static native String nativeInferImageToJson(long handle, String imagePath);

public static native String nativeInferRgbToJson(
        long handle, ByteBuffer rgb, int width, int height, int rowStrideBytes);

public static native String nativeInferI420ToJson(
        long handle, ByteBuffer i420, int width, int height);
```

成功 JSON 形状见 [§16.2](#162-offline_infer--tojson)；与 typed 字段一一对应（`message` 对应 `detailMessage`）。无 `nativeInferImage` 符号时可回退 `nativeInferImageToJson` 并 parse。

---

## 7. 诊断：写标注图 / 写标注视频

### 7.1 `nativeInferImageAndSave`

```java
public static native int nativeInferImageAndSave(
        long handle, String imagePath, String outputPath);
```

| 返回值 | 含义 |
|--------|------|
| `0` | 读图、推理、写输出图均成功 |
| `-1` | handle / 路径参数错误 |
| `-2` | 无法读入或解码输入图 |
| `-3` | 模型推理失败 |
| `-4` | 无法写出输出图 |

**返回值是管线状态，不是污点等级。** 等级 / `CLEAN`/`HEAVY` 等通过已注册的 `onCheckResult` 下发。详见 [`native-infer-image-and-save.md`](native-infer-image-and-save.md)。

### 7.2 `nativeInferVideoAndSave`

```java
public static native int nativeInferVideoAndSave(
        long handle, String inputVideoPath, String outputVideoPath);
```

| 返回值 | 含义 |
|--------|------|
| `0` | 输出 MP4 已写出且 `size > 0` |
| `-1` | handle 无效或路径为空 |
| `-2` | 无法打开输入或帧尺寸无效 |
| `-3` | 推理异常或 `nativeStop` 取消 |
| `-4` | 无法创建输出编码器 |
| `-5` | 输入无有效帧 |

- 与实时相同 `infer_stain` 路径；约 **500ms** 抽帧推理，**每源帧都写出**（帧间沿用上一组框）。
- **不**触发 `onCheckResult`；**不**做窗口等级聚合。
- 详见 [`native-infer-video-and-save.md`](native-infer-video-and-save.md)。

---

## 8. 激光与 AI Vision 预览

```java
public static native void nativeSetLaserOn(long handle, boolean on);

public static native void nativeSetAiVisionPreviewClassificationEnabled(long handle, boolean enabled);

public static native void nativeSetAiVisionPreviewDetectionEnabled(long handle, boolean enabled);
```

| 方法 | 行为 |
|------|------|
| `nativeSetLaserOn` | App 根据设备状态同步激光；native **不**读焊机硬件。`true` → 进入监控相关调度（det-only 时无 cls 状态机，见集成文档 §9） |
| `nativeSetAiVisionPreviewClassificationEnabled` | 真实激光 **OFF** 时更新分类缓存，**不**进入 MONITORING |
| `nativeSetAiVisionPreviewDetectionEnabled` | 激光 **OFF** 时每推帧低率 `preview_det`；`onCheckResult.message` 为 JSON（`source=preview_det`） |

| 路径 | 触发 | `onCheckResult` |
|------|------|-----------------|
| 生产 / 周期 | `nativeSetLaserOn` + `nativePushFrame` | 文本或业务 JSON |
| AI Vision 预览 det | 上项 + `nativeSetAiVisionPreviewDetectionEnabled(true)` | `message` 含 `preview_det` + `boxes` |
| 单次离线 | `nativeInfer*` | **无** 此回调 |

离开 AI Vision Tab 时应将两个 preview 开关置 `false`。

---

## 9. 设备 / 相机上下文（可选）

```java
public static native void nativeSetDeviceContext(long handle, String sn, String stationId);

public static native void nativePushCameraParams(
        long handle, float exposureTime, float gain, float lightLevel, float fps);

public static native void nativePushFrameMeta(long handle, long timestampMs, long frameId);

public static native void nativeNotifyModelSwitched(long handle, String modelVersion);
```

追溯与参数风险门控预留接口；**一般 App 可不接**。当前引擎侧多为 no-op 或占位，签名保持稳定以便后续启用。

---

## 10. 状态查询

```java
public static native int nativeGetState(long handle);
public static native int nativeGetStainLevel(long handle);
public static native boolean nativeIsLensDirty(long handle);
```

| 方法 | 返回值 |
|------|--------|
| `nativeGetState` | `0` IDLE，`1` MONITORING，`2` LOCKED；无效 handle → `-1` |
| `nativeGetStainLevel` | `0` clean，`1` slight，`2` heavy |
| `nativeIsLensDirty` | 当前是否判为脏（`level >= 2`） |

实时等级以 **`onCheckResult`** 为准；查询接口用于 UI 轮询或调试。

---

## 11. 分类只读

```java
public static native String nativeGetLastClsResult(long handle);
```

- **Pull** 模型：不触发推理，只读缓存快照。
- **不要**从 `onCheckResult.message` 解析分类。
- det-only（`models.cls.enabled: false`）时长期 `valid: false`。

无效 handle 或无快照时示例：

```json
{"valid":false,"classId":-1,"className":"","score":0.0,
 "topk":[],"timestampMs":0,"modelVersion":"unknown","source":"focus_cls"}
```

有效时典型字段：`valid`、`classId`、`className`（如 `0=其他`，`1=金属`）、`score`、`topk[]`（`classId`/`score`）、`timestampMs`、`modelVersion`、`source`（`focus_cls`）。详见 [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) §6。

---

## 12. 监听器 `NativeListener`

```java
public static native void nativeSetListener(long handle, NativeListener listener);

public interface NativeListener {
    void onStateChanged(int state);   // 0 IDLE, 1 MONITORING, 2 LOCKED
    void onCheckResult(int level, String status, String message);
}
```

| 回调 | 说明 |
|------|------|
| `onStateChanged` | 调度状态变化 |
| `onCheckResult` | 污点检测完成；`level` 0/1/2；`status` 如 `CLEAN`/`SLIGHT`/`HEAVY`；`message` 人类可读或 **`preview_det` JSON** |

回调可能在 **native 工作线程**；更新 UI 须 post 到主线程。`listener == null` 表示移除。

### 12.1 `onCheckResult` 等级（生产）

| level | status（示例） | App 建议 |
|-------|----------------|----------|
| 0 | `CLEAN` | 正常 / 隐藏 |
| 1 | `SLIGHT` | 轻度，建议擦拭 |
| 2 | `HEAVY` | 重度，清洗/更换；可联锁 + `LOCKED` |

规则（mask 圆心 **885,430**、半径 **280** @1920×1080、滑动窗口）在 native 计算，见集成文档 §5。

---

## 13. 数据类型

### 13.1 `StainBox`

```java
public static final class StainBox {
    public final float x1, y1, x2, y2;
    public final int classId;
    public final float score;
}
```

### 13.2 `StainInferOutcome`

```java
public static final class StainInferOutcome {
    public final int code;
    public final String errorMessage;   // 失败非空；成功为空串
    public final String source;         // offline_infer | live_infer
    public final int level;
    public final String status;         // CLEAN | SLIGHT | HEAVY
    public final String detailMessage;
    public final int imageWidth, imageHeight;
    public final StainBox[] boxes;
    public final boolean boxesTruncated;
    public final int boxesTotal;

    public boolean isSuccess();  // code == 0
}
```

---

## 14. 能力探测 `isNative*`

| 方法 | 探测符号 |
|------|----------|
| `isNativeInferImageLinked()` | `nativeInferImage` |
| `isNativeInferRgbLinked()` | `nativeInferRgb` |
| `isNativeInferI420Linked()` | `nativeInferI420` |
| `isNativeStainInferLinked()` | 以上三者 **全部** 存在 |
| `isNativeInferImageToJson` | （无单独 probe；用 `nativeInferImage` 或试调 ToJson） |
| `isNativeInferRgbToJsonLinked()` | `nativeInferRgbToJson` |
| `isNativeInferI420ToJsonLinked()` | `nativeInferI420ToJson`（deprecated，优先 `isNativeInferI420Linked`） |
| `isNativeInferVideoAndSaveLinked()` | `nativeInferVideoAndSave` |

探测实现：以无效 handle 试调一次，缓存 `UnsatisfiedLinkError` 结果，**不**跑真实推理。

---

## 15. 返回码对照

| API 族 | 成功 | 常见失败 |
|--------|------|----------|
| `StainInferOutcome.code` | `0` | `-1` 参数/buffer，`-2` 读图（path only），`-3` RKNN |
| `nativeInferImageAndSave` | `0` | `-1`…`-4` 见 [§7.1](#71-nativeinferimageandsave) |
| `nativeInferVideoAndSave` | `0` | `-1`…`-5` 见 [§7.2](#72-nativeinfervideoandsave) |
| `nativeCreate` | 非 0 handle | `0` handle |
| `nativeGetState` | `0`/`1`/`2` | `-1` 无效 handle |

---

## 16. JSON 载荷形状

### 16.1 `preview_det`（`onCheckResult.message`）

当 `nativeSetAiVisionPreviewDetectionEnabled(true)` 且激光 OFF 时，`message` 为单行 JSON，例如：

```json
{
  "code": 0,
  "source": "preview_det",
  "level": 1,
  "status": "SLIGHT",
  "message": "Slight — wipe recommended (outside mask)",
  "imageWidth": 1920,
  "imageHeight": 1080,
  "maxConfidence": 0.87,
  "boxes": [{"x1":…,"y1":…,"x2":…,"y2":…,"classId":0,"score":0.87,"confidence":0.87}],
  "boxesTruncated": false
}
```

`boxes` 为**推帧分辨率**全图坐标；解析用 `isPreviewDetMessage(message)` 等 App 工具。

### 16.2 `offline_infer` / `*ToJson`

成功时与 `StainInferOutcome` 对齐（字段名 `message` 而非 `detailMessage`）：

```json
{
  "code": 0,
  "source": "offline_infer",
  "level": 0,
  "status": "CLEAN",
  "message": "Clean",
  "imageWidth": 1280,
  "imageHeight": 720,
  "boxes": [ … ]
}
```

`nativeInferI420ToJson` 成功时 `source` 为 **`live_infer`**。失败：`code < 0`，仅 `message` 错误说明。

---

## 17. 发布验收 `verify_libai_jni.sh`

```bash
bash scripts/verify_libai_jni.sh /path/to/libai.so
```

脚本校验的动态符号（`Java_com_lasercyber_lws_ai_NativeBridge_*`）包括：

`nativeCreate`、`nativeDestroy`、`nativeStart`、`nativePushFrame`、`nativeSetLaserOn`、`nativeSetAiVisionPreviewDetectionEnabled`、`nativeInferImageAndSave`、`nativeInferImageToJson`、`nativeInferImage`、`nativeInferI420ToJson`、`nativeInferI420`、`nativeInferRgbToJson`、`nativeInferRgb`、`nativeInferVideoAndSave`。

**未列入必填、但存在于 Java 的符号**（发布前建议 `nm -D` 人工确认）：`nativeStop`、`nativeSetListener`、`nativeGetState`、`nativeInferRgb` 等完整列表见 [§1](#1-api-总表)。

新 App 离线能力：优先确认 **`nativeInferImage` + `nativeInferRgb` + `nativeInferI420`**（`isNativeStainInferLinked()`）。

---

## 18. lws-ui 映射建议

| App（lws-ui） | Native |
|---------------|--------|
| `LensGuardManager` 生命周期 | `nativeCreate` / `Start` / `Stop` / `Destroy` |
| `onI420Data` | `nativePushFrame(handle, buffer, w, h)` |
| `inferFromJpg` | `guardedInferImage` → `nativeInferImage` |
| `inferFrame` / 时间轴 RGBA | `guardedInferRgb` → `nativeInferRgb` |
| `inferFromI420` | `guardedInferI420` → `nativeInferI420` |
| `inferJpgAndSaveResult` | `nativeInferImageAndSave` |
| `inferVideoAndSave` | `nativeInferVideoAndSave` |
| 激光状态 | `nativeSetLaserOn` |
| AI Vision Tab | preview cls/det 开关 + `nativeGetLastClsResult` |

---

## 19. 集成检查清单

- [ ] `verify_libai_jni.sh` 通过
- [ ] `isNativeStainInferLinked()` 为 true（新离线时间轴）
- [ ] 单次推理用 `StainInferOutcome` 字段，**不** parse 多余 JSON
- [ ] `inferFromI420` **未**使用 `pushFrame` + 等待回调
- [ ] I420 / RGBA 均为 **direct** `ByteBuffer`（禁止 `buffer.get(byte[])`）
- [ ] overlay 框按回调 / `imageWidth`×`imageHeight` **1:1**，禁止二次 letterbox
- [ ] App **不重算** `level`；激光由 App → `nativeSetLaserOn`
- [ ] cls 走 `nativeGetLastClsResult`，**不**塞进 `onCheckResult.message`

---

## 20. 相关文档

| 文档 | 内容 |
|------|------|
| [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) | 交付物、职责边界、det/cls 规则、AI Vision、FAQ |
| [`APP_ALIGNMENT_BRIEF.md`](APP_ALIGNMENT_BRIEF.md) | 坐标 / mask / 框对齐 |
| [`SUBSTREAM_REALTIME_FEATURE_AND_API.md`](SUBSTREAM_REALTIME_FEATURE_AND_API.md) | 子码流实时归档 |
| [`native-infer-image-and-save.md`](native-infer-image-and-save.md) | `nativeInferImageAndSave` 详解 |
| [`native-infer-video-and-save.md`](native-infer-video-and-save.md) | `nativeInferVideoAndSave` 详解 |
| [`native-infer-image-to-json.md`](native-infer-image-to-json.md) | Legacy JSON 台架对照 |
| [`训练推理后处理对齐说明.md`](训练推理后处理对齐说明.md) | ROI / mask / 训练几何 |
