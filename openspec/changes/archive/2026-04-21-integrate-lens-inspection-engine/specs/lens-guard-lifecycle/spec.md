## ADDED Requirements

### Requirement: LensGuardManager 单例管理器

系统 SHALL 提供 `LensGuardManager` 类（包路径 `com.lasercyber.lws.ai`），作为引擎的唯一管理入口。该类 SHALL 使用单例模式，提供 `getInstance()` 静态方法。该类 SHALL 与同包 `NativeBridge` 协作调用 JNI（本仓库维护，与 `libai.so` 对齐）。

#### Scenario: 获取单例
- **WHEN** 任何组件调用 `LensGuardManager.getInstance()`
- **THEN** SHALL 返回同一个实例

### Requirement: 引擎启动流程

`LensGuardManager.start(Context context)` SHALL 按以下顺序执行引擎初始化：
1. 调用 `AssetDeployer` 确保 `config.yaml` 已解压到运行时路径
2. 调用 `NativeBridge.nativeCreate(configPath, projectRoot)` 创建引擎
3. 调用 `NativeBridge.nativeSetListener(handle, listener)` 设置回调监听
4. 调用 `NativeBridge.nativeStart(handle)` 启动引擎主循环
5. 注册 `MemoryCacheManager` 的 `DEVICE_STATUS_KEY` 监听（用于激光状态推送）

#### Scenario: 正常启动
- **WHEN** 配置文件有效且 .so 库可加载
- **THEN** 引擎 SHALL 成功创建并启动，`isRunning()` 返回 `true`

#### Scenario: 创建失败降级
- **WHEN** `nativeCreate` 返回 0
- **THEN** `LensGuardManager` SHALL 记录错误日志，`isRunning()` 返回 `false`，不 SHALL 影响 App 其他功能

### Requirement: 引擎停止流程

`LensGuardManager.stop()` SHALL 按以下顺序执行：
1. 移除 `MemoryCacheManager` 的监听器
2. 调用 `NativeBridge.nativeStop(handle)`（阻塞等待工作线程结束）
3. 调用 `NativeBridge.nativeDestroy(handle)`
4. 将 handle 置为 0

#### Scenario: 正常停止
- **WHEN** 引擎正在运行且调用 `stop()`
- **THEN** 引擎 SHALL 释放所有资源，`isRunning()` 返回 `false`

#### Scenario: 重复停止
- **WHEN** 引擎已停止时再次调用 `stop()`
- **THEN** SHALL 安全返回，不 SHALL 抛出异常

### Requirement: 集成到 LaserApplication

`LaserApplication.initBaseHardware()` SHALL 在串口初始化之后调用 `LensGuardManager.getInstance().start(this)` 启动引擎。App 退出或进程销毁时 SHALL 调用 `stop()` 释放资源。

#### Scenario: App 启动时引擎初始化
- **WHEN** `LaserApplication.onCreate()` 执行到 `initBaseHardware()`
- **THEN** `LensGuardManager` SHALL 被初始化并启动

#### Scenario: App 退出时引擎释放
- **WHEN** App 进程即将销毁
- **THEN** `LensGuardManager.stop()` SHALL 被调用
