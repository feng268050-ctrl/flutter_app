## Why

设备 OTA 更新目前仅能在「设备信息 → 检查并安装更新」中手动触发，用户容易错过新版本。增加「自动检查更新」复选框后，可在首次进入首页、完成设备注册状态确认后静默检查 manifest，有更新时主动提醒并一键进入升级页，降低运维成本且不打断无更新时的正常使用。

## What Changes

- 在设备信息页「检查并安装更新」按钮下方新增 **自动检查更新** 复选框（`FrostCheckbox`，样式与工程师模式提醒弹窗「不再显示」一致），默认未勾选；状态持久化到本地偏好。
- 勾选「自动检查更新」后，在 **本进程首次进入首页**（`MainActivity`）且 **开机自检完成** 后，经 `HomePromptQueue` 在 **设备绑定/注册检查**（`BindDeviceHomePrompt`）之后执行 OTA manifest 检查。
- 检查逻辑复用 `OtaUpdateManifestService.checkAgainst` 与现有 semver 规则；**无更新、检查失败、API base 未 pin** 时 **不弹窗**（静默跳过）。
- 有可用更新时，经 `AutoDialogQueue` 弹出 `FrostDialog` 确认框：标题与正文为固定本地化文案（含远程 `version`）；确认按钮为 Title Case **Go to Update**（中文「前往更新」）。
- 手动「检查并安装更新」按钮行为不变（含 10 秒防连点、检查中等待对话框、已是最新/失败提示）。

## Capabilities

### New Capabilities

- `auto-check-ota-update`: 设备信息页自动检查复选框的 UI、持久化、首页首次自动检查时机、静默失败语义、有更新时的确认弹窗与跳转 `UpgradeActivity` 时复用检查结果。

### Modified Capabilities

- `lws-app-ota-semver`: 补充「自动检查」入口的 normative 要求——与手动检查共用 manifest 获取与 semver 判定；自动路径在首页 prompt 队列中运行且成功命中更新时 SHALL 将 manifest 结果传递给升级页而非二次请求。

## Impact

- **UI**: `fragment_device_information.xml`（Checkbox）、`DeviceInformationFragment`（读写偏好）；字符串资源 `values` / `values-en` / `values-zh`。
- **首页编排**: `HomePromptQueue` / `HomePrompts`（新 `AutoOtaUpdateHomePrompt`，order 在 `BindDeviceHomePrompt` 之后）；`AutoDialogQueue` 排队展示。
- **OTA**: 复用 `OtaUpdateManifestService`、`UpgradeActivity` Intent extras；可抽取共享的「manifest → UpgradeActivity」导航辅助方法供手动/自动路径共用。
- **偏好**: 新 `AutoCheckOtaUpdateSettings`（或等价 SharedPreferences 封装），默认 `false`。
- **测试**: 单元测试覆盖偏好默认值、prompt 资格（未勾选/已勾选、非首次首页、绑定检查未完成）、有更新时 Intent extras 传递。
