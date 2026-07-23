# LWS-UI 项目架构（摘要）

> 原文：[`../PROJECT_ARCHITECTURE.md`](../PROJECT_ARCHITECTURE.md)  
> 文档版本口径：1.0.16 · compileSdk 34 · arm64-v8a

## 一句话

工业激光焊接/切割/清洗设备的 **Android HMI**，运行在工控屏上，通过 **Modbus RTU 串口** 控设备、**WebSocket** 同步工艺、**Room** 本地持久化，并支持视频录制与云端上传。

## 模块结构

| 模块 | 职责 |
|------|------|
| `:app` | 全部业务 UI、网络、数据库 |
| `:vendor:easydarwin` | EasyDarwin 视频播放/录制/编解码（`vendor/easydarwin/`） |
| `:vendor:modbus4android` | Modbus + Android 串口封装 |
| `:vendor:modbus4j` | Serotonin Modbus4J 协议栈 |
| `:vendor:ynhapi` | Innohi 工控板硬件 API（GPIO、静默安装、存储等） |

## 启动链路

`LaserApplication.onCreate()` → 基础组件 → 系统参数（隐藏状态栏/常亮）→ **串口 Modbus** → WebSocket → 网络监听 → 业务服务 → 定时上报

页面：`SplashActivity` → `SafetyTipsActivity` → `MainActivity`

## 主要功能页

- **快捷模式**：通用焊接 / CNC 切割
- **工程师模式**：焊接、清洗、切割参数
- **设备监控**：仪表盘、告警、工艺视频、统计
- **设备设置**：网络、设备信息、高级设置、屏幕显示

## 通信层

| 通道 | 技术 | 用途 |
|------|------|------|
| HTTP | Retrofit + OkHttp + Gson | REST API（工艺视频元数据、R2 STS 经 Worker `POST /v1/storage/r2/sts`） |
| WebSocket | OkHttp | 工艺参数/库推送、设备在线与 stat 通道 |
| Modbus RTU | 串口 `/dev/ttyS5` 等 | 读写寄存器，控激光器/焊机 |
| Room | SQLite v31 | 参数、告警、工艺、视频元数据 |

## 关键数据流

- **云 → 设备**：WebSocket → `ServerPushMessageHandler` → Room → UI → Modbus 写寄存器
- **设备 → 云**：Modbus 读 → `DeviceStatusPut` → WebSocket 上报
- **用户改参**：UI → ViewModel → Room → Modbus 下发
- **告警**：Modbus 读 → `WarnUtil` → Room → EventBus → UI

## 技术栈要点

Java 17 · ViewBinding/DataBinding · RxJava 3 · EventBus · Glide · Media3/ExoPlayer · Cloudflare R2（AWS S3 SDK）· YNHAPI 硬件 JAR

镜片 AI 类统一在 `com.lasercyber.lws.ai`（`NativeBridge`、`AiManager` 等）。

## 构建

```bash
./gradlew assembleDebug    # 或 assembleRelease
```

ABI 仅 `arm64-v8a`；依赖版本在 `gradle/libs.versions.toml`。

## 开发注意

- 耗时操作用 `ThreadPoolManager`，禁止主线程 IO
- Room 改表必须写 Migration
- Modbus 单线程调度保证指令顺序
- 摄像头与设备 **eth0 直连**，见 [`camera-eth0-topology.md`](camera-eth0-topology.md)

## 延伸阅读

完整目录树、API 表、包说明、命名约定见原文档。
