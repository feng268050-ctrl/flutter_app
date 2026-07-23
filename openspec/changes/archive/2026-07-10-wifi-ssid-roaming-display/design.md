## Context

`WifiActivity` 在 `updateWifiList()` 中已有按 SSID 保留最强 RSSI 的内联逻辑，但：

1. 逻辑未抽取复用，其他入口（如 `findConnectedScanResult`、未来设置页）可能仍按 BSSID 逐条处理。
2. SSID 规范化不一致（引号、`"<unknown ssid>"`、空串）可能导致去重失效或重复行。
3. 产品所称「漫游」在此变更中指 **展示层语义**：用户只见一个 SSID，信号强度反映当前可达 AP 中的最优值；**不是** App 实现 802.11r/k/v 切换。

现有连接与配置策略（`WifiNetworkProfile` 键 = SSID + SecurityType，不绑 BSSID）保持不变，与 `wlan-static-ip` 设计一致。

## Goals / Non-Goals

**Goals:**

- Wi‑Fi 扫描列表对每个非空 SSID **仅显示一行**。
- 代表行使用 **RSSI 最高** 的 `ScanResult`（同 SSID 多 BSSID 时）。
- 列表展示名称为规范化 SSID；信号图标/标准信息来自代表 AP。
- 已连接网络单独置顶，不与扫描列表中的同 SSID 重复出现。
- 抽取 `WifiScanResultAggregator`（包路径建议 `com.lasercyber.lws.ui.common.network.wifi`）并加单元测试。

**Non-Goals:**

- 不实现系统级 Wi‑Fi 漫游 / 主动 BSSID 切换 / `WifiManager` 漫游配置。
- 不改变 `WifiConnectionCoordinator` 连接、静态 IP、`CameraEth0` 路由策略。
- 不在列表中展示 BSSID（仍可在详情页保留）。
- 不合并 **不同安全能力** 的同名 SSID（若扫描结果 capabilities 冲突，以最强信号那条为准并在连接时由现有 `deriveSecurityType` 处理；若需分开展示列为后续增强）。

## Decisions

### 1. 聚合键：规范化 SSID

- **决策**：`aggregate(scanResults, connectedSsid)` 以 `WifiStatusUtils.normalizeSsid`（或等价）后的 SSID 为 Map key。
- **理由**：Android `ScanResult.SSID` 与 `WifiInfo.getSSID()` 引号格式可能不同。
- **备选**：SSID+BSSID 作为 key — 拒绝，会导致同网重复行。

### 2. 代表 AP 选择：max RSSI

- **决策**：同 SSID 多条扫描结果时保留 `level`（RSSI）最大者。
- **理由**：与用户「跟信号走」的预期一致；连接仍由系统在该 SSID 下选 AP。
- **备选**：最近连接 BSSID 优先 — 超出展示层范围，且需额外状态。

### 3. 抽取 `WifiScanResultAggregator`

```text
WifiScanResultAggregator
  normalizeSsid(String) → String?
  aggregate(List<ScanResult>, @Nullable String connectedSsidToExclude)
    → List<AggregatedScanEntry>  // ssid, representative ScanResult, rssi
  sortForDisplay(List<AggregatedScanEntry>) → 按 rssi 降序
```

- `WifiActivity.updateWifiList()` 改为调用 aggregator，删除内联 `LinkedHashMap` 循环。
- `findConnectedScanResult()` 优先 BSSID 精确匹配，否则回退到 aggregator 中该 SSID 的代表结果。

### 4. 已连接行与扫描列表关系

- **决策**：`connectedSsid` 从扫描聚合输入中排除；顶部 `wifiCon` 行单独展示当前连接。
- **理由**：避免「已连接 + 列表中同 SSID 再出现一行」的双显。

### 5. 测试策略

- 纯 Java 单元测试：`WifiScanResultAggregatorTest`
  - 同 SSID 3 BSSID → 1 条，RSSI 取 max
  - 空 SSID 过滤
  - `connectedSsid` 排除
  - 排序

## Risks / Trade-offs

- **[Risk] 仅代表 AP 的 capabilities 与最终关联 AP 不一致** → 接受；连接对话框仍用代表结果的 capabilities；极端多 SSID 异构加密场景极少。
- **[Risk] 扫描缓存陈旧导致 RSSI 不实时** → 维持现有 150s 周期扫描；不在此变更引入主动 roam 触发。
- **[Risk] 内联逻辑迁移遗漏第二入口** → 任务中 grep `getScanResults` / `ScanResult` 列表构建点并统一。

## Migration Plan

1. 新增 aggregator + 测试（无行为变更的可先对齐测试与现有内联逻辑）。
2. 替换 `WifiActivity` 列表构建。
3. RK3566 实机：同 SSID 多 AP 环境验证列表唯一、信号随走动变化（扫描刷新后）。
4. 回滚：恢复 `WifiActivity` 内联实现即可，无数据迁移。

## Open Questions

- 设置页 `NetworkSettingFragment` 是否另有独立 Wi‑Fi 列表需同步？（实现阶段 grep 确认）
- 是否需要在列表行副标题显示「多 AP」提示？（默认否，保持简洁）
