# Lens Guard 真机验证记录（2026-05-19）

> **历史记录**：下表基于 **libai 1.1.8**（无离线 JSON JNI）。当前引擎提供 **`nativeInfer*`**；新验收请用 `bash scripts/verify_libai_jni.sh` 与 [`NATIVE_UNIFIED_INFER_API.md`](NATIVE_UNIFIED_INFER_API.md)。

| 项 | 值 |
|----|-----|
| 设备 | `10.0.1.159:5555`（rk3566_r） |
| App | `com.lasercyber.lws.ui` **1.0.26**（versionCode 191） |
| 验证 APK | `lws-ui` release，`ENABLE_LENS_GUARD_STARTUP=true`（`BuildConfig` 已确认） |
| 设备 ai-library | `files/bundled-libraries/ai-library/1.1.8/jniLibs/arm64-v8a/libai.so` |
| 引擎 so 构建戳 | logcat：`C++ Build May 13 2026 06:40:20` |

对齐说明见 [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) §10–§12。引擎几何/mask 约定以 [`训练推理后处理对齐说明.md`](训练推理后处理对齐说明.md) 与 [`APP_ALIGNMENT_BRIEF.md`](APP_ALIGNMENT_BRIEF.md) 为准（700 ROI、mask 885/430、全图框）。

---

## 验收清单结果

| # | 项 | 结果 | 说明 |
|---|-----|------|------|
| 1 | `nm` 含 `nativeInferImageToJson` | **未通过** | 设备 `libai.so`（1.1.8）无该符号；有 `nativeInferImageAndSave` 等 16 个 JNI |
| 2 | 实时推流 + 污点 `onCheckResult` | **未测** | 需接相机/激光台架；引擎已 `Engine started` |
| 3 | AI Vision `preview_det` overlay | **未测** | 需进入监控页并开预览 |
| 4 | 离线推理 MP4 / 上传 | **阻塞** | 启动即探测失败，见下文 logcat |
| 5 | det-only（无 `MONITORING(1)`） | **部分通过** | `Capability profile`: `classificationEnabled=false`, `focusMonitoringExpected=false` |
| 6 | （可选）cls 回归 | **跳过** | — |

---

## 关键 logcat（冷启动）

```
LensGuardManager: Engine config ready configPath=.../files/lens_guard/config.yaml
LensGuard: [VER] C++ Build  May 13 2026 06:40:20
LensGuardManager: Engine started, handle=...
E ... No implementation found for ... nativeInferImageToJson(long, java.lang.String)
W NativeBridge: nativeInferImageToJson is not exported by libai.so
W LensGuardManager: Offline infer JSON JNI unavailable; AI Vision inference MP4 upload will be blocked until ai-library libai.so is updated
I LensGuardManager: Capability profile: LensGuardCapabilityProfile{classificationEnabled=false, detectionEnabled=true, offlineInferJsonAvailable=false, focusMonitoringExpected=false}
```

与 App 侧 `NativeBridge.isNativeInferImageToJsonLinked()` / `LensGuardManager.buildCapabilityProfile()` 设计一致。

---

## 设备 `config.yaml` 与引擎默认差异

设备 `files/lens_guard/config.yaml`（自 ai-library 1.1.8 解压）：

- **无** `models.cls.enabled` / `models.det.enabled` 块 → App `LensGuardConfigParser` 默认 **cls=false, det=true**（与 det-only 一致）。
- `algorithm.stain_conf_thresh: **0.25**`（引擎仓库默认 **0.65**，见根目录 `config.yaml`）。

部署新 zip 时建议一并更新 bundled `config.yaml`，避免阈值与文档不一致。

### `det_raw_head` 嵌入（2026-05-21）

- 检测 RKNN：`assets/models/det_raw_head.rknn`（三路 raw `raw_p2/p3/p4`，见 [`训练推理后处理对齐说明.md`](训练推理后处理对齐说明.md) §7–8.3）。
- 训练 parity：`stain_score_mode: logits`，`stain_conf_thresh: 0.25`，`stain_nms_thresh: 0.35`（引擎 `config.cpp` 默认值；产线 yaml 可覆盖）。
- 真机 smoke：推流或 `nativeInferImageToJson` 跑污点图，logcat 确认 det 输出数为 3、框合理；需接 rk3566 台架（本仓库 CI 无法代测）。

---

## OpenSpec `det-only-disable-cls`（2026-05-19 复测）

在恢复 **ai-library 1.1.9** 后运行 `DetOnlyOpenSpecDeviceTest`：**通过**。

- `nativeInferImageToJson`：`code==0`，`source=offline_infer`
- 污点单图：`inferJpgAndSave` → `Check result: CLEAN`
- cls stub：`valid:false`
- 冷启动：`offlineInferJsonAvailable=true`，`models.cls.enabled=0`，仅加载 det RKNN

未在本会话验证：接 RTSP 后周期/焊后污点、`preview_det` 实时 overlay；双模型包上 `cls.enabled=true` 的 MONITORING 回归。

---

## 结论与后续

1. **App 1.0.26 + `ENABLE_LENS_GUARD_STARTUP=true`**：LensGuard 可正常 `nativeCreate` / `Engine started`；det-only 能力画像正确。
2. **阻塞项**：bundled **ai-library 1.1.8** 的 `libai.so` 为 **5 月 13 日**构建，**不含** `nativeInferImageToJson`（及文档中的 preview 开关 JNI）。离线 AI Vision 时间轴/推理 MP4 **不可用**，直至更换含离线 JNI 的 `libai_<version>.zip` 并重导 bundled 库（必要时清数据或版本号递增触发 `BundledLibraryBootstrap`）。
3. **建议下一步**：
   - lensinspector：`build_android.sh` / CI 产出新 zip → 更新 Workers ai-library + lws-ui assets；
   - 设备复验：`nm -D libai.so | grep nativeInferImageToJson` → 冷启动无 `UnsatisfiedLinkError` → `offlineInferJsonAvailable=true` → §8 项 2–4 台架。

---

## 复现命令

```bash
adb -s 10.0.1.159:5555 install -r lws-ui/app/build/outputs/apk/release/app-release.apk
adb -s 10.0.1.159:5555 shell am start -n com.lasercyber.lws.ui/.activitys.SplashActivity
adb -s 10.0.1.159:5555 logcat -d | grep -iE 'LensGuardManager|NativeBridge|Capability profile'

# 符号（需 root / su）
adb -s 10.0.1.159:5555 shell su 0 cp \
  /data/user/0/com.lasercyber.lws.ui/files/bundled-libraries/ai-library/1.1.8/jniLibs/arm64-v8a/libai.so \
  /sdcard/_libai_check.so
adb pull /sdcard/_libai_check.so /tmp/_libai_device.so
nm -D /tmp/_libai_device.so | grep nativeInferImageToJson
```
