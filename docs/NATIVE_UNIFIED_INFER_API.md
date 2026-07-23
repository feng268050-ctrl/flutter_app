# Lens Guard 单次推理 — 外部 App 对接 API


| 项           | 值                                                                                                 |
| ----------- | ------------------------------------------------------------------------------------------------- |
| **文档更新时间**  | **2026-05-27**                                                                                    |
| **Java 声明** | `[java/com/lasercyber/lws/ai/NativeBridge.java](../java/com/lasercyber/lws/ai/NativeBridge.java)` |
| **集成总览**    | `[LENS_GUARD_APP_INTEGRATION.md](../LENS_GUARD_APP_INTEGRATION.md)`                               |


本文描述 **单次污点推理** 的对外 API。推荐路径由 native **直接填充 Java 字段**（`StainInferOutcome` / `StainBox`），**不在 JNI 边界传递 JSON 字符串**。Legacy `*ToJson` 仅用于旧 `libai.so` 回退。

---

## 1. 设计原则


| 原则                | 说明                                                                                                                 |
| ----------------- | ------------------------------------------------------------------------------------------------------------------ |
| **少 marshalling** | 推荐 API 在 JNI 层设置 `int` / `float` / `String` / 对象数组，避免「C++ 拼 JSON → Java 再 parse」                                   |
| **动词方法名**         | `nativeInferImage` / `nativeInferRgb` / `nativeInferI420`（与 `nativeInferImageAndSave`、`nativeInferImageToJson` 同族） |
| **类型名用名词**        | 返回类型 `StainInferOutcome`、`StainBox` 为数据类，允许名词                                                                      |
| **实时 vs 单次**      | 子码流仍用 `nativePushFrame` + `onCheckResult`；本文 API **不**写盘、**不**走回调                                                  |


---

## 2. 函数签名一览

```java
// ── 推荐：typed outcome（无 JSON 字符串）────────────────────────────

public static native StainInferOutcome nativeInferImage(
        long handle,
        String imagePath);

public static native StainInferOutcome nativeInferRgb(
        long handle,
        ByteBuffer rgb,
        int width,
        int height,
        int rowStrideBytes);

public static native StainInferOutcome nativeInferI420(
        long handle,
        ByteBuffer i420,
        int width,
        int height);

public static native void nativePushFrame(
        long handle,
        ByteBuffer i420,
        int width,
        int height);

// ── Legacy：整段 JSON 字符串（仅旧库 / 过渡）────────────────────────

public static native String nativeInferImageToJson(long handle, String imagePath);

public static native String nativeInferRgbToJson(
        long handle, ByteBuffer rgb, int width, int height, int rowStrideBytes);

public static native String nativeInferI420ToJson(
        long handle, ByteBuffer i420, int width, int height);

// ── 能力探测 ───────────────────────────────────────────────────────

public static boolean isNativeStainInferLinked();

public static boolean isNativeInferImageLinked();

public static boolean isNativeInferRgbLinked();

public static boolean isNativeInferI420Linked();
```

### 2.1 返回类型 `StainBox`

```java
public static final class StainBox {
    public final float x1, y1, x2, y2;
    public final int classId;
    public final float score;

    public StainBox(float x1, float y1, float x2, float y2, int classId, float score);
}
```

### 2.2 返回类型 `StainInferOutcome`

```java
public static final class StainInferOutcome {
    public final int code;              // 0 = success
    public final String errorMessage;   // 失败时说明；成功为空串
    public final String source;         // 成功：offline_infer | live_infer
    public final int level;             // 成功：0/1/2
    public final String status;         // 成功：CLEAN | MILD | HEAVY
    public final String detailMessage;  // 成功：英文提示
    public final int imageWidth;
    public final int imageHeight;
    public final StainBox[] boxes;      // 成功：全图坐标；可能 length 0
    public final boolean boxesTruncated;
    public final int boxesTotal;

    public StainInferOutcome(int code, String errorMessage, String source,
                             int level, String status, String detailMessage,
                             int imageWidth, int imageHeight,
                             StainBox[] boxes, boolean boxesTruncated, int boxesTotal);

    public boolean isSuccess();
}
```

---

## 3. 前置条件

```java
System.loadLibrary("c++_shared");
System.loadLibrary("rknnrt");
System.loadLibrary("ai");

long handle = NativeBridge.nativeCreate(configPath, projectRoot);
```

- 在 **RKNN 守护线程** 调用 `nativeInfer`*（`guardedInferImage` 等）。
- `nativeInferRgb` 的 `rgb` 必须为 **direct** `ByteBuffer`（`RGBA_8888`）。
- `nativeInferI420` / `nativePushFrame`：`i420` 为 **direct** `ByteBuffer`，`capacity >= width * height * 3 / 2`。**禁止** `buffer.get(byte[])`。

发布验收：

```bash
bash scripts/verify_libai_jni.sh /path/to/libai.so
```

须导出：`nativeInferImage`、`nativeInferRgb`、`nativeInferI420`。

---

## 4. 推荐使用方式

```java
// 单次 I420（解码回调里的 direct buffer，勿拷贝）
StainInferOutcome out = NativeBridge.nativeInferI420(handle, i420Direct, w, h);

// 实时推帧
NativeBridge.nativePushFrame(handle, i420Direct, w, h);

if (!out.isSuccess()) {
    Log.w(TAG, "infer failed code=" + out.code + " msg=" + out.errorMessage);
    return;
}

// 直接使用字段，无需 JSON 解析
int level = out.level;
for (NativeBridge.StainBox b : out.boxes) {
    drawRect(b.x1, b.y1, b.x2, b.y2);
}
```

lws-ui 可将 `StainInferOutcome` 映射为 `LensGuardInferenceResult`（字段一一对应，**不必**经过 Gson/JSON）。

---

## 5. 成功字段说明（`code == 0`）


| 字段                                   | 说明                                                 |
| ------------------------------------ | -------------------------------------------------- |
| `source`                             | `offline_infer`（path / RGB）或 `live_infer`（I420 单次） |
| `level` / `status` / `detailMessage` | native 已算等级；App **禁止**重算                           |
| `imageWidth` / `imageHeight`         | 该帧像素尺寸；画框 1:1，勿按推流分辨率缩放                            |
| `boxes[]`                            | 全图 xyxy；已含引擎 ROI 还原                                |
| `boxesTruncated` / `boxesTotal`      | NMS 后超过 `stain_max_det`（默认 100）时                   |


---

## 6. 失败（`code != 0`）


| `code` | 含义                             |
| ------ | ------------------------------ |
| `0`    | 成功                             |
| `-1`   | 参数 / buffer 错误                 |
| `-2`   | 读图失败（**仅** `nativeInferImage`） |
| `-3`   | RKNN / 后处理异常                   |


失败时：`errorMessage` 非空；`source`、`status`、`boxes` 等为 null / 0 / 空数组。

---

## 7. 三个入口对照


| JNI                | 输入                       | 成功 `source`           |
| ------------------ | ------------------------ | --------------------- |
| `nativeInferImage` | 文件路径                     | `offline_infer`       |
| `nativeInferRgb`   | direct RGBA              | `offline_infer`       |
| `nativeInferI420`  | direct I420 `ByteBuffer` | `live_infer`          |
| `nativePushFrame`  | direct I420 `ByteBuffer` | 实时队列（`onCheckResult`） |


除 `source` 与输入方式外，**成功时字段语义相同**。

---

## 8. Legacy `*ToJson` 与 typed API 关系

```
C++ StainInferOutcome  ←── 核心推理结果（唯一真源）
        │
        └─ JNI → StainInferOutcome（App 统一推理唯一路径，无 JSON）
```

lws-ui **仅**使用 typed API（`nativeInferImage` / `nativeInferRgb` / `nativeInferI420`）。`libai.so` 必须与 App 同步发布；`ensureLoaded` 在缺少 typed 符号时 **直接抛 `UnsatisfiedLinkError`**，不会回退 `*ToJson` 或 push+callback 单次推理。

---

## 9. 与其它 JNI 的边界


| API                                 | 返回                         |
| ----------------------------------- | -------------------------- |
| `nativeInferImage` / `Rgb` / `I420` | `StainInferOutcome`        |
| `nativeInferImageToJson` 等          | `String` JSON              |
| `nativePushFrame`                   | `void`；结果在 `onCheckResult` |
| `nativeInferImageAndSave`           | `int`；等级在回调                |


---

## 10. lws-ui 映射（建议）


| App                                   | Native                                   |
| ------------------------------------- | ---------------------------------------- |
| `inferFromJpg`                        | `guardedInferImage` → `nativeInferImage` |
| `inferFrameToJson`（改名建议 `inferFrame`） | `guardedInferRgb` → `nativeInferRgb`     |
| `inferFromI420`                       | `guardedInferI420` → `nativeInferI420`   |


---

## 11. Android 模拟器

AVD 无 Rockchip NPU：`ensureLoaded` 可成功，**不得**调用 `nativeCreate` 或 typed infer（`AiNativeRuntime` / `NativeBridge.guarded*` 短路）。`LensGuardManager.isRunning()` 为 `false`；`inferFrom*` 返回 App 层错误。详见 [`LENS_GUARD_APP_INTEGRATION.md` §2.1](LENS_GUARD_APP_INTEGRATION.md)。

---

## 12. 集成检查清单

- `bash scripts/verify_libai_jni.sh /path/to/libai.so` 通过（含 `nativeInferImage` / `nativeInferRgb` / `nativeInferI420`）
- `ensureLoaded` 后 `isNativeStainInferLinked()` 为 true
- App 使用 `StainInferOutcome` → `LensGuardInferenceResult` 字段映射，**不** parse JSON 字符串
- `inferFromI420` 调用 `guardedInferI420`，**未**使用 `pushFrame` + 等待回调
- I420 / RGBA 均为 **direct** `ByteBuffer`（禁止 `buffer.get(byte[])` 作为 unified infer 热路径）
- ai-library 与 App **同步发布**；忘更新库时启动阶段 fail-fast，而非静默降级

---

## 13. 相关文档


| 文档                                                                  | 内容               |
| ------------------------------------------------------------------- | ---------------- |
| `[LENS_GUARD_APP_INTEGRATION.md](../LENS_GUARD_APP_INTEGRATION.md)` | 全量 JNI           |
| `[APP_ALIGNMENT_BRIEF.md](APP_ALIGNMENT_BRIEF.md)`                  | 坐标 / mask        |
| `[native-infer-image-to-json.md](native-infer-image-to-json.md)`    | Legacy JSON 台架对照 |


