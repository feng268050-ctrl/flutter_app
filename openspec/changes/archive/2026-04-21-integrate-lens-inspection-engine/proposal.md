> Archived as superseded on 2026-04-21.
> This proposal was an early integration plan and has been replaced by later changes focused on
> runtime stabilization, package migration, and upload-path verification.

## Why

YOLO 团队已完成 C++ 镜片检测引擎（固定库名 **`libai.so`**），通过 RKNN 对焊接镜片进行实时聚焦检测和污染检测。当前 App 不包含任何推理模块，需要集成该引擎的 JNI 接口层、视频帧推送管道、激光状态推送、以及检测回调处理（告警声音、状态展示、检测结果记录），以实现 App 对镜片状态的实时监控和告警。

## What Changes

- **ZIP 包解压部署**：YOLO 团队以 ZIP 包（`lens_guard_engine_v1.0.0.zip` 等）形式提供 **`jniLibs`（含 `libai.so`、`libc++_shared.so`、`librknnrt.so`）** 与 `assets/config.yaml`，解压后合并到 `app/src/main/`。`NativeBridge.java`（包路径 **`com.lasercyber.lws.ai`**）**由本仓库维护**，与 YOLO JNI 对齐；ZIP 可不包含 `java/`。
- **新增 `LensGuardManager` 引擎管理器**：封装引擎的完整生命周期（创建→设置监听→启动→运行→停止→销毁），提供对外简单调用接口。包路径为 **`com.lasercyber.lws.ai`**（与 `NativeBridge`、`AssetDeployer` 同包）。
- **改造 `EasyPlayerClientManger`**：构造 `EasyPlayerClient` 时传入非空 `I420DataCallback`，启用 Path B 解码路径，使 CPU 侧可获取 I420 帧数据用于推理。
- **新增激光状态推送**：监听 `MemoryCacheManager` 中 `DEVICE_STATUS_KEY` 的变化，在激光状态切换时调用 `nativeSetLaserOn`。
- **新增检测回调处理**：处理引擎的 `onAlert`（触发 `GlobalSoundManager.warnSound()`）、`onStateChanged`（更新 UI 状态）、`onCheckResult`（记录检测结果、通知用户）回调，需将 native 线程回调 post 到主线程。
- **新增 `config.yaml` 资产运行时解压**：首次启动时将 `assets/config.yaml` 解压到 App 私有目录 `files/lens_guard/`。
- **集成到 App 生命周期**：在 `LaserApplication` 或独立 `Service` 中初始化引擎，确保随 App 启动自动运行，随 App 退出正确释放。

## Capabilities

### New Capabilities
- `native-bridge-jni`: JNI 接口层（本仓库 `com.lasercyber.lws.ai.NativeBridge`），App 侧负责 ZIP 中 `.so`/配置部署及与 JNI 声明一致性验证
- `lens-guard-lifecycle`: 引擎生命周期管理器，封装 create→listener→start→pushFrame→stop→destroy 全流程
- `frame-push-pipeline`: I420 视频帧推送管道，改造 EasyPlayerClient 解码路径，将解码帧喂入引擎
- `laser-state-push`: 激光状态推送模块，监听设备状态缓存变化并同步给引擎
- `detection-callback-handler`: 检测回调处理模块，处理告警、状态变化、检测结果回调并执行相应业务动作
- `config-asset-deploy`: 配置文件部署模块，管理 config.yaml 从 assets 解压到运行时路径

### Modified Capabilities

（无现有 spec 需要修改）

## Impact

- **代码改动**：
  - `app/.../common/camera/EasyPlayerClientManger.java`：构造函数参数变更（添加 I420DataCallback）
  - `app/.../LaserApplication.java`：新增引擎初始化入口
  - App 侧新增 3-4 个 Java 类：`LensGuardManager`、`AssetDeployer` 与 `NativeBridge` 同包 `com.lasercyber.lws.ai`；另有 EventBus 事件类等位于 `ui.bean.event`
  - `NativeBridge.java` 由本仓库维护（`app/src/main/java/com/lasercyber/lws/ai/`）
- **依赖/部署**：
  - YOLO 团队提供 ZIP 包（`lens_guard_engine_v1.0.0.zip` 等），解压合并到 `app/src/main/`
  - 包含 3 个 `.so` 文件 + `config.yaml`（~30-50MB）；`NativeBridge.java` 可不随 ZIP 分发
  - APK 体积增加约 30-50MB
- **线程模型**：引擎回调在 native 工作线程执行，UI 更新需 post 到主线程
- **现有功能**：录制功能（`pumpVideoSample`）不受影响；预览功能当前使用虚拟 Surface 也不受影响
- **硬件要求**：目标设备需为 arm64-v8a 架构，且需支持 RKNN 推理运行时
