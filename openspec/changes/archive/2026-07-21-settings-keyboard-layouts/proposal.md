## Why

Settings → Keyboard 仍是 Demo 级 HID 探测 + US/RU 切换，缺少面向产品的多语种布局选择与预览。外接 USB/BT 物理键盘若 XKB 规格与实体键位不一致，部分符号/字母键会“失灵”；同时 CyberIME 虚拟键盘需要展示与所选规格一致的打字区（无 F 键、无右侧小键盘），方便操作员确认布局。

## What Changes

- 在 **Common Settings → Keyboard** 提供四选一布局规格，用 **`CyberSegmentedControl`** 切换，并展示对应**打字区预览**（typewriter block only：无 Function 行、无 9 键/数字小键盘）。
- 四规格（产品枚举）：
  1. **美规 ANSI** — US QWERTY（ANSI Enter）
  2. **德规 QWERTZ** — ISO 德语（ISO Enter / 额外键）
  3. **法规 AZERTY** — 法语 ISO（含 AltGr 第三层字符映射需求）
  4. **日规 JIS** — Japanese Industrial Standard（半角/全角、無変換/変換等日文专用键在物理 XKB 侧；虚拟预览以打字区为主）
- **虚拟键盘（CyberIME）**：默认继续走项目内 CyberIME；Keyboard A 字母/符号层按所选规格排列；仍不含 F 键与右侧数字小键盘；Keyboard B（专用数字垫）不变。
- **物理键盘**：布局经现有 HAL `Keyboard.setLayout` → XKB（`/var/lib/hmi/keyboard.conf`）；操作员必须选择与实体键盘一致的规格，否则部分键位不生效（产品文案明示）。v1 仍可按现有契约在 apply 后重启 `hmi.service` 并恢复路由。
- HAL `listLayouts` 产品集扩展为至少 `us` / `de` / `fr` / `jp`（显示名对齐四规格）；Demo 用的 `ru` 可保留在 HAL 列表但不出现在产品 Segment，或移出产品页。
- 软硬布局共用同一产品枚举偏好（一处选择，同时驱动 CyberIME 预览/键帽与物理 XKB）。

## Capabilities

### New Capabilities

- `product-keyboard-layouts`: 四规格产品模型、Settings Segment + 预览、与 CyberIME / 物理 XKB 的绑定契约及操作员提示。

### Modified Capabilities

- `settings-ui`: Keyboard 页从 Demo 嵌入升级为产品布局选择 + 预览（可保留连接探测作为次要信息）。
- `cyber-ime`: Keyboard A 支持按规格切换字母/符号布局（ANSI / QWERTZ / AZERTY / JIS 打字区）；仍排除 F 键与右侧小键盘。
- `dart-hal`: 物理键盘布局列表与四规格对齐（XKB id / model / variant 映射）；产品不得用 Dart 重映射 HID scancode 替代 XKB。

## Impact

- **App:** `keyboard_settings_page.dart`、偏好存储/恢复；可选从 Demo section 抽离产品 UI。
- **cyber_ime:** 多布局定义 + 语言/规格 provider；预览可用只读 panel。
- **cyber_hal:** `LinuxKeyboard.listLayouts` 与 persist 映射（`us`/`de`/`fr`/`jp`，JIS 可能需 `jp` + model `jp106`）。
- **cyber_ui:** 复用已有 `CyberSegmentedControl`；无需新控件包。
- **Out of scope:** 完整日文假名/汉字候选引擎；系统 OEM IME；为虚拟键盘添加 F1–F12 或 100% 数字小键盘；热切换 XKB 而不重启 HMI（仍按 dart-hal v1）。
