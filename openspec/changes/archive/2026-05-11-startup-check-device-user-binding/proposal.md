## Why

设备启动后当前没有自动确认绑定状态，导致未绑定设备在进入系统后没有明确引导，用户可能不知道需要先完成绑定才能继续使用相关云端能力。将绑定检查放在 WiFi 提醒/网络连接之后可确保网络可用时立即给出绑定动作指引，降低首次使用阻力。

## What Changes

- 在程序启动流程中，于“连接 WiFi 提醒对话框之后（若出现）”或“网络连接完成之后”触发设备绑定用户检查。
- 新增调用 `GET /v1/devices/:sn/users` 的启动期检查逻辑，按 `ApiResult` 解析响应。
- 约束用户列表数据模型为简化字段：`id`、`nickname`、`avatar` 和脱敏后的 `email`，仅用于启动期绑定判断和提示展示。
- 当用户列表为空时，弹出绑定提醒对话框：主标题与副标题使用可翻译字符串资源（`bind_device_dialog_title` / `bind_device_dialog_subtitle`，英文默认 + `values-zh` 中文），主体展示设备二维码；视觉风格复用现有 WiFi 提醒对话框模式。
- 二维码内容与 `Settings -> Device Information -> Machine Model` 中使用的二维码保持一致来源与格式。

## Capabilities

### New Capabilities
- `startup-device-user-binding-check`: 定义启动后联网条件满足时的设备用户绑定状态检查与无绑定提醒行为。

### Modified Capabilities
- `wifi-initialization-onboarding`: 启动联网引导完成后增加设备绑定状态检查触发点，扩展启动引导链路行为。

## Impact

- Android 启动流程相关 UI/状态编排逻辑（包含 WiFi 提醒对话框与网络状态回调衔接点）。
- 设备云 API 调用层新增或扩展 `GET /v1/devices/:sn/users` 调用与 `ApiResult` 解析。
- 设备用户信息数据结构（简化字段）与空列表判定逻辑。
- 新增或复用扫码绑定提示对话框组件，以及二维码内容复用逻辑（来自设备信息页机型二维码来源）。
