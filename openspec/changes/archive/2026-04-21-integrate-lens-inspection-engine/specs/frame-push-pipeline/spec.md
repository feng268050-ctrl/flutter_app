## ADDED Requirements

### Requirement: EasyPlayerClientManger 启用 I420DataCallback

`EasyPlayerClientManger` 构造 `EasyPlayerClient` 时 SHALL 传入非空 `I420DataCallback`，将解码路径从 Path A（Surface 直出）切换到 Path B（CPU 可获取 I420 帧）。

#### Scenario: 构造时传入回调
- **WHEN** `EasyPlayerClientManger` 创建新的 `EasyPlayerClient` 实例
- **THEN** 构造函数的 `I420DataCallback` 参数 SHALL 为非空 lambda

#### Scenario: 回调中不阻塞解码线程
- **WHEN** `I420DataCallback.onI420Data` 被触发
- **THEN** 回调内的处理时间 SHALL 控制在 5ms 以内，不 SHALL 执行模型推理等耗时操作

### Requirement: 帧数据拷贝与推送

在 `I420DataCallback.onI420Data(ByteBuffer buffer)` 回调中，系统 SHALL：
1. 立即将 `ByteBuffer` 内容拷贝到 `byte[]`（因 buffer 生命周期极短）
2. 调用 `NativeBridge.nativePushFrame(handle, data, width, height)` 将帧推送给引擎

#### Scenario: ByteBuffer 及时拷贝
- **WHEN** `onI420Data` 被调用
- **THEN** SHALL 在方法返回前完成 `buffer.get(data)` 拷贝，不 SHALL 持有 `buffer` 引用到回调外

#### Scenario: 帧尺寸正确
- **WHEN** 推送帧时
- **THEN** `data.length` SHALL 等于 `width * height * 3 / 2`，宽高 SHALL 取自 `CameraConfig.VIDEO_RESOLUTION_WIDTH` (1280) 和 `VIDEO_RESOLUTION_HEIGHT` (720)

### Requirement: 录制功能不受影响

改造后的 `EasyPlayerClientManger` SHALL 保持录制功能正常，`pumpVideoSample` 写入原始 NAL 数据的通道 SHALL 不受解码路径变更影响。

#### Scenario: 录制与帧推送并行
- **WHEN** 引擎正在接收帧数据
- **THEN** MP4 录制 SHALL 正常工作，录制文件 SHALL 包含完整视频数据

### Requirement: 引擎未启动时的降级

当 `LensGuardManager.isRunning()` 为 `false` 时，`I420DataCallback` 回调 SHALL 跳过帧推送（不调用 `nativePushFrame`），避免向无效 handle 推送。

#### Scenario: 引擎创建失败后帧推送
- **WHEN** 引擎创建失败（handle = 0）且 `onI420Data` 被调用
- **THEN** SHALL 跳过 `nativePushFrame` 调用，不 SHALL 抛出异常
