## Why

HMI 设备开机后由系统直接拉起 App 并进入首页，但下位机 Modbus 通讯与工业摄像头连通性需要一段时间才能稳定。当前异步轮询（Modbus 状态任务、摄像头 1 Hz ping 与 C002 告警弹窗）会在自检完成前各自触发，操作员看不到统一的启动期健康结论，且可能弹出与开机自检重叠的告警。需要在进入首页后先执行一次**同步式**开机自检，逐项展示结果，完成后再恢复现有异步检测。

## What Changes

- 在 `MainActivity` 进入首页后（`initView` 或等价首页可见时机），触发**每进程一次**的开机自检流程。
- 自检期间展示不可取消的进度弹窗，按固定顺序逐项执行检测；每完成一项即在弹窗中**追加**检测项目名称与状态（检测中 / 正常 / 异常）。
- 自检检测项覆盖 Modbus 所支持的告警信息检测（与 Monitor → Alarm Information 左侧面板一致：下位机连通、泵/枪/送丝机通讯、温湿度与激光电流等状态类检测）以及摄像头 ICMP 连通检测。
- 自检执行期间**暂停**异步检测：Modbus 设备状态/数据轮询触发的 `DeviceDialogHandler` 告警弹窗、以及 `CameraCommunicationMonitor`（1 Hz ping + C002 告警监听）。
- 全部检测项完成后自动关闭弹窗，并**恢复**上述异步检测能力。
- 自检失败项仅记录在弹窗列表中，不替代现有告警弹窗语义（恢复异步检测后仍按既有规则告警）。

## Capabilities

### New Capabilities

- `boot-self-check`: 定义首页开机同步自检的触发时机、检测项清单、弹窗交互、异步检测暂停/恢复与每进程幂等规则。

### Modified Capabilities

- `camera-ping-health-check`: 周期性 ICMP ping 的启动时机延后至开机自检完成之后（在首页进入时仍不立即启动）。
- `camera-communication-alarm`: C002 摄像头通讯告警监听延后至开机自检完成之后，自检期间不得弹出 C002 告警。

## Impact

- `MainActivity` 首页生命周期与启动编排（与现有 WiFi 引导、固件引导、绑定检查等启动弹窗的先后顺序需协调）。
- 新增自检编排器、进度弹窗 UI 与字符串资源。
- `DeviceStatusTaskHandler` / `DeviceDialogHandler` 需支持自检期间的告警抑制闸门。
- `CameraCommunicationMonitor` 启动时机调整；`CameraUtils.checkCameraBlocking()` 复用于自检中的摄像头项。
- Modbus 同步读取（`ModbusManagerRtu` / `ModbusFiledBuilder`）在自检流水线中串行调用。
- 单元测试：自检顺序、异步抑制、完成后恢复、每进程幂等。
