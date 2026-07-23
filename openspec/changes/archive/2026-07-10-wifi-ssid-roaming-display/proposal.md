## Why

设备 Wi‑Fi 设置页在扫描结果中会把**同一 SSID 的多个 AP（不同 BSSID）**展示为多条网络，用户看到重复的 Wi‑Fi 名称，无法判断应连接哪一条。产品需要一种**展示层漫游机制**：列表按 SSID 唯一呈现，并以**当前最强信号**代表该网络的可视状态，与底层「按 SSID 保存配置、由系统负责 AP 切换」的策略一致。

## What Changes

- 引入统一的 **SSID 聚合规则**（扫描结果 → 展示列表）：同一 SSID 只显示一行，保留 RSSI 最高的 `ScanResult` 作为代表。
- 将聚合逻辑从 `WifiActivity` 内联实现提取为可复用组件，并在 Wi‑Fi 相关 UI（列表、已连接行辅助信息）统一使用。
- **展示名称**始终为用户可读的 SSID；BSSID 仅用于详情/调试，不作为列表去重键。
- 列表排序：已连接网络置顶；其余按代表 AP 的 RSSI 降序。
- 连接行为不变：用户仍按 **SSID + 安全类型** 发起连接；不绑定特定 BSSID（延续 `wlan-static-ip` 与企业 AP 漂移设计）。
- 补充单元测试，覆盖同 SSID 多 BSSID、空 SSID、已连接 SSID 与扫描结果合并等场景。

## Capabilities

### New Capabilities

- `wifi-scan-ssid-roaming`: Wi‑Fi 扫描结果按 SSID 去重、按信号强度选代表 AP、列表展示与排序规则。

### Modified Capabilities

- `wifi-network-details`: 已连接网络在设置入口展示的 SSID 与信号信息须与聚合后的扫描代表结果一致（不出现同 SSID 重复行）。

## Impact

- `WifiActivity`（扫描列表构建、已连接行绑定）
- 新增 `WifiScanResultAggregator`（或等价工具类）及测试
- 可选：`NetworkSettingFragment` / `WifiAdapter` 若存在独立扫描路径则对齐
- 不影响 `WifiConnectionCoordinator`、`WifiNetworkProfileStore` 的 SSID+SecurityType 存储键
- 不影响 `CameraEth0WifiNetworkCallback` 摄像头路由策略
