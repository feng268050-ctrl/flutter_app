# COREDEX Lens Guard C++ Engine

本仓库构建 Android 侧使用的原生检测引擎 `**libai.so**`（文件名固定；`LIB_VERSION` 仅用于构建元数据与 zip 包名 `libai_<version>.zip`）。引擎负责：

- 自动聚焦状态检测
- 镜片污染检测（RKNN + scheduler）
- **lens_det 单帧分析**（OpenCV，`nativeDetectLensDet*`，与 RKNN 同在 `libai.so`）
- 通过 JNI 暴露给 Android App 调用

当前 Android Java/JNI canonical package 为 `com.lasercyber.lws.ai`。

## Repository Scope

`README.md` 面向仓库维护者，说明源码结构、构建方式和交付物。
App 团队接入说明见 [`docs/LENS_GUARD_APP_INTEGRATION.md`](docs/LENS_GUARD_APP_INTEGRATION.md)（**更新 2026-05-27**，含原变更清单与验收）；简版见 [`docs/APP_ALIGNMENT_BRIEF.md`](docs/APP_ALIGNMENT_BRIEF.md)。白中红 JSON/JNI 契约见 [`docs/WHITE_IN_RED_NATIVE_API.md`](docs/WHITE_IN_RED_NATIVE_API.md)（与 `opencv_pet` 同步维护）。零点检测（`find_redcode` C++ 移植）见 [`docs/ZERO_POINT_NATIVE_API.md`](docs/ZERO_POINT_NATIVE_API.md)。

## Architecture

引擎本身不主动采集画面。机器端 App 负责解码视频并调用 `NativeBridge.nativePushFrame()` 推送 I420 帧，同时通过 `nativeSetLaserOn()` 推送激光状态。

```
App (Java/Kotlin)
  ├── com.lasercyber.lws.ai.NativeBridge
  ├── nativePushFrame(I420)
  └── nativeSetLaserOn(boolean)
            |
            v
libai.so
  ├── JNI bridge (push-frame, infer, white-in-red)
  ├── scheduler / stain detection (det-only)
  ├── opencv_stain_detect_core (OpenCV single-frame)
  ├── zero_point_core (exposure window + brightest zero, find_redcode port)
  └── embedded RKNN models
            |
            v
librknnrt.so
```

## Repository Layout

```
lens_guard_cpp/
├── CMakeLists.txt
├── build_android.bat
├── build_android.sh
├── config.yaml
├── assets/
│   └── models/
│       ├── v8_cls_i8.rknn
│       └── v8_rknn_stain_det_i8.rknn
├── java/com/lasercyber/lws/ai/
│   └── NativeBridge.java
├── src/
│   ├── jni_bridge.cpp
│   ├── main.cpp
│   ├── central_scheduler.h
│   ├── config.h / config.cpp
│   ├── model_manager.h / model_manager.cpp
│   ├── rknn_runner.h / rknn_runner.cpp
│   └── rknn_stain_detect_pp.h / rknn_stain_detect_pp.cpp
└── docs/
    └── java-integration.md
```

## Dependencies


| Dependency         | Version  | Purpose                          |
| ------------------ | -------- | -------------------------------- |
| Android NDK        | r18b     | Android toolchain                |
| RKNPU2 Runtime     | >= 1.6.0 | NPU inference via `librknnrt.so` |
| OpenCV Android SDK | 4.5.5    | image conversion and processing (`make opencv`) |
| yaml-cpp           | 0.8.0    | runtime config parsing           |


相关下载地址：

- [OpenCV Android SDK](https://opencv.org/releases/page/2/) — vendored by `make opencv` into `native/toolchains/opencv/`
- [RKNN-Toolkit2](https://github.com/airockchip/rknn-toolkit2)
- [Android NDK r18b](https://github.com/android/ndk/wiki/Unsupported-Downloads#ndk-17c-downloads)

## Build

### Windows

```bat
set LIB_VERSION=v1.0.0
set ANDROID_NDK_PATH=D:\Android\android-ndk-r18b
set RKNN_RT_PATH=D:\path\to\rknpu2\runtime\Android\librknn_api\arm64-v8a
set OPENCV_PATH=D:\path\to\OpenCV-android-sdk\sdk\native\jni

build_android.bat
```

### macOS (Apple Silicon)

NDK **r18b** ships **darwin-x86_64** host tools only. Install the AI-isolated toolchain once, then build:

```bash
softwareupdate --install-rosetta --agree-to-license   # once, if needed
make ndk-r18b   # once: native/toolchains/ndk-r18b/ndk (not Gradle's NDK)
make opencv     # once
make ai         # auto re-runs under Rosetta on arm64 Mac → Android arm64-v8a (RK3566)
```

`make ndk-r18b` downloads Google's **android-ndk-r18b-darwin-x86_64.zip** into `native/toolchains/ndk-r18b/` (gitignored). Other native targets (Gradle, MediaMTX, etc.) may use different NDK versions elsewhere. Set `AI_SKIP_ROSETTA=1` only if you already run from an x86_64 shell.

### Linux / WSL

```bash
make ndk-r18b   # once: linux-x86_64 host prebuilts
make opencv     # once
make ai

# Or manual env (lensinspector-only):
export LIB_VERSION=v1.0.0
export ANDROID_NDK_PATH=~/android-ndk-r18b
export RKNN_RT_PATH=~/rknpu2/runtime/Android/librknn_api/arm64-v8a
export OPENCV_PATH=~/OpenCV-android-sdk/sdk/native/jni

bash build_android.sh
```

**CMake 选项**：Release 默认关闭 stain 路径的 `YOLO_PP_DIAG` 每帧日志。台架需要 `class_sigmoid` 分位数与 layout 双读时：

```bash
cmake ... -DLENS_YOLO_PP_DIAG=ON
```

或通过 `adb shell setprop debug.lws.det_postprocess.debug 1`（`jni_bridge` 在 `nativeCreate` 时映射到 `DET_POSTPROCESS_DEBUG_*`）。`LENS_STAIN_DIAG_INTERVAL_FRAMES`（默认 300）仅在 `LENS_YOLO_PP_DIAG=ON` 编译时生效。

### Output

构建产物位于 `build_android/libai.so`（OpenCV **静态链入**）。`make ai` 会将 runtime `.so` 复制到 **`app/src/main/jniLibs/arm64-v8a/`**，随 **`make build`** 打进 APK，不再生成中间 zip。

```text
app/src/main/jniLibs/arm64-v8a/
  libai.so
  libc++_shared.so
  librknnrt.so
app/src/main/assets/config.yaml
```

App 安装后从 APK 解压的 `nativeLibraryDir` 加载上述库。

## RKNN Memory Demo

仓库现在额外提供一个参考 `rknn_create_mem_demo.cpp` 流程的独立可执行目标：`rknn_mem_demo`。它使用同一套 `RKNNRunner` 核心，但走 `rknn_create_mem` / `rknn_set_io_mem` 的内存绑定推理路径，并输出：

- RKNN SDK / driver 版本
- 模型输入输出 tensor 属性
- 可选多次循环推理耗时与 FPS
- 每个输出 tensor 的 Top-N `class id`

示例调用：

```bash
./rknn_mem_demo <model_path.rknn> <image_path> [loop_count]
```

说明：

- 当前仅输出数值 `class id`，不做 label 映射。
- Android 打包流程保持不变；`rknn_mem_demo` 主要用于桌面/板端验证和与 Rockchip 参考 demo 对齐。
- 若只想构建原有 `libai.so`，可通过 `-DBUILD_RKNN_MEM_DEMO=OFF` 关闭该目标。

## Packaging

CI 在 tag 构建时会收集：

- `libai.so`
- `librknnrt.so`
- `libc++_shared.so`
- `config.yaml`

CI 会生成**同一构建**下的两个 zip（内容相同，仅文件名不同，便于渠道区分）：

```text
libai_<version>.zip
libai_<version>-beta.zip
```

ZIP 仅包含 App 运行时所需文件：`assets/config.yaml` 与 `jniLibs/arm64-v8a/*.so`。`NativeBridge.java` 保留在仓库源码树中，但不打包进 ZIP，而是单独交付给 App 团队并放到 `app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java`。

CI 上传阶段会先校验 `UPLOAD_AI_LIBRARY_BASE` 与规范生产基址 `https://api-prod.lasercyber.workers.dev/upload/ai-library` 一致，再分别 `curl` PUT `**libai_<version>.zip**` 与 `**libai_<version>-beta.zip**`（`API_TOKEN`）。tag 流水线还会创建 **GitLab Release**（`create_gitlab_release` 作业），说明见下文。不再单独 PUT `.so`。

## Local Release

本地 zip 默认输出到 `**ReleaseOutputDir`**（默认 `**E:\workspace\laser\lens_guard_cpp\release`**）下**两个**文件：`**libai_<version>.zip`** 与 `**libai_<version>-beta.zip`**（`<version>` 为 `vX.Y.Z`，示例 `**libai_v1.0.0.zip`** / `**libai_v1.0.0-beta.zip**`）。可用 `**-ReleaseOutputDir**` 覆盖目录。流程顺序为：先构建 `**libai.so**`（脚本内调用 `build_android.bat`），再打包 zip；脚本结束时会**打印**两个 zip 的完整路径。若**只需要生成本地 zip、不上传远端**，请使用 `**release_local.ps1 -SkipUpload`**。

Windows 本地发布入口为：

```powershell
powershell -ExecutionPolicy Bypass -File .\release_local.ps1
```

常用参数：

- `-Version v1.0.1`：显式指定发布版本
- `-SkipTagCleanup`：跳过 tag 清理（默认会删**远端**与**本地**所有 `v*` 标签）
- `-SkipUpload`：跳过 ZIP 上传
- `-ReleaseOutputDir <path>`：zip 输出目录（默认 `E:\workspace\laser\lens_guard_cpp\release`）
- `-SkipClean`：跳过发布前本地清理（默认只删仓库内 `**.release_tmp`**；不会删除 `**ReleaseOutputDir`**（默认 `E:\workspace\laser\lens_guard_cpp\release`）下任何文件，旧 zip 请自行管理）
- `-DryRun`：不修改任何状态——不删远端/本地 tag、不删 `.release_tmp`、不构建、不上传；会打印计划及**将要写入的两个 zip 完整路径**（若要看真实删除与上传，去掉 `-DryRun`）

发布脚本会串联以下步骤：

1. 校验版本号（格式 `vX.Y.Z`，默认按当前最新 tag 的 patch + 1 推导）
2. 删除远端与本地 Git 标签（`git push :refs/tags/...` 与 `git tag -d`，匹配 `v`*）
3. **（默认）清理本地 staging**：仅删除仓库内 `**.release_tmp`** 暂存目录；**不删除** zip 输出目录（默认 `E:\workspace\laser\lens_guard_cpp\release`）内任何文件；使用 `-SkipBuild` 时不执行此项（保留现有构建产物）
4. 调用 `build_android.bat` 构建 `libai.so`
5. 打包 `libai_<version>.zip` 与 `libai_<version>-beta.zip`
6. 通过 `API_TOKEN` 将上述两个文件分别 PUT 到 `https://api-prod.lasercyber.workers.dev/upload/ai-library/`

成功标准：**本地**存在本次生成的两个 zip（默认在上述 release 目录），终端会打印完整路径；若未跳过上传，则两次 PUT 均成功。`*.zip` 由 `.gitignore` 忽略，不会提交到 Git；「远端」指分发 API 上的对象，而非仓库内文件。

**GitLab（tag 流水线）**：`create_gitlab_release` 会为当前 tag 创建 **Release** 页面（描述中指向 **build_libai** 制品与 api-prod 上传）。若作业失败，请在项目 **Settings → CI/CD → Token Access** 中确认 **Job token** 允许访问 Releases（不同 GitLab 版本菜单略有差异）；亦可使用具备 `api` 权限的 **Project Access Token** 通过自定义脚本创建 Release（本仓库默认依赖内置 `release:` 作业）。

**方法一（仅上传已有 zip）：** 先在当前终端设置 `API_TOKEN`（与 GitLab CI/CD 变量一致，且需服务端已配置允许的 token），再对**两个**文件分别 PUT（将 `v1.0.0` 换成你的版本）：

```powershell
curl.exe --http1.1 -X PUT `
  -H "Authorization: Bearer $env:API_TOKEN" `
  -H "Content-Type: application/octet-stream" `
  --data-binary "@E:\workspace\laser\lens_guard_cpp\release\libai_v1.0.0.zip" `
  "https://api-prod.lasercyber.workers.dev/upload/ai-library/libai_v1.0.0.zip"
curl.exe --http1.1 -X PUT `
  -H "Authorization: Bearer $env:API_TOKEN" `
  -H "Content-Type: application/octet-stream" `
  --data-binary "@E:\workspace\laser\lens_guard_cpp\release\libai_v1.0.0-beta.zip" `
  "https://api-prod.lasercyber.workers.dev/upload/ai-library/libai_v1.0.0-beta.zip"
```

成功时 HTTP 状态码为 **200**；若返回 **503** 且提示 `STATIC_API_TOKENS`，需在 `api-prod` Worker 侧配置 `STATIC_API_TOKENS` 后再试。

### CI 上传失败（`SSL unexpected eof` / `URLError: EOF`）

`upload_libai` 使用 `scripts/upload_ai_library_zip.sh`（`curl --http1.1`，默认 **12** 次重试，**不限速**）。可选 CI 变量：`UPLOAD_RETRY_ATTEMPTS`、`UPLOAD_RETRY_SLEEP`、`UPLOAD_LIMIT_RATE`（例如 `1M`）。beta tag 默认只上传 `libai_<tag>.zip`；`BETA_UPLOAD_COMPAT_FORMAL=1` 会多传别名，失败时可先设为 `0`。

**本机补传**（`build_libai` 已成功时，从 Pipeline 下载 `libai_*.zip` 或用 `release/` 下本地包）：

```bash
export API_TOKEN='...'
export UPLOAD_AI_LIBRARY_BASE='https://api-prod.lasercyber.workers.dev/upload/ai-library'
bash scripts/upload_ai_library_zip.sh release/libai_v1.2.0-beta.zip
```

Runner 若长期无法访问 `api-prod.lasercyber.workers.dev`（如解析到 `198.18.x.x` 超时），需运维修复 Runner 出网/代理；本机 curl 成功而 CI 失败时，用上述补传即可。

### 本地构建失败时

先核对本机 `**ANDROID_NDK_PATH`**、`**RKNN_RT_PATH`**、`**OPENCV_PATH**` 是否与上文 [Build](#build) 一致。未设置环境变量时，`release_local.ps1` 会回退到脚本内的 `**$DefaultNdkPath**` 与 `**$DefaultRknnPath**`；若解析 `librknnrt.so` 或 `libc++_shared.so` 失败，请按终端报错调整路径或显式设置上述变量。

## Native Bridge

Java bridge class:

```java
package com.lasercyber.lws.ai;
```

核心生命周期：

1. `nativeCreate(configPath, projectRoot)`
2. `nativeSetListener(handle, listener)`
3. `nativeStart(handle)`
4. App 持续调用 `nativePushFrame(...)`
5. App 在激光状态变化时调用 `nativeSetLaserOn(...)`
6. `nativeStop(handle)`
7. `nativeDestroy(handle)`

查询接口：

- `nativeGetState(handle)`
- `nativeGetStainLevel(handle)`
- `nativeIsLensDirty(handle)`
- `nativeGetLastClsResult(handle)`：返回单行 JSON 分类快照；`score` / `topk[].score` 为分类后处理后的概率，`classId` 从 0 开始，`className` 来自 native 固定表（0=`其他`, 1=`金属`）。无有效分类或 handle 无效时返回 `valid:false` 的合法 JSON。

AI Vision / 离线单图（App 对接）：

- `nativeSetAiVisionPreviewClassificationEnabled` / `nativeSetAiVisionPreviewDetectionEnabled`：激光 OFF 时预览 cls/det（见 [`docs/LENS_GUARD_APP_INTEGRATION.md`](docs/LENS_GUARD_APP_INTEGRATION.md) §9）。
- **JNI API 索引**：[`docs/NATIVE_UNIFIED_INFER_API.md`](docs/NATIVE_UNIFIED_INFER_API.md)（`NativeBridge` 全部方法；单次推理推荐 `nativeInfer*` → `StainInferOutcome`）。
- **兼容**：`nativeInferImageToJson` / `nativeInferRgbToJson` / `nativeInferI420ToJson`（字符串 JSON，schema 相同）。
- `nativeInferImageAndSave`：单图诊断写标注图（§9.6；见 [`docs/native-infer-image-and-save.md`](docs/native-infer-image-and-save.md)）。
- App 集成总览：**[`docs/LENS_GUARD_APP_INTEGRATION.md`](docs/LENS_GUARD_APP_INTEGRATION.md)**；App 简版：**[`docs/APP_ALIGNMENT_BRIEF.md`](docs/APP_ALIGNMENT_BRIEF.md)**。

## Configuration

`config.yaml` 为运行时配置，包含：

- **模型槽位**（`models.cls.enabled` / `models.det.enabled`）：默认 **det-only**（`cls: false`, `det: true`）。关闭 cls 时不加载分类 RKNN、不跑聚焦状态机；JNI `nativeGetLastClsResult` 仍返回 `valid:false` 的合法 JSON。
- 光学中心标定
- 自动聚焦阈值（仅 `models.cls.enabled: true` 时生效）
- 镜片污染检测阈值（**BREAKING**：mask 圆内/外分级；默认 `mask_radius_px: 280` @ `mask_ref_width: 1920`，见 `docs/LENS_GUARD_APP_INTEGRATION.md` §5）
- 调度周期
- 调试图片目录与上限

RKNN 模型在构建时嵌入 `libai.so`，无需单独分发模型文件。

- **`assets/models/`**：**DET 必选**（`det_raw_head.rknn`，由 `det_raw_head.onnx` 转 RK3566 i8）；**CLS 可选**（无 cls 文件时可编 det-only so，体积更小）。
- **检测后处理约定**：见 [`docs/训练推理后处理对齐说明.md`](docs/训练推理后处理对齐说明.md)（当前为 P2/P3/P4 raw head：`raw_p2`/`raw_p3`/`raw_p4` → DFL + NMS；勿按 `[1,5,33600]` decoded 或 8400 anchor 处理）。
- 运行时恢复分类：提供 CLS 嵌入 **且** `models.cls.enabled: true`，并重启 native 会话（`nativeDestroy` / `nativeCreate`）。
- 仅 DET 嵌入时若 `models.cls.enabled: true`，native 会打日志并自动按 cls 关闭处理。

### det-only 模式（BREAKING）

当 `models.cls.enabled: false` 时：

- 激光 **ON** 时**不会**进入 `MONITORING(1)`，**不会**调用 `onStateChanged(1)` 仅因自动聚焦。
- 污点检测（周期 / 焊后 / preview_det / 离线 `nativeInfer*`）与 LOCKED 安全门控**不变**。

## Notes

- `projectRoot` 是设备上的可写工作目录，供 `debug_data/` 等运行时文件使用。
- 当前实现目标 ABI 为 `arm64-v8a`。
- `docs/java-integration.md` 保留为历史说明入口，若内容与本 README 或 `APP_INTEGRATION_GUIDE.md` 冲突，以后两者为准。

# git 提交改动
1.
git add -u && git add CLS_READONLY_JNI_YOLO_DELIVERABLE.md docs/CLS_READONLY_JNI_YOLO_DELIVERABLE.md
或
git add .

2.
git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>" -m "$(cat <<'EOF'
fix(ci): make upload_libai curl failures visible under set -e

- Wrap PUT curls with set +e; report curl exit + HTTP body on transport errors.
- Add connect/max timeouts and curl -sS for clearer TLS/network diagnostics.

feat(jni): readonly CLS + YOLO scheduling hooks

- Extend NativeBridge / jni_bridge and main/scheduler for deliverable flow.
- Update config defaults; add CLS_READONLY_JNI_YOLO deliverable doc and docs pointer.

EOF
)"

3.
git push origin dev

# git 命令上传 CI 编译 so 和打包一个 beta 版本的 tags
git tag -a v1.2.0-beta -m "Beta v1.2.0-beta — CI build + libai_v1.2.0-beta.zip"
git push origin v1.2.0-beta
