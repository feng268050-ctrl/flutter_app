## 1. CyberUI status icons

- [x] 1.1 Add `packages/cyber_ui/lib/src/icons/` with connectivity UI phase enum and camera link status type (`Cyber*` names)
- [x] 1.2 Port Wi‑Fi status icon + signal-bar painter from Home into CyberUI; render by phase (hidden / connecting / connected / onIdle) and optional `signalDbm`
- [x] 1.3 Port Bluetooth status icon into CyberUI; render by the same connectivity phase
- [x] 1.4 Port camera status icon + corner sync spinner into CyberUI; render by connecting / connected / failed
- [x] 1.5 Export icons from `package:cyber_ui` and add package tests covering each status visual

## 2. CyberUI status bars (extensible)

- [x] 2.1 Implement `CyberHomeStatusBar` as an ordered `items` (slot) list with shared gap/size tokens and a **transparent** background — MUST NOT be a fixed three-named-param-only API
- [x] 2.2 Implement compact minute-resolution status-bar clock widget in CyberUI
- [x] 2.3 Implement `CyberPageStatusBar` (`PreferredSizeWidget`): back + click sound + `onBack` callback, centered title, trailing `CyberHomeStatusBar` + clock; **Theme-adaptive background** with optional `backgroundColor` override; support `bottom` and optional actions without displacing status+clock
- [x] 2.4 Export status-bar widgets from `package:cyber_ui` and add package widget tests for item order, **more-than-three items**, transparent Home bar, page bar theme default + explicit background, page regions, back callback, and clock update

## 3. App binders (Home)

- [x] 3.1 Keep HAL/session → UI-phase mappers in the App; map into CyberUI status types
- [x] 3.2 Replace Home’s local strip/icons with `CyberHomeStatusBar(items: [wifi, bt, camera])` in the existing top-right overlay; remove feature-local status-bar forks
- [x] 3.3 Ensure camera status can be supplied from the product IP-camera session / `AppServices` (not only `HomePage` local state)
- [x] 3.4 Update Home status-bar tests for CyberUI strip adoption

## 4. App binders (Monitor / Settings)

- [x] 4.1 Switch `SettingsScaffold` to `CyberPageStatusBar` with App `onBack` + the same current three-icon `items` list
- [x] 4.2 Switch Settings shell (`SettingsPage`) to `CyberPageStatusBar` (keep tabs as `bottom`)
- [x] 4.3 Switch Monitor shell (`MonitorPage`) to `CyberPageStatusBar` (keep tabs as `bottom`)

## 5. Verification

- [x] 5.1 Add/adjust App widget tests for page status bar regions, Wi‑Fi hidden-when-off, and camera status without Home mounted
- [x] 5.2 Add/adjust tests proving Settings scaffold and Monitor/Settings shells use CyberUI page status bar
- [x] 5.3 Run `flutter analyze` / tests for `packages/cyber_ui` and relevant `app/hmi` chrome
