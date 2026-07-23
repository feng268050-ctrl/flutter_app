## 1. ZIP 包解压部署

- [x] 1.1 已被当前 bundled AI library 交付方式替代：项目使用 `app/src/main/assets/ai-library/libai_v1.0.0-beta.zip` 与运行时 bootstrap，不再要求手工获取 `lens_guard_engine_v1.0.0.zip`。
- [x] 1.2 已被当前 bundled AI library 交付方式替代：native triple 由 zip/bootstrap 管理，不再手工合并到 `app/src/main/jniLibs/arm64-v8a/`。
- [x] 1.3 已被当前 AssetDeployer/bootstrap 流程替代：配置随 assets/bundled library 部署并校验，不再按原 ZIP 结构手工合并。
- [x] 1.4 `NativeBridge.java` 由本仓库维护（`app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java`）；ZIP 可不包含 `java/`，升级时核对 JNI 与 `libai.so` 是否一致即可
- [x] 1.5 确认 `app/build.gradle.kts` 中 `abiFilters` 包含 `arm64-v8a`（当前已有，验证即可）
- [x] 1.6 当前 `NativeBridge` 由本仓库维护，`./gradlew :app:compileReleaseJavaWithJavac` 已在 2026-04-21 通过，App 侧 import 可编译。

## 2. EventBus 事件类

- [x] 2.1 创建 `app/.../bean/event/LensGuardStateEvent.java`：包含 `int state` 字段、构造函数、getter
- [x] 2.2 创建 `app/.../bean/event/LensCheckResultEvent.java`：包含 `int level`、`String status`、`String message` 字段、构造函数、getter

## 3. AssetDeployer 配置文件部署

- [x] 3.1 创建包目录 `app/src/main/java/com/lasercyber/lws/ai/`（与 `NativeBridge` 同包）
- [x] 3.2 创建 `AssetDeployer.java`（`com.lasercyber.lws.ai` 包内）：实现 `deploy(Context)` 方法
- [x] 3.3 实现逻辑：检查 `files/lens_guard/config.yaml` 是否存在，不存在则从 assets 复制
- [x] 3.4 返回结果对象包含 `configPath` 和 `projectRoot` 两个路径

## 4. LensGuardManager 引擎管理器

- [x] 4.1 创建 `LensGuardManager.java`（`com.lasercyber.lws.ai` 包内）：单例模式 + `getInstance()`
- [x] 4.2 实现 `start(Context)` 方法：调用 AssetDeployer → `NativeBridge.nativeCreate` → `NativeBridge.nativeSetListener` → `NativeBridge.nativeStart` → 注册缓存监听
- [x] 4.3 实现 `NativeBridge.NativeListener` 回调处理：`onAlert` 调用 `GlobalSoundManager`；`onStateChanged` 和 `onCheckResult` 通过 EventBus 发布事件
- [x] 4.4 实现 `MemoryCacheManager.OnCacheChangedListener`：从缓存取 `DeviceStatus`，调用 `NativeBridge.nativeSetLaserOn(handle, status.isLaserOn())`
- [x] 4.5 实现 `stop()` 方法：移除缓存监听 → `NativeBridge.nativeStop` → `NativeBridge.nativeDestroy` → handle 置 0
- [x] 4.6 实现 `isRunning()` 方法和 `getHandle()` 方法
- [x] 4.7 实现 `onI420Frame(ByteBuffer buffer)` 方法：拷贝 ByteBuffer 为 byte[] 后调用 `NativeBridge.nativePushFrame`

## 5. EasyPlayerClientManger 帧推送改造

- [x] 5.1 修改 `EasyPlayerClientManger.java`：构造 `EasyPlayerClient` 时传入 `I420DataCallback` lambda
- [x] 5.2 在回调 lambda 中：检查 `LensGuardManager.isRunning()`，若为 true 则调用 `LensGuardManager.getInstance().onI420Frame(buffer)`
- [x] 5.3 确认帧宽高从 `CameraConfig.VIDEO_RESOLUTION_WIDTH` / `VIDEO_RESOLUTION_HEIGHT` 获取

## 6. LaserApplication 集成

- [x] 6.1 在 `LaserApplication.initBaseHardware()` 中串口初始化之后添加 `LensGuardManager.getInstance().start(this)` 调用
- [x] 6.2 在 `LaserApplication.onTerminate()` 或合适的退出钩子中添加 `LensGuardManager.getInstance().stop()` 调用

## 7. 验证与测试

- [x] 7.1 `./gradlew :app:compileReleaseJavaWithJavac :app:compileReleaseAndroidTestJavaWithJavac` 已在 2026-04-21 通过。
- [x] 7.2 目标 RK3566 设备已验证 App 可启动；LensGuard auto-start 因 BSP/RKNN runtime 不匹配被配置开关保护，不再要求在当前 BSP 上加载并运行 bundled runtime。
- [x] 7.3 当前板端 RKNN runtime 与 BSP/驱动不匹配，handle/帧推送/激光状态同步不作为当前交付验收；待 BSP/runtime 匹配后应以新 change 重开功能验收。
- [x] 7.4 App 启动已验证正常，录制链路不在本归档处置范围内；相关视频上传/录制回归由已归档的视频 OpenSpec change 覆盖。
