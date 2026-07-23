## Context

- **手动 OTA 检查** 已在 `DeviceInformationFragment#checkUpgrade` 实现：10 秒防连点 → 等待对话框 → 后台 `OtaUpdateManifestService.checkAgainst(BuildConfig.VERSION_NAME)` → 有更新则带 Intent extras 打开 `UpgradeActivity`。
- **首页启动提示** 由 `HomePromptQueue` 编排，经 `AutoDialogQueue` 串行展示；现有 prompt 顺序为 WiFi 初始化 (10) → 远程锁 (20) → 内置固件 (40) → 设备绑定/注册 (50)。`BindDeviceHomePrompt` 在 WiFi 可用时异步调用 `DeviceWorkerUsersClient.fetchDeviceUsers`，无绑定用户时弹 QR 绑定对话框。
- **用户诉求**：在设备信息页增加「自动检查更新」复选框；勾选后于 **首次进入首页**、**绑定检查之后** 自动执行与手动检查相同的 manifest 拉取与 semver 比较；有更新时弹确认框（确认按钮「前往更新」），跳转升级页并 **复用已获取的 manifest**，避免二次网络请求。

## Goals / Non-Goals

**Goals:**

- 设备信息页「检查并安装更新」按钮下方展示 `FrostCheckbox`（`@style/FrostCheckbox`，标签「自动检查更新」，布局与工程师模式激光开启提醒弹窗的「不再显示」选项一致），默认未勾选。
- 勾选状态持久化（进程重启后保留）。
- 已勾选时，本进程 **仅首次** `MainActivity` 首页 resume（且 boot self-check 已完成）触发一次自动检查；在 `HomePromptQueue` 中排在 `BindDeviceHomePrompt`（order 50）**之后**（建议 order **60**）。
- 自动检查在后台线程执行；无更新、网络/manifest 失败、API base 未 pin 时 **静默**，不打扰用户。
- 有更新时通过 `FrostDialog` 展示固定本地化标题/正文（正文含远程版本号）；确认按钮 Title Case「Go to Update」/「前往更新」，取消「Cancel」/「取消」。
- 确认后 `startActivity(UpgradeActivity)`，extras 与手动路径一致（`title`、`content`、`version`、`downloadUrl`、`sha512`、可选 `info`），不再次调用 `checkAgainst`。
- 抽取共享导航辅助（如 `OtaUpgradeNavigation`）供 `DeviceInformationFragment` 与 `AutoOtaUpdateHomePrompt` 共用。

**Non-Goals:**

- 不改变手动「检查并安装更新」的防连点、等待对话框、「已是最新」/失败提示行为。
- 不在每次回到首页重复自动检查（仅本进程首次首页）。
- 不在无 WiFi / API base 未 pin 时弹错误框（自动路径静默）。
- 不自动下载或安装；用户须在 `UpgradeActivity` 内确认「立即升级」。
- 不替代 WS `command.check_update` 远程检查通道。

## Decisions

### 1. 设置 UI：按钮下方 Checkbox

在 `fragment_device_information.xml` 中，于 `btn_check_update` 下方增加居中的 `FrostCheckboxView`（`@style/FrostCheckbox`，`app:labelText="@string/auto_check_ota_update"`），视觉与 `dialog_frost_action_laser_enable_reminder.xml` 中 `important_reminder_check_box` 一致。

**理由**：用户要求与工程师模式提醒弹窗「不再显示」选项同款 Checkbox，而非设置页 Switch 行。

**备选**：`InsetListRow` + `FrostSwitchView` — 已按反馈弃用。

### 2. 偏好存储：`AutoCheckOtaUpdateSettings`

新建轻量 SharedPreferences 封装（模式参考 `BootSelfCheckSettings` / `DeviceRemoteLockStore`）：

- Key: `auto_check_ota_update_enabled`
- 默认: `false`
- 读写 API: `isEnabled(Context)` / `setEnabled(Context, boolean)`

Fragment `initView` 绑定 checkbox 初始勾选状态；`OnCheckedChangeListener` 持久化。

### 3. 首页编排：新 `AutoOtaUpdateHomePrompt`（order 60）

注册到 `HomePromptQueue.PROMPTS`，位于 `BindDeviceHomePrompt` 之后。

**资格 (`isEligible`)**：

- `AutoCheckOtaUpdateSettings.isEnabled()`
- `HomePromptQueue.isFirstHomeResumeSeen()` 为 true（与 WiFi 初始化 prompt 共用「首次首页」语义；自动检查在 bind prompt 之后，故首次首页时 bind 已先完成或跳过）
- 本 prompt 本会话尚未消费（`markConsumedForSession` 或 `consumedSessionIds`）
- WiFi 可用且 `AppRuntimeEnvironment.isWifiInitializationCompleted()`（与 bind 检查前置一致）
- `BindDeviceHomePrompt` 的 prepare 已结束且 **不需要** 绑定提示（`prepareState == SKIP`），或用户已 dismiss 绑定对话框 — 实现上可在 `prepare()` 中等待 bind prompt 的 prepare 完成并读取同一 `DeviceWorkerUsersClient` 结果，避免重复请求

**`prepare()`**：后台线程调用 `OtaUpdateManifestService.checkAgainst`；结果缓存在 prompt 实例：

- `hasUpdate` + `ManifestData` → `NEED_PROMPT`
- 无更新 / 异常 / 无 pin → `SKIP`（静默）

**`show()`**：`FrostDialog.prompt(activity)`：

- `title`: `@string/auto_ota_update_dialog_title`（**New Version Available** / **新版本可用**）
- `message`: `@string/auto_ota_update_dialog_message`（`SemanticVersionHelper.toCoreVersion(manifest.version)` 去 `-alpha`/`-beta` 等后缀后填入，与 `UpgradeActivity` 标题一致）
- `confirmText`: `@string/go_to_update`（**Go to Update** / **前往更新**）
- `cancelText`: `@string/cancel_text`（**Cancel** / **取消**）
- 确认 → `OtaUpgradeNavigation.startUpgradeActivity(activity, manifest, deviceInfo)` → `onComplete`
- 取消 → `onComplete`（本会话不再提示同一检查结果）

经 `AutoDialogQueue.enqueueFrostDialog` 展示，与其他 home prompt 一致。

**理由**：复用现有首页对话框队列，保证与 WiFi / 绑定 / 内置固件提示不重叠抢焦点；排在 bind 之后满足「注册检查之后」。

**备选**：在 `MainActivity.onResume` 直接调用 — 会与 `HomePromptQueue` 重复且难保证顺序，不采用。

### 4. 复用检查结果：缓存 manifest + 共享导航

`prepare()` 阶段已完成网络请求；`show()` 确认时仅组装 Intent：

```java
// OtaUpgradeNavigation — 伪代码
static void startUpgradeActivity(Context ctx, ManifestData m, @Nullable DeviceInfo info) {
    Intent i = new Intent(ctx, UpgradeActivity.class);
    i.putExtra("title", ...);
    i.putExtra("content", ...);
    i.putExtra("version", m.version);
    i.putExtra("downloadUrl", m.url);
  // sha512, info — 与 DeviceInformationFragment#checkUpgrade 一致
    ctx.startActivity(i);
}
```

手动 `checkUpgrade()` 在成功分支改为调用同一 helper。

### 5. 静默失败语义

自动路径 **不** 使用 `GlobalDialogUtil.showStatusDialog` 展示「已是最新」「检查失败」「请等待 10 秒」。仅 `Log` 记录失败原因。

手动路径保持原有 UX。

### 6. 会话范围

每个 app 进程生命周期内，自动检查 **最多执行一次**（无论结果是否有更新）。用户关闭「有更新」对话框后本会话不再自动检查；下次冷启动若仍勾选且仍为「首次首页」流程，可再检查。

不在 `onHomePause` 重置（与 bind prompt 的 dismiss 语义不同）；仅进程重启后重新 eligible。

## Risks / Trade-offs

- **[Risk] API base 未 pin 时自动检查永远静默** → 与手动检查相同前置条件；运维需保证 Worker origin 探测成功。可接受。
- **[Risk] 与 `BindDeviceHomePrompt` 重复请求 `fetchDeviceUsers`** → `AutoOtaUpdateHomePrompt.prepare` 复用 bind prompt 已完成的 prepare 状态，或抽取共享 `DeviceRegistrationProbe`；实现时注意不 double-fetch。
- **[Risk] 首页 prompt 链过长延迟 OTA 提醒** → order 60 仅在开关开启且有更新时出现；无更新零 UI 成本。
- **[Trade-off] 仅首次首页检查** → 用户长时间不重启可能错过当日发布的新版本；可依靠手动检查或后续增强「每日一次」策略（本期不做）。

## Migration Plan

1. 发布 APK；新复选框默认未勾选，现有用户行为不变。
2. 用户主动开启后下次冷启动进入首页生效。
3. 回滚：取消勾选或还原代码；无服务端/数据库迁移。

## Open Questions

- 无。产品已明确：默认关、首次首页、bind 之后、有更新才弹窗、确认进升级页且复用结果。
