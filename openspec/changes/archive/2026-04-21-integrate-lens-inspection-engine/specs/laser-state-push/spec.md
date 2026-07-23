## ADDED Requirements

### Requirement: 监听激光状态变化

`LensGuardManager` SHALL 实现 `MemoryCacheManager.OnCacheChangedListener` 接口，监听 `CacheKey.DEVICE_STATUS_KEY` 的变化事件。

#### Scenario: 注册监听
- **WHEN** `LensGuardManager.start()` 成功启动引擎后
- **THEN** SHALL 调用 `MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this)` 注册监听

#### Scenario: 注销监听
- **WHEN** `LensGuardManager.stop()` 被调用
- **THEN** SHALL 调用 `MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this)` 移除监听

### Requirement: 推送激光状态到引擎

当 `onCacheChanged(CacheKey.DEVICE_STATUS_KEY)` 触发时，系统 SHALL 从 `MemoryCacheManager` 获取 `DeviceStatus` 对象，调用 `NativeBridge.nativeSetLaserOn(handle, status.isLaserOn())`。

#### Scenario: 激光开启
- **WHEN** 设备激光开启且 `DeviceStatus.isLaserOn()` 返回 `true`
- **THEN** SHALL 调用 `nativeSetLaserOn(handle, true)`，引擎进入 MONITORING 模式

#### Scenario: 激光关闭
- **WHEN** 设备激光关闭且 `DeviceStatus.isLaserOn()` 返回 `false`
- **THEN** SHALL 调用 `nativeSetLaserOn(handle, false)`，引擎进入 IDLE 模式并触发焊后检测

#### Scenario: DeviceStatus 为 null
- **WHEN** `MemoryCacheManager` 中 `DEVICE_STATUS_KEY` 对应的值为 null
- **THEN** SHALL 跳过状态推送，不 SHALL 抛出 NullPointerException
