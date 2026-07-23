## ADDED Requirements

### Requirement: 告警声音处理

当引擎回调 `onAlert(int alertLevel)` 时，系统 SHALL 根据 `alertLevel` 执行告警声音控制。

#### Scenario: 告警触发
- **WHEN** `alertLevel > 0`（1=警告，2=严重）
- **THEN** SHALL 调用 `GlobalSoundManager.warnSound()` 播放告警声音

#### Scenario: 告警解除
- **WHEN** `alertLevel == 0`
- **THEN** SHALL 调用 `GlobalSoundManager.stopWarnSound()` 停止告警声音

#### Scenario: 回调线程安全
- **WHEN** `onAlert` 在 native 工作线程上被调用
- **THEN** 声音操作 SHALL 在正确的线程上执行（`GlobalSoundManager` 的方法本身是线程安全的）

### Requirement: 状态变化事件分发

当引擎回调 `onStateChanged(int state)` 时，系统 SHALL 通过 EventBus 发布事件。

#### Scenario: 状态变化通知
- **WHEN** 引擎状态发生变化（IDLE=0, MONITORING=1, LOCKED=2）
- **THEN** SHALL 创建 `LensGuardStateEvent` 对象并通过 `EventBus.getDefault().post()` 发布

#### Scenario: UI 组件订阅
- **WHEN** UI 组件通过 `@Subscribe(threadMode = ThreadMode.MAIN)` 订阅 `LensGuardStateEvent`
- **THEN** SHALL 在主线程收到状态变化通知

### Requirement: 检测结果事件分发

当引擎回调 `onCheckResult(int level, String status, String message)` 时，系统 SHALL 通过 EventBus 发布事件。

#### Scenario: 检测结果通知
- **WHEN** 引擎完成一次污点检测
- **THEN** SHALL 创建 `LensCheckResultEvent` 对象（包含 level、status、message）并通过 EventBus 发布

#### Scenario: 重度污染告警联动
- **WHEN** `level == 2`（重度污染，引擎进入 LOCKED）
- **THEN** `LensCheckResultEvent` SHALL 携带 `STAIN_HEAVY` 状态，UI 层可据此展示紧急提示

### Requirement: EventBus 事件类

系统 SHALL 新增以下 EventBus 事件类（包路径 `com.lasercyber.lws.ui.bean.event`）：

1. `LensGuardStateEvent`：包含 `int state` 字段
2. `LensCheckResultEvent`：包含 `int level`、`String status`、`String message` 字段

#### Scenario: 事件类数据完整
- **WHEN** 事件对象被创建
- **THEN** SHALL 通过构造函数传入所有必要字段，字段 SHALL 通过 getter 方法访问
