## Context

- 应用为 Android（`lws-ui`），已有 `WifiActivity`、`WifiStatusUtils`、`NetworkStatusUtil`、`SystemWifiManagerUtils` 等 WiFi 相关能力；启动链为 `SplashActivity` → `SafetyTipsActivity` → `UseSafetyTipsActivity` → 主流程（含 `MainActivity` 等）。
- `MainActivity` 已注册 `SimpleWifiConnectReceiver`，具备监听 WiFi 连接变化的先例。
- 项目存在基于 `SharedPreferences` 的运行时配置（如 `AppRuntimeEnvironment`），适合存放一次性「WiFi 初始化已完成」标记。

## Goals / Non-Goals

**Goals:**

- **仅当未连接 WiFi** 时于合适界面提示用户连接 WiFi，确认后进入系统 WiFi 设置（`Settings.ACTION_WIFI_SETTINGS`）或团队确认的等价入口。
- 在入口检查或回调中一旦判定**已连接 WiFi** 且标记仍为假，**立即**写入持久化标记（同一逻辑路径内完成，不延迟到后续事件）；之后无论是否断开、忘记网络，均不再展示该引导弹窗。
- 将「是否已完成初始化」与「当前是否连着 WiFi」解耦：弹窗仅受持久化标记控制（标记为真后永不因未连接而再弹）。

**Non-Goals:**

- 不强制用户必须点击弹窗才能完成应用使用（若需「仅确认跳转、允许稍后」可在实现阶段用取消/关闭行为定义，默认规格以「完成初始化以首次连接成功为准」）。
- 不修改系统 WiFi 特权连接、OTA 等无关模块的架构。
- 不解决非 WiFi 网络（蜂窝/以太网）是否算「初始化完成」的争议：规格以 **WiFi 传输** 成功为准，若需扩展可在 Open Questions 中跟进。

## Decisions

1. **持久化键与存储**  
   - **决策**：使用与现有应用一致的 `SharedPreferences`（或封装层），新增独立 key，例如 `wifi_initialization_completed`（最终实现命名以代码规范为准）。  
   - **备选**：DataStore — 对单一布尔值偏重，且与现有 `AppRuntimeEnvironment` 模式不一致时可不引入。

2. **何时展示弹窗**  
   - **决策**：在用户进入**稳定主界面**或完成安全提示后的首个合适 Activity（如 `MainActivity` 的 `onResume` / 首次布局就绪）先做连接性判断：**仅当** `!wifi_initialization_completed && !当前已连 WiFi` 时展示弹窗。若当前**已连 WiFi** 且标记仍为假，**不得**展示弹窗；须在同一次检查中**立即** `wifi_initialization_completed = true` 并持久化。  
   - **备选**：在 `SplashActivity` 展示 — 过早且可能被立即 finish，体验较差。

3. **何时将标记置为真**  
   - **决策**：任一时刻首次判定 **WiFi 已连接**（与 `WifiStatusUtils.isWifiConnected` 或 `NetworkStatusUtil.isWifiAvailable` 对齐，实现阶段二选一并在代码注释中固定）且标记为假时，**立即**写入 `true`：包括「进入检查点时已经连着 WiFi」与「从未连接变为已连接」两种路径。用户日后忘记网络不改变该标记。  
   - **备选**：仅在 `WifiActivity` 内连接成功时写入 — 会漏掉用户在系统设置里首次连 WiFi 的路径，不推荐。

4. **确认按钮行为**  
   - **决策**：`startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))`，必要时 `FLAG_ACTIVITY_NEW_TASK` 按上下文补全。若产品要求留在应用内，可改为 `WifiActivity`，需在实现/测试中明确一种并写死。

5. **弹窗与生命周期**  
   - **决策**：使用非阻塞 UI 线程的 `Dialog` / `AlertDialog`，在 `onDestroy` 中 dismiss，避免泄漏；从设置返回后在 `onResume` 再次评估连接状态并可能关闭弹窗或写入标记。

## Risks / Trade-offs

- **[Risk] 首次连接判定与「已验证网络」不一致** → **Mitigation**：规格与实现统一选用 `isWifiConnected` vs `isWifiAvailable`（含 `VALIDATED`），并在 spec 中写清。
- **[Risk] 多 Activity 重复弹窗** → **Mitigation**：单例标记 + 本次会话「已展示过」内存标志，或仅在单一宿主 Activity 触发。
- **[Risk] 工厂刷机/清数据后标记丢失** → **Mitigation**：符合「未初始化」语义，会再次提示；属可接受行为。

## Migration Plan

- 新装与升级：缺省视为「未完成初始化」，key 不存在即 false；无服务端迁移。
- 回滚：移除检查逻辑即可；preferences 中多余 key 可保留无害。

## Open Questions

- 弹窗是否提供「稍后」：不影响初始化标记；**已连 WiFi 或之后首次连上**即写入完成标记。
- 是否在仅以太网/无 WiFi 硬件设备上隐藏该流程：需产品确认（可在实现中通过 `PackageManager.hasSystemFeature(FEATURE_WIFI)` 兜底）。
