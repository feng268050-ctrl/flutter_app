# eLinux HMI HMI 规划（通用嵌入式 OS 方向 · ynh960 基准）

目标：在 **lws-hmi** Buildroot 基线上，用 **Weston + flutter-embedded-linux** 跑 Flutter UI；建设可复用的 **嵌入式 OS**：共用 **CyberUI** 框架与 **Dart HAL（`cyber_hal`）**，主板/屏幕以 **OEM board·screen pack** 插拔，**产品顶层 App 可分叉**（`gpio`/`modbus` 目录属 App，不进 OEM）。按 **P1→P5** 增量交付（见下表）。显示栈细节与切换命令见 [`embedder-migration-plan.md`](embedder-migration-plan.md)。平台化（OEM / 自有 SDK / P3.2 虚拟机）见 [`platform-os-oem-sdk-plan.md`](platform-os-oem-sdk-plan.md)。

**能力原则**：**产品能力不少于 lws-ui**；**Linux** 平台层长期为 **Buildroot + Dart HAL（`cyber_hal`）**；UI 为 **CyberUI**（初期 Frosted Glass，设计可换）；**产品子进程**（MediaMTX、日后 AI daemon）经 **`cyber_pm`** 由 App 监护，**不**默认进通用 rootfs；**P5.0** 保留 Android 兼容构建（**App/APK + YNHAPI**，不扩展 `cyber_hal`）；算法/拓扑/模型尽量复用。逐项对照见 **§11.5**。HAL 设计见 OpenSpec [`dart-hal-package`](../openspec/changes/archive/2026-07-18-dart-hal-package/design.md)（已归档）。MediaMTX App 化见 [`app-owned-mediamtx-cyber-pm`](../openspec/changes/archive/2026-07-30-app-owned-mediamtx-cyber-pm/)。AI daemon App 化见 [`app-owned-ai-daemon`](../openspec/changes/app-owned-ai-daemon/)。

**板级范围（当前）**：**ynh960 / ynh962 / ynh961** 同产品线三档（RK3566 → RK3568B2 → RK3568）；**P1～P4 以 ynh960 验收**。中长期目标是 **少量不同主板 + 不同屏幕** 共用 OS 契约与 CyberUI，而非每产品从零开始。Rockchip SDK `**rk3566_rk3568`** profile 见 **§3.0**。

---

## 1. 目标与范围


| 阶段 | 交付 | 状态 |
| ---- | ---- | --- |
| **Linux P1 — 平台镜像 + Hello World** | Linux 镜像开机/关机稳定；简单 Flutter **Hello, World!** | ✅ |
| **Linux P1.5 — 设备调试 + 快速 UI 迭代** | 真机调试模式跑 Flutter App；为快速 UI 迭代铺路 | ✅ |
| **Linux P2 — 硬件设施准备** | Modbus / 三色 LED / 喇叭 / 以太网 / Wi‑Fi / BT / 键盘 / 鼠标等硬件 I/O 接入与前置验证（含原 P2.1～P2.3：板级外设、日期时间 Demo、硬件偏好持久化） | ✅ |
| **Linux P2.5 — 双分区刷机** | A/B 双分区；经 Wi‑Fi / USB 的 `make upgrade`；加快硬件开发并为 OTA 打底（原 P2.4） | ✅ |
| **Linux P3.0 — UI 框架 + IME** | Flutter 重写 UI 框架与 IME：**CyberUI** + **CyberIME**（`packages/` path 包；初期 Frosted Glass，API 面向可换设计）；骨架已落地，持续优化中 | 🔄 |
| **Linux P3.1 — HAL 硬件抽象层** | **Dart HAL 子包** + **systemd-networkd 网络栈切换**（wpa D-Bus + networkd L3；无 Rust/`hald`）。设计：[`dart-hal-package`](../openspec/changes/archive/2026-07-18-dart-hal-package/design.md) | ✅ |
| **Linux P3.2 — Linux 模拟器** | 同 `Image` + 同 rootfs 内容 + OEM `sim_virt`；QEMU + VirGL 自动 `hmi.service`；细则 [`platform-os-oem-sdk-plan.md`](platform-os-oem-sdk-plan.md) §6 / W4；操作 [`p32-emulator.md`](p32-emulator.md)；OpenSpec `archive/2026-07-28-platform-p32-sim-virt` | ✅ |
| **Linux P3.3 — AI 库迁移** | `native/lws_ai` + `lws_ai_daemon` + RKNN；App 经 **`cyber_pm`** 监护；OpenSpec `app-owned-ai-daemon` | 🔄 |
| **Linux P4 — UI 界面与业务迁移** | 焊机 App：快速模式 / 工程师 / 监视器 / 设置等；告警、录像、AI、云服务等（原 P5 业务；子阶段见 **§1.2**）；IPC MediaMTX 已 App 化 | 🔄 |
| **Linux P5.0 — Android 兼容** | Flutter App 打 **APK**；Modbus / GPIO / Wi‑Fi / BT 等在 **App 侧**接 Android / `YNHAPI`（**不**往 `cyber_hal` 加 Android 后端） | 🔲 |
| **Linux P5.1 — 升级 Flutter Engine** | flutter-engine / SDK / flutter-embedded-linux：**3.24 → 3.41**（2026 代） | 🔲 |


状态图例：✅ 完成 · 🔄 进行中 · 🔲 未开始

**lws-ui 对照**：算法/拓扑/模型复用；平台层 → Linux + HAL；UI = CyberUI；**P4 业务子阶段 §1.2**、**P2.5 双分区 §1.3**；旧阶段号映射 **§1.4**；细则 **§12**；openspec **§11.7**。

当前 Rockchip 参考 defconfig 为 EVB 演示系统；替换为 **HMI 栈 + Weston + eLinux+ HAL**，按上表增量交付。

### 1.1 各阶段任务一览

```text
P1  镜像 + Hello World ✅
    ├─ lws_hmi defconfig + 方案 A systemd（§3.6）
    ├─ 裁剪 weston/chromium/camera/benchmark/adbd …
    ├─ 平台必须组件：Mali、Weston/eLinux、LCD/splash、RKNPU2 运行时、Wi‑Fi/BT、powermanager …
    ├─ hmi.service 自启；Hello World → /opt/hmi
    └─ 验收：logo → 首页 ≤10 s（§14.2）

P1.5  设备调试 + 快速 UI 迭代 ✅
    ├─ make debug-app：真机调试模式（断点、热重载、VM Service）
    ├─ VSCode / Cursor Flutter 插件接入
    └─ make push-app：USB-SSH 快速替换 release/debug bundle

P2  硬件设施准备 ✅（含原 P2 / P2.1 / P2.2 / P2.3）
    ├─ Modbus RTU + GPIO 三色灯（gpio_innohi）；Demo 读设备/控灯
    ├─ 喇叭 / Wi‑Fi / BT / eth0 / 触控 / USB HID 键盘·鼠标 / 背光·旋转
    ├─ 按需 LAN/WLAN sshd；pinmux 台账 docs/ynh960-io-pinmux-ledger.md
    ├─ 日期/时间 Demo（DateTimeController）
    └─ 硬件偏好持久化 + settings-restore（独立于 hmi.service cgroup）

P2.5  A/B 双分区 + make upgrade ✅（原 P2.4）
    ├─ boot/boot_b + rootfs_a/rootfs_b；misc try-boot / 回滚
    ├─ 主机 make upgrade（USB-SSH / LAN）；不进 loader
    └─ 产品 OTA UI 仍属 P4（业务迁移内的 OTA 子阶段）

P3.0  CyberUI + CyberIME（packages/ path 包）🔄
    ├─ packages/cyber_ui — CyberUI（初期 Frosted Glass；§6.3；骨架 + frost parity 已落地，持续优化）
    ├─ packages/cyber_ime — IME overlay（EnglishGlobal v1；中文等仍优化中）
    └─ 主 App pubspec path 依赖；设计可换，API 用 Cyber* 前缀

P3.1  Dart HAL 子包 + 网络栈切换 ✅
    ├─ packages/cyber_hal/：hal/network|output|input|… 按需 import
    ├─ **启用 systemd-networkd**（L3）+ wpa D-Bus（L2）；旧 L3 脚本删除或改为 networkd 封装
    ├─ restore/persist 按新栈重做；相机 eth0 动态配址改为重配 networkd
    ├─ backlight/volume/gpio/modbus… 配置/路径注入
    └─ 设计：openspec/changes/archive/2026-07-18-dart-hal-package/（D11）

P3.2  Linux 模拟器 ✅（W4 / archive/2026-07-28-platform-p32-sim-virt）
    ├─ QEMU + VirGL + Weston + eLinux + Linux HAL；三网卡 + ethssh；无 OTG
    ├─ sim_virt OEM；USB BT/串口；GPIO LED 悬浮层（参考系统状态浮层）
    ├─ 平台化：OEM · 通用 boot/rootfs · 自有 linux-sdk
    │   （见 docs/platform-os-oem-sdk-plan.md；gpio/modbus 仍属产品 App）
    │   操作见 docs/p32-emulator.md（原 UTM 方案已改为 QEMU）
    └─ 量产显示栈：Weston + eLinux
        （见 docs/embedder-migration-plan.md）

P3.3  AI → `native/lws_ai` / daemon 🔄
    ├─ 源码：`native/lws_ai`（自 lws-ui lensinspector 迁入）；`make build-opencv` + `make build-ai` → `prebuilt/`
    ├─ 产品路径：`/opt/hmi/bin/lws_ai_daemon` + `/opt/hmi/lib`；Unix sock `/run/hmi/ai/`；workdir `/var/lib/hmi/ai/`
    ├─ App：`AiDaemonSupervisor` + `cyber_pm`（冷启动 smoke：`daemon_ready` / `ping`）
    └─ 业务叠框 UI 仍在 P4；OpenSpec `openspec/changes/app-owned-ai-daemon/`

P4  业务迁移（子阶段见 §1.2）🔄
    ├─ 已交付切片：产品 Home / Settings / Monitor（告警温度）/ 开机自检 / 系统状态卡等
    ├─ **IPC MediaMTX**：产品运行时 — `/opt/hmi/bin/mediamtx` + Dart YAML + `cyber_pm`
    │   （OpenSpec `app-owned-mediamtx-cyber-pm`）；**不进**通用 rootfs
    ├─ packages/cyber_pm — 可复用子进程监护（MediaMTX 已用；AI 复用）
    ├─ 进行中：P4.2 网络与状态栏、P4.6 其余业务页；云服务 / `:5580`（OpenSpec `align-cloud-local-server`）已落地非 OTA 切片；AI Vision / process-video AI SSE（`ai-vision-and-process-video-ai`）已落地最小可交付；P4.1 / P4.3～P4.5 / P4.7～P4.8 未开始
    └─ 依赖 CyberUI（优化中）+ HAL（设置/硬件页）

P5.0  Android 兼容 🔲
    ├─ Flutter App 双目标 APK；平台能力走 Android / YNHAPI（非 cyber_hal）
    └─ Modbus / GPIO / Wi‑Fi / BT 等 App 侧适配；make build-apk / push-apk

P5.1  Flutter Engine / SDK / flutter-embedded-linux 升级 🔲
    └─ 3.24 → 3.41 代；三件套（SDK + engine + eLinux）重编

参考链接：
- eLinux / GStreamer video_player（预览栈）
- [RKNN-Toolkit2](https://github.com/airockchip/rknn-toolkit2) — 模型转换
- lws-hmi `README.md` — ynh960 显示参数、Docker 构建
- lws-hmi `native/lws_ai` — Linux AI daemon / libai 源（自 lws-ui `native/lensinspector`）
- lws-ui `native/lensinspector` — 历史 Android 参考实现（对照用）
- lws-ui `openspec/specs/*` — UI/交互**参考**（非完整迁移清单，§11.7）
- lws-ui `docs/project-architecture-summary.md`、`docs/root-docs-index.md` — 实装与文档索引
- lws-ui `scripts/make/convert-rknn.sh` — RKNN 模型转换流水线
- lws-ui `docs/camera-eth0-topology.md`、`docs/dual-stream-summary.md`、`docs/network-api-reference.md` — PR0/PR1 与 MediaMTX LAN URL
- lws-ui `MediaMtxConfigRenderer.java` / `MediaMtxRelayUrls.java` — YAML 与 URL 规范（Linux：`MediaMtxConfigWriter` + `/opt/hmi/bin/mediamtx`）
- lws-ui `AdbRemoteDebugHelper.java` / `POST /v1/adb` — SSH 隐藏调试对标（§7.7）
- lws-ui `docs/frostui.md`、`FrostBlurViewSupport.kt` — Frost 冻结/live 语义对照（§6.3）
- Rockchip SDK `buildroot/configs/rockchip_rk3566_rk3568_defconfig` — 当前臃肿基线（对照用）

---

**总结**：**能力不少于 lws-ui**（§11.5）。**P1～P2.5 与 P3.1（`cyber_hal` + networkd）已完成**；**IPC MediaMTX 已 App 化（`cyber_pm` + `/opt/hmi/bin`）**；**P3.3 AI daemon 脚手架进行中**（`native/lws_ai` + `cyber_pm` smoke）。**进行中**：**P3.0 CyberUI/IME**（优化）、**P4**（含 **P4.2** 网络与状态栏、**P4.6** 业务页切片）。其后仍待：P3.3 板端验收与 P4 AI UI、P4 其余子阶段、**P5.0 Android（App/APK + YNHAPI，非 `cyber_hal`）**、**P5.1 Engine 升级**。**P3.2 模拟器主路径已落地**（USB Wi‑Fi/BT ⏸）。Linux 平台层长期为 **`cyber_hal` + Buildroot**；产品附属进程用 **`cyber_pm`**；UI 框架名 CyberUI（初期 Frosted Glass）。旧阶段号见 **§1.4**。以 lws-ui 实装为准，openspec 作补充（§11.7）。
