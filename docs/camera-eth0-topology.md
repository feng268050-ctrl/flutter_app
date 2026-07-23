# 摄像头以太网拓扑（产品硬约束）

本文档描述 LWS 工控设备上 **IP 摄像头与平板有线网** 的固定物理结构。  
软件、RTSP/AI/局域网代理等设计 **必须以本文为准**；勿按「eth0 接入车间交换机 / 与路由器同一广播域」建模。

## 1. 物理拓扑（不可变更）

- IP 摄像头与 Android 工控板 **一根网线直连**。
- 网线仅连接：**摄像头 RJ45 ↔ 设备 `eth0` 网卡**。
- 摄像头与 `eth0` 接口 **内置整机**，出厂后 **不可改线**，中间 **不经过交换机、路由器或集线器**。

```text
┌─────────────────────────────────────┐
│  LWS 整机（内置）                    │
│  ┌──────────┐   网线    ┌──────────┐ │
│  │  eth0    │──────────│ IP 摄像头 │ │
│  └──────────┘           └──────────┘ │
│  ┌──────────┐                        │
│  │  wlan0   │─── Wi‑Fi ──► 客户路由器 / 手机 │
│  └──────────┘                        │
└─────────────────────────────────────┘
```

## 2. 网络语义

| 接口 | 连接对象 | 典型用途 |
|------|----------|----------|
| **eth0** | 仅摄像头 | RTSP（`/PR0`、`/PR1`）、摄像头 HTTP 配置/对时 |
| **wlan0** | 客户现场 Wi‑Fi | 上云、设备 WebSocket、mDNS、本地 HTTP `:5580`（`:8080` 已废弃）、手机 App 连接设备 |

- 摄像头网段默认为 **`192.168.1.0/24`**（出厂 IP 固定为 `CameraConfig.CAMERA_IP`，`192.168.1.100`；掩码见 `CameraConfig.CAMERA_NETMASK`）。
- **eth0 链路上只有两台设备**（平板 + 摄像头）。车间其它 IP 在 Wi‑Fi 等侧，与 eth0 **二层隔离**。

## 3. 地址规划与冲突（设备侧责任）

### 3.1 必须避免

1. **平板 eth0 地址 = 摄像头 IP**（无法稳定通信）。
2. **平板 eth0 地址 = 本机 `wlan0` 当前 IPv4**（同机双接口地址冲突）。

### 3.2 不要求客户现场做的

- **不要求** 客户修改路由器 DHCP 池、保留地址或 Wi‑Fi 网段。
- eth0 与 Wi‑Fi 上 **其它设备** IP 数字相同（例如 Wi‑Fi 某设备为 `192.168.1.10`、eth0 为 `192.168.1.234`）在本文拓扑下 **不构成 eth0 链路冲突**。

### 3.3 App 侧行为（当前实现）

拉 RTSP / 使用摄像头能力前，由 **`SystemSettingUtils.setCameraNetworkSegment()`** 配置 `eth0`：

1. 读取摄像头主机：`CameraConfig.CAMERA_IP`（硬件固定，非运行时配置）。
2. 读取当前 Wi‑Fi IPv4：`WifiStatusUtils.getConnectedWifiInfo()`（与 **设置 → Wi‑Fi 详情** 同源）。
3. 由 **`CameraEth0AddressPlanner`** 在摄像头 **/24** 内选取平板 `eth0` 地址（候选主机位含 `234`、`253`、`252` 等），避开摄像头 IP 与 **同网段** 的 `wlan0` IP。
4. 由 **`CameraEth0Configurator`** 执行（幂等、带重试）：
   - 优先 `ip addr replace <tablet-ip>/24 dev eth0`（避免无谓 `flush` 导致短暂断链）；
   - 再依次尝试多种 `ip route`（含 `/24` 与摄像头 `/32` 主机路由）；
   - 配置前 `ip neigh flush dev eth0`；`ping -I eth0` 作可达性参考（多数 IPC **不回 ICMP**，ping 失败不代表 RTSP 不可用）；
   - Wi‑Fi 断开后延迟约 **1.5s** 再重配（`CameraEth0WifiNetworkCallback`）。
5. 地址与路由配置成功后，异步 **`GET /System/deviceinfo`** 并将归一化后的 `appVersion` 写入 **`CameraDeviceInfoCache`**（供 Settings 与 WebSocket `deviceInfo.cameraVersion` 读取）。

**Wi‑Fi 变化时**：`CameraEth0WifiNetworkCallback` 在连接、断开或 DHCP 地址变化时重新执行上述逻辑（未连 Wi‑Fi 时仅按摄像头网段选址）。

## 4. 与仓库其它模块的关系

| 模块 | 说明 |
|------|------|
| `CameraConfig` | `CAMERA_IP`、`CAMERA_NETMASK`；RTSP/HTTP 见 `CAMERA_RTSP_*_URL`、`BASE_CAMERA_APP_URL` |
| `CameraEth0AddressPlanner` | 按摄像头 / Wi‑Fi IP 计算 eth0 地址 |
| `SystemSettingUtils.setCameraNetworkSegment()` | 应用 `eth0` IP 与摄像头网段路由 |
| `CameraEth0WifiNetworkCallback` | Wi‑Fi 地址变化时重新配网 |
| 手机访问摄像头 RTSP | 手机不在 eth0 链路；需经平板 **代理/转发**（Wi‑Fi 访问设备 IP），不能假设手机直达 `192.168.1.100` |

## 5. 双码流（回顾）

- 主流 `PR0`、子流 `PR1` 均由 **eth0 → 摄像头** 拉取。
- Wi‑Fi 是否与 eth0 同网段（`192.168.1.x`）不影响「eth0 专链仅摄像头」；关键仍是 eth0 地址不与摄像头 / 本机 `wlan0` 冲突，且到摄像头 `/24` 的路由走 eth0。

## 6. 卸载旧版系统脚本（`192.168.1.10` self-heal）

若设备上曾安装 `install-eth0-autofix.sh`，需 root 删除 `/system` 内守护进程，否则会与 App 配网冲突：

```bash
# .env 或命令行设置 ADB_SERIAL
make uninstall-eth0-autofix
make uninstall-eth0-autofix REBOOT=1   # 建议：删掉 init.rc 后重启
```

等价脚本：`scripts/ci/uninstall-eth0-autofix.sh`。

## 7. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-05-25 | 明确摄像头与 eth0 机内直连、不经交换机，为产品硬约束 |
| 2026-05-25 | eth0 由 App 按摄像头 IP 自动配网并避开 wlan0；移除固定 `192.168.1.10` 系统脚本 |
| 2026-05-25 | 增加 `make uninstall-eth0-autofix` 卸载现场旧版 self-heal |
| 2026-05-25 | `CameraConfig` 移除 SharedPreferences 覆盖；eth0 地址由 `CameraEth0AddressPlanner` 派生 |
