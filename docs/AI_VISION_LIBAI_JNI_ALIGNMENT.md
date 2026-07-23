# AI Vision 离线推理：`libai.so` 与 App 1.0.27 对齐说明

AI Vision **离线抽帧上传**依赖 JNI `nativeInferImageToJson`。App **1.0.27** 已声明并调用该接口；若设备上的 `libai.so` 未导出对应符号，离线推理失败，上传会提示「推理视频尚未准备好」。

---

OpenSpec 实现追踪：[`openspec/changes/lens-guard-engine-alignment-2026-05-19/`](openspec/changes/lens-guard-engine-alignment-2026-05-19/)（含 `LensGuardCapabilityProfile`、运行时 JNI 探测、离线 MP4 门禁）。引擎侧摘要：[`LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](LENS_GUARD_APP_ALIGNMENT_2026-05-19.md)。

**真机推理问题归档**（多框饱和、`nativeInferVideoAndSave`、libai 1.2.5–1.2.7、部署与 log）：[`docs/AI_VISION_INFERENCE_TROUBLESHOOTING_ARCHIVE.md`](docs/AI_VISION_INFERENCE_TROUBLESHOOTING_ARCHIVE.md)。

## 对齐矩阵（重点）

| 组件 | 当前仓库 / 设备基准 | 要求 |
|------|---------------------|------|
| **App** | `versionName` **1.0.27**（`app/build.gradle.kts`） | 含 `NativeBridge.nativeInferImageToJson`、`LensGuardManager.inferJpgToJson`、`AiVisionFragment` 离线时间轴 |
| **Java 引入** | commit `cafaea7`（`feat(ai-vision): 离线录像推理…`） | 与上述 App 版本一并发布 |
| **bundled ai-library** | APK 内 `assets/ai-library/libai_v1.1.8-beta.zip` | **不足以**满足离线 JSON 推理（见下文反例） |
| **运行时 libai.so** | `files/bundled-libraries/ai-library/<storageDir>/jniLibs/arm64-v8a/libai.so` | **必须**导出 JNI（见「验收」） |
| **LensGuard 引擎** | 未设置 `DISABLE_LENS_GUARD` 且 logcat 有 `Engine started` | 仅保证实时推帧；**不能**代替 `nativeInferImageToJson` |
| **模拟器（AVD）** | logcat 有 `emulator_libs_only_no_npu` 或 `Emulator: native libraries loaded`；**无** `Engine started` | so 已加载，**无** RKNN 会话；`isRunning()==false`，离线/推理 API 会失败并提示无 NPU；见 [`LENS_GUARD_APP_INTEGRATION.md` §2.1](LENS_GUARD_APP_INTEGRATION.md) |

> **版本号 ≠ 能力**：zip 文件名里的 `1.1.8-beta` 只决定解压目录名；是否支持离线 JSON 以 **so 是否含符号** 为准。

---

## JNI 与 Java 入口（与 NativeBridge 一致）

| 层级 | 符号 / 方法 |
|------|-------------|
| Native | `Java_com_lasercyber_lws_ai_NativeBridge_nativeInferImageToJson(JLjava/lang/String;)Ljava/lang/String;` |
| Java 声明 | `NativeBridge.nativeInferImageToJson(long handle, String imagePath)` |
| 封装 | `NativeBridge.guardedInferImageToJson` → RKNN 单线程 |
| App 调用 | `LensGuardManager.inferFromI420` ← `I420FrameUtil` ← `AiVisionFragment` / `ProcessVideoAiSession` 抽帧 |

成功时 native 返回 JSON，**`code` 必须为 `0`**（`AiVisionFrameInference.fromNativeJson` 校验）。  
失败时常见 `message`：`nativeInferImageToJson failed or unavailable`（`code` **-1007** 等）。

---

## 含该 JNI 的 native 交付物（应对齐目标）

YOLO / lensinspector 交付的 **`lens_guard_engine_<version>.zip`**（导入为 `ai-library`）中，`jniLibs/arm64-v8a/libai.so` 须 **新于** 仅含 `nativeInferImageAndSave` 的旧包。

**构建侧**：`make build`（默认 `staging.json`）拉取的 `ai-library` manifest 条目，须指向 **已含 `nativeInferImageToJson` 实现** 的 zip；打 1.0.27 发布包前在真机做一次「验收」。

**命名示例（目标态，以 Workers manifest `version` / `filename` 为准）**：

```text
assets/ai-library/libai_v<含离线JSON能力的版本>.zip
  └── jniLibs/arm64-v8a/libai.so   # 含 nativeInferImageToJson
```

具体 SemVer 以 YOLO 发布说明为准；在 manifest 未更新前，**不要假设** `1.1.8-beta` 已满足。

---

## 现场验收（设备 / 台架）

**logcat（失败特征）**

```text
UnsatisfiedLinkError: No implementation found for ... nativeInferImageToJson
AiVisionFragment: AI Vision offline video inference failed
IllegalStateException: nativeInferImageToJson failed or unavailable
```

**符号检查**（对实际加载的 so，路径因安装而异）

```bash
nm -D libai.so | grep nativeInferImageToJson
# 有输出 = 与 App 1.0.27 可配对；无输出 = 需更换 ai-library zip
```

**功能检查**：AI Vision 选片 → 等待离线分析完成 → 点「上传」不应再出现「推理视频尚未准备好」（且 `files/ai-vision-inference-videos/` 下应有非空 `.mp4`）。

---

## 已知反例（04624f28aaf5e60f，2026-05-18）

| 项 | 值 |
|----|-----|
| App | 1.0.27，`libai_v1.1.8-beta.zip` |
| LensGuard | `Engine started`（实时路径正常） |
| 离线推理 | `UnsatisfiedLinkError` → 无推理 MP4 → 上传 Toast「推理视频尚未准备好」 |

**处理**：向 Workers 更新/替换为 **含 `nativeInferImageToJson` 的 ai-library** 后重装 APK，或 OTA/启动导入更新 `bundled-libraries/ai-library`（必要时清应用数据以强制重新导入 bundled zip）。

---

## 离线检测框异常（满屏 / y2=0）

若 `nativeInferImageToJson` **已链接**但返回每帧约 80 个 `y2=0` 框，见 **[docs/AI_VISION_OFFLINE_INFERENCE_BOX_FIX.md](docs/AI_VISION_OFFLINE_INFERENCE_BOX_FIX.md)**（App 兜底 + 引擎根治与验收）。

---

## 相关代码

- `app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java` — JNI 声明与 `guardedInferImageToJson`
- `app/src/main/java/com/lasercyber/lws/ai/LensGuardManager.java` — `inferFromI420`；`inferFromJpg` 仅遗留磁盘 JPG
- `app/src/main/java/com/lasercyber/lws/ai/I420FrameUtil.java` — Bitmap/ARGB → I420
- `app/src/main/java/com/lasercyber/lws/ui/activitys/device/monitor/fragment/AiVisionFragment.java` — 离线时间轴与上传门禁
- `docs/LENS_GUARD_APP_INTEGRATION.md` — Lens Guard 总览（§10 离线能力见本文）
