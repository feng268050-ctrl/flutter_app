## Why

AI Vision 当前的 RTSP + 解码链路在弱网、缓冲区堆积或分辨率/码流切换时容易出现**端到端延迟偏高**和**花屏/马赛克/短暂绿块**等解码异常。产线场景需要画面更跟手、异常更易恢复。`实时视频流.md` 已给出工业侧方向：同网段以太网、TCP 拉流稳定、低缓冲、硬解与丢帧保实时；本变更把这些方向落到 AI Vision 的可验收行为与实施任务上。**实施顺序上必须先完成可复现的根因归类与证据采集，再决定是否改缓冲、解码或网络，避免「未定位先调参」掩盖真实故障。**

## What Changes

- **根因优先**：在改动播放器参数或架构前，完成可复现矩阵（网络 / 解码 / UI 线程 / AI 抽帧）的分流诊断，并留存日志、VLC 对照、必要的抓包或短录屏证据；再选择对应修复分支。
- 明确并收敛 AI Vision **首帧与稳态延迟**目标，以及**抖动/花屏**的可接受阈值与恢复策略（超时重连、缓冲区策略）。
- 在网络层保持与文档一致：**进入播放前确保摄像头网段可达**；可选记录/诊断实际 RTSP URL 与 `eth0` 配置结果。
- 在播放层评估并落地**低延迟解码/渲染**措施：维持或优化 RTSP **TCP** transport；在播放器/底层可配置范围内减少缓冲；必要时评估 UDP/备选 URL（产品决策）。
- 在 CPU/主线程侧减少与视频竞争：`LensGuard` 等 I420 回调路径控制频率或异步，避免加重解码线程饥饿（与花屏相关时重点验证）。
- 文档化**新设备**验收清单：ping、VLC 对照、App 日志关键字、常见 DHCP/路径/鉴权不一致排查。

## Capabilities

### New Capabilities

- `ai-vision-live-video`: AI Vision 实时视频（RTSP）的**延迟、稳定性、花屏恢复、网络前置条件**等产品级要求与验收标准。

### Modified Capabilities

- （无）当前 `openspec/specs/` 下无专用于 AI Vision RTSP 的既有能力包；本变更以新增能力为主，不修改其他 spec 的 REQUIREMENTS。

## Impact

- **代码**：`AiVisionFragment`、`EasyPlayerClient` / `Client` 配置、`CameraConfig`、可能的 `SystemSettingUtils` / 播放器 JNI 选项；以及与 `LensGuardManager` 的帧推送协作。
- **依赖**：继续使用现有 EasyDarwin/EasyRTSPClient 栈；若引入 FFmpeg/GStreamer 或 MPP 直解则为更大范围迭代，本 proposal 仍以**当前栈内优化**为第一里程碑。
- **系统**：RK3566 以太网、`ENABLE_LENS_GUARD_STARTUP` 与 native 兼容性仍按既有构建开关管理。
