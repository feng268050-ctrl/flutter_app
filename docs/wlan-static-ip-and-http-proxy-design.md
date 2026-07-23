# Wi‑Fi 静态 IP 与 HTTP 代理方案

本文档描述 LWS 工控设备在 **客户现场路由器无 DHCP**、或 **企业内网需经 HTTP 代理出站** 场景下的能力缺口、设计约束与实现方案。

与 [`camera-eth0-topology.md`](camera-eth0-topology.md) 配套阅读：eth0 专链摄像头逻辑 **职责不变**，但路由策略需按 wlan0 网段动态切换。

| 项 | 值 |
|----|-----|
| 状态 | 方案（待实现） |
| 影响范围 | `wlan0` 用户配网、出站 HTTP/WebSocket |
| 不涉及 | 用户直接配置 eth0、`CameraLanHttpProxy` 语义变更 |

---

## 1. 目标

解决以下两类现场网络问题。

### 1.1 路由器无 DHCP

设备允许用户在 **连接 Wi‑Fi 时** 配置：

```text
SSID
Password
IP Mode
├── DHCP
└── STATIC
    ├── IP
    ├── Prefix / Mask
    ├── Gateway
    ├── DNS1
    └── DNS2
```

期望链路：

```text
Wi‑Fi 关联
    ↓
STATIC IPv4
    ↓
Gateway 可达
    ↓
公网直连 或 HTTP Proxy
```

**关键约束**：静态 IP 必须是连接流程的一部分，不能等「连上后再进详情页」——无 DHCP 时关联成功但拿不到 IP，用户将无法进入详情页配置静态地址。

### 1.2 企业网络要求 HTTP 代理

以下 **公网访问** 支持 HTTP Proxy：

- 业务 API（Retrofit）
- WebSocket
- API Origin Probe
- OTA Manifest / OTA Package
- AI Report、R2 Upload、Users API

以下 **局域网访问** 保持直连：

- Camera HTTP / RTSP
- `CameraLanHttpProxy`
- `localhost`、本地 MediaMTX

---

## 2. 当前代码现状

### 2.1 Wi‑Fi 连接链路

```text
WifiActivity
    ↓
FrostWifiPasswordDialog
    ↓
connectAndSaveWifi()
    ↓
SystemWifiManagerUtils.connectOrUpdateNetwork(ssid, password)
    ↓
WifiConfiguration → updateNetwork / addNetwork
    ↓
disconnect → enableNetwork → reconnect
```

**主要问题**：

| 问题 | 说明 |
|------|------|
| Dialog 只处理密码 | 无静态 IP 配置入口；开放 Wi‑Fi 直连时同样无法在连接前设静态 IP |
| `SystemWifiManagerUtils` 职责过重 | 继续塞入 Profile / Store / Validator 会过度膨胀 |
| 连接状态判断粗糙 | 无法区分「已关联但无 IP」「已有 IP」「已真正联网」 |

### 2.2 HTTP Client 分布

出站请求 **并未统一**，不能只改 `OkHttpConfig`：

| 模块 | 客户端 |
|------|--------|
| Retrofit API | `OkHttpConfig` → `RetrofitClient` |
| API 探针 | `DeviceApiOriginProber` 自建 Client |
| OTA 清单 | `OtaUpdateManifestService` 独立 static Client |
| OTA 包下载 | `UpgradeActivity` 使用 `HttpURLConnection` |
| WebSocket | `DeviceWebSocketConnectionManager` 独立 Client |
| AI / R2 / Users | 各自独立 Client |

**结论**：先统一 Client 创建入口，再增加代理支持。

### 2.3 eth0 与 YNHAPI（基线，不变更职责）

- eth0 仍由 `CameraEth0Configurator` 自动配置，用户不直接操作。
- `vendor/ynhapi` 的 `setStaticIp()` / `setDhcpIp()` 与以太网 API 同组，**未接入**；wlan0 静态 IP 优先走 Android Wi‑Fi API。

---

## 3. 总体架构

```text
                         User UI
                            │
             ┌──────────────┴──────────────┐
             │                             │
             ▼                             ▼
      Wi‑Fi Settings                 HTTP Proxy Settings
             │                             │
             ▼                             ▼
  WifiConnectionCoordinator         HttpProxySettingsStore
             │                             │
     ┌───────┼────────┐                    ▼
     │       │        │         NetworkHttpClientProvider
  Profile  Validator  Applier               │
     │                 │           ┌───────┴───────┐
     └────────┬────────┘           │               │
              ▼                    ▼               ▼
         WifiManager        Proxy-aware       Direct LAN
              │                 Client            Client
              ▼                    │               │
            wlan0           API / WS / OTA       Camera
              │             Upload / R2          Localhost
              │                                  MediaMTX
       LinkProperties
              │
              ▼
  CameraEth0WifiNetworkCallback
              │
              ▼
       Camera Route Policy
              │
        ┌─────┴─────┐
        │           │
   No overlap    Overlap
        │           │
        ▼           ▼
   /24 route     /32 route
        │           │
        └─────┬─────┘
              ▼
             eth0 → Camera
```

---

## 4. Wi‑Fi 静态 IP 设计

### 4.1 核心原则

静态 IP **不是** `WifiDetailsActivity` 的附加功能，必须支持 **连接前配置**。

错误路径（无 DHCP 时会死锁）：

```text
选择 Wi‑Fi → 输入密码 → 已关联但无 IP → 无法进详情页 → 无法设 STATIC
```

推荐路径：

```text
点击 Wi‑Fi
    ↓
FrostWifiJoinDialog
    ├── Password（开放网络可隐藏）
    └── Advanced → IP Settings
            ├── DHCP
            └── STATIC
    ↓
Connect
```

`WifiDetailsActivity` 继续提供：查看当前状态、编辑 DHCP/STATIC、保存并重连。

### 4.2 推荐分层

```text
WifiActivity
    ↓
FrostWifiJoinDialog
    ↓
WifiConnectionCoordinator
    ├── WifiNetworkProfileStore
    ├── WifiIpConfigValidator
    └── WifiIpConfigApplier
            ↓
    SystemWifiManagerUtils
            ↓
        WifiManager
```

| 模块 | 职责 |
|------|------|
| `WifiActivity` | Wi‑Fi 列表与用户操作 |
| `FrostWifiJoinDialog` | 密码及高级网络配置（含开放 Wi‑Fi） |
| `WifiConnectionCoordinator` | 连接流程协调 |
| `WifiNetworkProfileStore` | 持久化用户期望配置 |
| `WifiIpConfigValidator` | IP 参数校验 |
| `WifiIpConfigApplier` | DHCP/STATIC 系统配置适配（隔离 @hide API） |
| `SystemWifiManagerUtils` | 基础 `WifiManager` 操作 |

### 4.3 数据模型

#### `WifiIpConfig`

```java
public final class WifiIpConfig {
    public enum Mode { DHCP, STATIC }

    public final Mode mode;
    @Nullable public final String ip;
    public final int prefixLength;   // 内部统一用前缀，如 24
    @Nullable public final String gateway;
    @Nullable public final String dns1;
    @Nullable public final String dns2;
}
```

- 内部统一：`192.168.10.50` + `prefixLength = 24`
- UI 可输入 `255.255.255.0`，保存前转换为前缀长度，避免同时维护两种表示

#### `WifiNetworkProfile`

```java
public final class WifiNetworkProfile {
    public final String ssid;
    public final String securityType;
    public final WifiIpConfig ipConfig;
}
```

**Profile Key**：`SSID + SecurityType`（不用单独 SSID，避免同名 SSID 误复用；不用 BSSID，企业网同 SSID 多 AP 会漂移）。

#### `WifiConnectRequest`

不再扩展 `connectOrUpdateNetwork(ssid, password)`，改为：

```java
public final class WifiConnectRequest {
    public String ssid;
    public String password;
    public String securityType;
    public WifiIpConfig ipConfig;
}

// 调用
wifiConnectionCoordinator.connect(request);
```

### 4.4 `SystemWifiManagerUtils` 优化

连接时不应每次从空 `WifiConfiguration` 重建，应：

```text
查找已有 WifiConfiguration
    ├── 已存在 → 修改已有配置
    └── 不存在 → 创建新配置
```

推荐流程：

1. 权限检查
2. Wi‑Fi 状态检查
3. 获取或创建 `WifiConfiguration`
4. 设置认证方式
5. 应用 DHCP / STATIC
6. `updateNetwork` / `addNetwork`
7. `enableNetwork` → `reconnect`
8. 等待 `LinkProperties` 更新
9. 验证网络状态

接口：

```java
OperationResult connectOrUpdateNetwork(WifiConnectRequest request);
```

### 4.5 `WifiIpConfigApplier`

将隐藏 API / 固件差异集中隔离：

```java
public interface WifiIpConfigApplier {
    boolean isSupported();
    ApplyResult applyDhcp(WifiConfiguration config);
    ApplyResult applyStatic(WifiConfiguration config, WifiIpConfig ipConfig);
}
```

负责：`StaticIpConfiguration`、`IpAssignment`、Android 10/11 差异、反射、权限检查、异常处理。主连接流程不直接依赖具体实现。

### 4.6 STATIC 与 DHCP 切换

**STATIC**：

```text
WifiConfiguration
    → IpAssignment.STATIC
    → StaticIpConfiguration
        ├── LinkAddress
        ├── Gateway
        └── DNS
```

**切回 DHCP** 必须同时清理：

```text
IpAssignment = DHCP
StaticIpConfiguration = null
```

不能只改 `Profile.mode = DHCP`，否则系统可能残留旧静态配置。

### 4.7 参数校验（`WifiIpConfigValidator`）

| 项目 | 规则 |
|------|------|
| IPv4 | 合法点分十进制 |
| Prefix | 合法前缀范围 |
| Network / Broadcast | 禁止作为设备 IP |
| Gateway | 合法地址；不应与 Camera IP 冲突 |
| DNS1 | STATIC 模式必填 |
| DNS2 | 可选 |
| Camera IP | wlan0 IP 不可与 `CameraConfig.CAMERA_IP` 完全相同 |
| eth0 IP | wlan0 IP 不可与本机 eth0 当前 IP 完全相同 |
| 网段重叠 | 允许，但触发 Camera Route Policy（见 §5） |

---

## 5. Wi‑Fi 状态模型

### 5.1 三阶段状态

不再仅用 `isWifiConnected()`，需区分：

| 状态 | 含义 |
|------|------|
| **ASSOCIATED** | Wi‑Fi 已关联（SSID 可识别、WPA 成功），但可能 `IP = 0` |
| **L3_READY** | IPv4 / 路由 / DNS 已就绪（DHCP 或 STATIC） |
| **INTERNET_READY** | 公网 API 可达，或 Proxy 可达且 API 经 Proxy 可达 |

```text
ASSOCIATED → L3_READY → INTERNET_READY
```

### 5.2 快照对象

| 对象 | 来源 | 用途 |
|------|------|------|
| `WifiAssociationSnapshot` | 关联层 | SSID、BSSID、RSSI、Frequency、Security |
| `WifiLinkSnapshot` | `LinkProperties` | IPv4、Prefix、Gateway、DNS |

**原则**：`WifiNetworkProfileStore` = 用户期望；`LinkProperties` = 系统真值。两者不可混用。

---

## 6. eth0 摄像头专链与路由策略

### 6.1 职责不变

eth0 仍由 `CameraEth0Configurator` 自动配置，用户不直接配置 eth0。

### 6.2 同网段风险

若 wlan0 与摄像头同 `/24`，且 eth0 安装 `192.168.1.0/24 → eth0` 路由，则客户 Wi‑Fi LAN 中其他 `192.168.1.x` 也可能错误走 eth0。

**不能**简单认为「wlan0 与 eth0 同网段、IP 不同即可」。

### 6.3 `CameraRoutePolicy`

```java
enum CameraRoutePolicy {
    CAMERA_SUBNET_ROUTE,  // 192.168.1.0/24 → eth0
    CAMERA_HOST_ROUTE     // 192.168.1.100/32 → eth0
}
```

| 场景 | wlan0 | camera | 策略 |
|------|-------|--------|------|
| **A：网段不重叠** | `10.10.20.50/24` | `192.168.1.100` | `CAMERA_SUBNET_ROUTE`（`/24 → eth0`） |
| **B：网段重叠** | `192.168.1.50/24`，gw `192.168.1.1` | `192.168.1.100` | `CAMERA_HOST_ROUTE`（`/32 → eth0`，避免 `/24` 劫持客户 LAN） |

### 6.4 `CameraEth0WifiNetworkCallback` 优化

增加 `onLinkPropertiesChanged(Network, LinkProperties)`，链路：

```text
STATIC IP Apply
    ↓
wlan0 LinkProperties Changed
    ↓
CameraEth0WifiNetworkCallback
    ↓
判断 wlan0 与 Camera LAN 是否重叠
    ↓
选择 Route Policy → 重配 eth0 route
```

不要只依赖 `onAvailable` / `onLost` / `onCapabilitiesChanged` 间接发现 IP 变化。

---

## 7. HTTP Proxy 架构

### 7.1 先收敛 Client，再注入 Proxy

不推荐逐个 Client 调用 `applyProxy()`，易遗漏。

```text
HttpProxySettingsStore
        ↓
NetworkHttpClientProvider
        ├── INTERNET_PROXY_AWARE
        │       Retrofit / WebSocket / Probe
        │       OTA Manifest / OTA Download
        │       AI Report / R2 / Users
        │
        └── DIRECT_LAN
                Camera HTTP / CameraLanHttpProxy
                localhost / MediaMTX Local API
```

### 7.2 Provider 接口

不同业务可有不同 timeout，但共享路由策略：

```java
enum NetworkRoutePolicy {
    INTERNET_PROXY_AWARE,
    DIRECT_LAN
}

enum ClientPurpose {
    API, WEBSOCKET, PROBE,
    OTA_MANIFEST, OTA_DOWNLOAD, UPLOAD
}

OkHttpClient getClient(
    ClientPurpose purpose,
    NetworkRoutePolicy routePolicy,
    @Nullable Network boundNetwork
);
```

示例：

| 场景 | purpose | route | boundNetwork |
|------|---------|-------|--------------|
| Retrofit | `API` | `INTERNET_PROXY_AWARE` | — |
| Origin Prober | `PROBE` | `INTERNET_PROXY_AWARE` | wlan `Network` |
| Camera HTTP | `API` | `DIRECT_LAN` | — |

### 7.3 数据模型

```java
public final class HttpProxySettings {
    public boolean enabled;
    public String host;
    public int port;
    public ProxyAuthType authType;  // NONE | BASIC
    public String username;
    public String password;
}
```

**v1 支持**：HTTP Proxy、HTTPS over HTTP Proxy、Basic Auth、WebSocket / WSS。

**v1 不支持**：SOCKS5、PAC、NTLM、Kerberos。

### 7.4 Client Generation 生命周期

不推荐各模块手动 `CLIENT = null`。

```text
Proxy Settings V1 → Client Generation 1
用户保存 V2      → generation++
                      ├── NetworkHttpClientProvider.invalidate()
                      ├── RetrofitClient.invalidate()
                      └── WebSocket: 关闭旧连接 → 新 Generation → connectOrReconnect("proxy_settings_changed")
```

### 7.5 OTA 路径

| 环节 | 现状 | 目标 |
|------|------|------|
| Manifest | 独立 Client | `getClient(OTA_MANIFEST, INTERNET_PROXY_AWARE)` |
| Package | `HttpURLConnection` | OkHttp 流式下载 → 写 ZIP → SHA512 校验 |

避免为 OTA 单独维护代理逻辑。

---

## 8. UI 设计

### 8.1 `FrostWifiJoinDialog`（替代/扩展密码 Dialog）

```text
FrostWifiJoinDialog
├── Password（开放 Wi‑Fi 隐藏）
└── Advanced → IP Settings
      ├── DHCP
      └── STATIC → IP / Mask / Gateway / DNS1 / DNS2
```

开放 Wi‑Fi + 无 DHCP 场景：同样进入 Join Dialog，仅不显示 Password。

### 8.2 `WifiDetailsActivity`

展示（来自 `LinkProperties` 真值）：

- SSID、Security、Signal
- IP Mode、IP Address、Subnet Mask、Gateway、DNS1、DNS2

操作：`[编辑 IP 配置]`、`[忘记网络]`

编辑页读写 `WifiNetworkProfile`；详情页显示系统实际状态。

### 8.3 HTTP Proxy 页面

入口：`NetworkSettingFragment` → HTTP Proxy

```text
Enable Proxy [Switch]
Host / Port
Authentication: None / Basic
Username / Password
[Test Connection]  [Save]
```

---

## 9. 推荐文件结构

```text
common/network/
├── wifi/
│   ├── WifiIpConfig.java
│   ├── WifiNetworkProfile.java
│   ├── WifiNetworkProfileStore.java
│   ├── WifiConnectRequest.java
│   ├── WifiIpConfigValidator.java
│   ├── WifiIpConfigApplier.java
│   ├── WifiConnectionCoordinator.java
│   ├── WifiAssociationSnapshot.java
│   └── WifiLinkSnapshot.java
├── proxy/
│   ├── HttpProxySettings.java
│   ├── HttpProxySettingsStore.java
│   ├── ProxyAuthType.java
│   └── NetworkHttpClientProvider.java
└── camera/
    ├── CameraEth0AddressPlanner.java      （已有）
    ├── CameraEth0Configurator.java        （已有，扩展 RoutePolicy）
    ├── CameraRoutePolicy.java             （新增）
    └── CameraEth0WifiNetworkCallback.java （已有，扩展 onLinkPropertiesChanged）
```

现有 `SystemWifiManagerUtils`、`WifiStatusUtils`、`OkHttpConfig`、`RetrofitClient` **逐步缩小职责**，不继续向内堆功能。

---

## 10. 实施阶段

### Phase 0：网络状态模型重构

- `WifiAssociationSnapshot`、`WifiLinkSnapshot`
- 区分：已关联无 IP / 有 IP 无公网 / 需 Proxy 才能访问公网

### Phase 1：STATIC IP

- `WifiIpConfig`、`WifiNetworkProfile`、`Store`、`Validator`、`Applier`、`WifiConnectionCoordinator`
- UI：`FrostWifiJoinDialog` + Advanced；`WifiDetailsActivity` 编辑
- `CameraEth0WifiNetworkCallback.onLinkPropertiesChanged` + `CameraRoutePolicy`

**验收**：

```text
Router DHCP OFF → 选 SSID → 密码 + STATIC → Connect
→ wlan0 IP 正确 → Gateway 可达 → API 可达 → Camera RTSP 正常
```

### Phase 2：HTTP Client 收敛

- 实现 `NetworkHttpClientProvider`
- 迁移：Retrofit、WebSocket、Probe、OTA、AI、R2、Users
- **先收敛，再加 Proxy**

### Phase 3：HTTP Proxy

- `HttpProxySettings`、`Store`、Proxy UI、Test Connection
- Client Generation + WebSocket Reconnect

**验收**：STATIC IP + Proxy 下 HTTPS API、WSS、OTA、Upload 全部正常；Camera / localhost 仍 DIRECT。

---

## 11. 测试计划

### 11.1 Wi‑Fi

| 场景 | 预期 |
|------|------|
| DHCP 正常 | 与现网一致 |
| DHCP OFF + STATIC | 可联网 |
| 已关联但无 IP | UI 显示 ASSOCIATED，不误判完全断开 |
| STATIC → DHCP | 清除静态配置并重新获址 |
| DHCP → STATIC | 重连后静态生效 |
| Forget Network | 同步清除对应 Profile |
| Open Wi‑Fi + STATIC | 连接前可配置 |

### 11.2 eth0

**Case A（不重叠）**：wlan0 `10.0.0.50/24`，camera `192.168.1.100` → `192.168.1.0/24 → eth0`

**Case B（重叠）**：wlan0 `192.168.1.50/24`，gw `192.168.1.1`，camera `192.168.1.100` → `192.168.1.100/32 → eth0`

同时验证：Camera RTSP/HTTP、Gateway 经 wlan0、客户 LAN 主机经 wlan0、API/WS/OTA 正常。

### 11.3 HTTP Proxy

- Proxy OFF / ON（No Auth / Basic Auth）
- 错误 Host/Port/用户名/密码
- 修改 Proxy 后 WebSocket 自动重连
- OTA Manifest/Package、AI、R2 经 Proxy；Camera HTTP/RTSP、localhost 仍 DIRECT

---

## 12. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 无 DHCP 无法进详情页 | STATIC 必须支持连接前配置（Join Dialog） |
| 同名 SSID 误复用 | Profile Key = SSID + SecurityType |
| Profile 与系统不一致 | `LinkProperties` 为运行真值 |
| STATIC→DHCP 残留 | 显式清空 `StaticIpConfiguration` |
| API/固件差异 | 集中到 `WifiIpConfigApplier` |
| wlan0/eth0 同网段 | 按 overlap 切换 `/24` 或 `/32` Route Policy |
| 多 Client 漏接代理 | `NetworkHttpClientProvider` 统一出口 |
| Proxy 变更旧 WS 仍连 | Client Generation + WS Reconnect |
| OTA 不走统一代理 | `HttpURLConnection` 迁 OkHttp |
| Camera LAN 误走 Proxy | `DIRECT_LAN` 独立策略 |

---

## 13. 结论（三条核心方向）

### 1. STATIC IP 是连接流程的一部分

```text
选择 Wi‑Fi → Password + Advanced → DHCP/STATIC → Connect
```

而非：连上 → 详情页 → 再配 STATIC。

### 2. eth0 保持摄像头专链，路由策略动态切换

```text
wlan0 与 Camera LAN 不重叠 → Camera /24 → eth0
wlan0 与 Camera LAN 重叠   → Camera /32 → eth0
```

### 3. HTTP Proxy 先统一 Client，再增加代理

```text
NetworkHttpClientProvider
    → 迁移 Retrofit / WS / OTA / Upload
    → HttpProxySettings + Client Generation
```

不建议在多个现有 Client 中分别加代理。

### 推荐端到端架构

```text
Wi‑Fi → WifiConnectionCoordinator → DHCP/STATIC → WifiManager → wlan0
    → LinkProperties → Camera Route Policy → eth0 → Camera

HTTP → NetworkHttpClientProvider
    ├── INTERNET_PROXY_AWARE → API / WS / OTA / Upload
    └── DIRECT_LAN           → Camera / localhost / Local Services
```

在不破坏现有 DHCP、eth0 专链与网络请求的前提下，可逐步落地静态 IP 与 HTTP Proxy，并降低后续维护成本。

---

## 14. 相关文档

| 文档 | 说明 |
|------|------|
| [`camera-eth0-topology.md`](camera-eth0-topology.md) | eth0 专链硬约束 |
| [`system-wifi-privileged-setup.md`](system-wifi-privileged-setup.md) | priv-app Wi‑Fi 权限 |
| [`network-api-reference.md`](network-api-reference.md) | HTTP / WebSocket 端点 |
| `vendor/ynhapi/API.md` | 板卡网络 API（未用） |

---

## 15. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-07-09 | 初稿 |
| 2026-07-09 | 提炼整理：连接前 STATIC、Coordinator 分层、三态模型、CameraRoutePolicy、Client Provider + Generation |
