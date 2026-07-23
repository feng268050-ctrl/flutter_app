## Context

本项目是运行在 Android 工控屏上的激光焊接 HMI 应用，当前通过 EasyDarwin RTSP 客户端接收摄像头视频流用于后台录制，但不做任何视频帧级别的智能分析。YOLO 团队已完成 C++ 镜片检测引擎，交付固定库名 **`libai.so`**（`System.loadLibrary("ai")`），通过 RKNN 实现焊接镜片的聚焦检测和污染检测，引擎不主动采集画面，完全依赖 App 推送 I420 帧和激光状态。

现有 App 的视频管道关键约束：
- `EasyPlayerClientManger` 当前构造 `EasyPlayerClient` 时 `I420DataCallback` 为 `null`，走 Surface 直出路径（Path A），CPU 侧拿不到帧
- 当前使用虚拟 `SurfaceTexture(0)` 作为 Surface，不存在实时预览
- 录制走独立的 `pumpVideoSample` 通道，与解码路径无关
- 设备状态（含激光开关）已通过 Modbus 轮询写入 `MemoryCacheManager`，可通过 `CacheKey.DEVICE_STATUS_KEY` 监听
- 告警声音已有 `GlobalSoundManager.warnSound()` / `stopWarnSound()` 封装

目标平台：arm64-v8a Android 设备，配备 RKNN NPU。

## Goals / Non-Goals

**Goals:**
- 将 C++ 检测引擎集成进 App，引擎生命周期跟随 App 自动管理
- 改造视频帧解码路径，使 CPU 侧可获取 I420 帧并推送给引擎
- 将设备激光状态实时同步给引擎
- 正确处理引擎的三种回调（状态变化、检测结果、告警），执行告警声音、UI 通知等业务动作
- 保证现有录制功能不受影响
- 代码结构清晰，新增模块独立于现有业务代码

**Non-Goals:**
- 不实现实时预览画面叠加检测框（当前 App 无实时预览需求）
- 不修改 C++ 引擎本身（引擎作为黑盒 .so 集成）
- 不引入新的 UI 页面展示检测结果（第一阶段仅做告警声音和日志，后续可扩展）
- 不处理 EasyPlayerClient 的 Planar 格式遗漏 bug（大多数 ARM SoC 默认输出 SemiPlanar，风险极低）
- 不改造 `BackgroundLoopRecorder`（它有独立的 `EasyPlayerClient` 实例，保持不变）

## Decisions

### D1: 镜片引擎 Java 包路径

**决定**：
- **`NativeBridge.java`**、**`LensGuardManager.java`**、**`AssetDeployer.java`** 均位于 **`com.lasercyber.lws.ai`**，目录 `app/src/main/java/com/lasercyber/lws/ai/`；JNI 与 YOLO 端 `libai.so` 对齐。YOLO ZIP **仅交付** `jniLibs` + `assets` 时可不再包含 `java/`。

**理由**：JNI 与包名、类名绑定，由本仓库单一维护；管理类与 JNI 桥同包，减少跨包耦合，导入路径统一。

**替代方案**：曾将管理类或 JNI 桥放在 `com.lasercyber.lws.ui.lensinspector` 等非 `ai` 包并由 ZIP 覆盖——均已废弃，现统一为 `com.lasercyber.lws.ai`。

### D2: 引擎生命周期绑定到 LaserApplication

**决定**：在 `LaserApplication.initBaseHardware()` 中初始化 `LensGuardManager`，与串口初始化同级别。引擎随 App 进程存活。

**理由**：
- 引擎需要持续接收帧数据和激光状态，与 App 生命周期一致最简单
- 不使用独立 Service 是因为引擎本身不需要跨进程通信，也不需要独立于 App 存活
- `LaserApplication` 已有完善的硬件初始化流程（串口→MQTT），检测引擎作为新的硬件关联组件自然适合放在这里

**替代方案**：使用前台 Service——被否决，增加复杂度但无收益（引擎已在 App 进程内运行，不需要 Service 保活）。

### D3: 帧推送在 I420DataCallback 回调中同步执行

**决定**：在 `EasyPlayerClientManger` 构造 `EasyPlayerClient` 时传入 `I420DataCallback`，回调中立即拷贝 `ByteBuffer` 为 `byte[]`，然后调用 `NativeBridge.nativePushFrame()`。

**理由**：
- `nativePushFrame` 不做模型推理（引擎内部是异步的），仅做 I420→BGR 转换 + 缓冲写入，耗时 < 3ms
- `ByteBuffer` 生命周期极短，必须在回调内立即拷贝
- 同步调用简单可靠，无需维护额外的帧队列

**替代方案**：异步队列（offer 到 BlockingQueue，独立线程 poll 后 push）——被否决，因为 `nativePushFrame` 本身很快（< 3ms），异步队列引入延迟和复杂度但无性能收益。

### D4: 激光状态通过 MemoryCacheManager 监听推送

**决定**：`LensGuardManager` 实现 `MemoryCacheManager.OnCacheChangedListener`，监听 `CacheKey.DEVICE_STATUS_KEY`，状态变化时从缓存取出 `DeviceStatus` 对象并调用 `nativeSetLaserOn(handle, status.isLaserOn())`。

**理由**：
- `DeviceStatus.isLaserOn()` 已经存在，从 Modbus 寄存器 `machineStatusSeg1` Bit0 解析
- `MemoryCacheManager` 的 Listener 机制成熟，`EquipmentStatusBar` 等组件已在使用
- 无需新增任何 Modbus 轮询逻辑

### D5: 检测回调分三路处理

**决定**：
- `onAlert(alertLevel)`: `alertLevel > 0` 时调用 `GlobalSoundManager.warnSound()`，`alertLevel == 0` 时调用 `stopWarnSound()`
- `onStateChanged(state)`: 通过 EventBus 发布 `LensGuardStateEvent`，UI 组件按需订阅
- `onCheckResult(level, status, message)`: 通过 EventBus 发布 `LensCheckResultEvent`，可用于日志记录或 UI 展示

**理由**：
- 告警声音是硬性需求，与现有 `GlobalSoundManager` 无缝衔接
- EventBus 是项目已有的组件间通信方式，保持一致性
- 回调在 native 线程执行，EventBus 可配合 `@Subscribe(threadMode = ThreadMode.MAIN)` 自动切主线程

### D6: config.yaml 解压到固定路径

**决定**：首次启动时将 `assets/config.yaml` 解压到 `context.getFilesDir()/lens_guard/config.yaml`，后续启动检查文件是否存在，若存在则跳过。

**理由**：
- 引擎 `nativeCreate` 需要 `configPath` 和 `projectRoot` 两个文件系统路径
- Android assets 不能直接以文件路径访问
- `getFilesDir()` 是 App 私有目录，安全且不需要额外权限

## Risks / Trade-offs

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| RKNN 运行时库与目标设备 NPU 驱动不兼容 | 引擎 `nativeCreate` 失败，检测功能不可用 | `nativeCreate` 返回 0 时降级处理，App 其他功能不受影响；日志记录失败原因 |
| `EasyPlayerClient` 在 Planar YUV 格式下不触发 `onI420Data` | 帧无法推送给引擎 | 大多数 ARM SoC 默认 SemiPlanar，实际风险低；若遇到则需修补 `EasyPlayerClient.java` Planar 分支 |
| APK 体积增加 30-50MB（.so 文件） | 部署/OTA 时间变长 | 工控设备通过 USB 侧载安装，带宽不是瓶颈 |
| Native 线程回调中误操作 UI | ANR 或崩溃 | 所有回调通过 EventBus post 到主线程，或在 LensGuardManager 内用 Handler post |
| 引擎连续报告 Level 2 告警导致声音重叠 | 用户体验差 | 引擎已做去重（同级别不重复触发），App 侧 `warnSound()` 使用 SoundPool 循环播放，stop 一次即停 |
| `ByteBuffer` 生命周期管理不当导致 native crash | JVM crash | 严格在回调内完成 `buffer.get(data)` 拷贝，不持有 buffer 引用到回调外 |
