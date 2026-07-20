## 1. App skeleton and navigation

- [x] 1.1 Create `lib/app/` bootstrap (theme, `LwsHmiApp`) and feature folder layout `lib/features/{home,settings,demo}/{domain,application,presentation}/`
- [x] 1.2 Register named routes `/`, `/settings`, `/demo` with initial route `/` (zero-dep `routes` / `onGenerateRoute` unless nesting forces otherwise)
- [x] 1.3 Wire `main.dart` to load board profile, construct shared `BoardBindings` owner, and launch with product Home as initial route

## 2. Product Home

- [x] 2.1 Copy lws-ui Home assets (`home_back`, `home_left_400`, `home_right_400`) into `app/hmi/assets/home/` and declare them in `pubspec.yaml`
- [x] 2.2 Implement Home presentation: full-screen backdrop + dual animated overlays with non-fatal decode fallback
- [x] 2.3 Add Settings entry on Home that navigates to `/settings` (no Quick/Engineer/Monitor/AI/stat cards)

## 3. Settings shell

- [x] 3.1 Implement Settings shell with four Material tabs: Device Information, Common Settings, Advanced Settings, Custom Home Page
- [x] 3.2 Add Advanced Settings and Custom Home Page placeholder content with clear deferred messaging
- [x] 3.3 Implement Device Information tab using existing SN / sysinfo / Modbus version sources (missing → `-`)

## 4. Common Settings — platform sections

- [x] 4.1 Network: Wi‑Fi settings UI (reuse `ui/wifi/*` + `WifiController`) under Common Settings
- [x] 4.2 Network: HTTP Proxy settings UI wired to HTTP/proxy abstraction
- [x] 4.3 Network: Ethernet settings UI wired to `EthernetController`
- [x] 4.4 Network: Bluetooth settings UI (adapter, discoverable/pairable, A2DP, scan/pair/connect, challenges) wired to `BluetoothController` — DDD presentation/application, not a Demo section paste
- [x] 4.5 Display & Sound: brightness + volume sliders; stub rows for language/unit/screen-off/sound-effect where no store exists
- [x] 4.6 Date & Time group wired to `DateTimeController`
- [x] 4.7 Input: mouse settings + keyboard controls wired to existing HAL controllers
- [x] 4.8 Ensure Settings does not expose USB/LAN SSH debug toggles

## 5. Demo demotion

- [x] 5.1 Move Demo page under `features/demo` and bind it only to route `/demo`
- [x] 5.2 Remove Ethernet, Wi‑Fi, HTTP, Bluetooth, Date & Time, mouse, keyboard, backlight, and speaker/volume sections from Demo
- [x] 5.3 Keep device information, Alarm Information, RGB LED, and Debug (USB/LAN) on Demo; fix Debug placement independent of removed sections
- [x] 5.4 Ensure product Home has no primary Demo entry control

## 6. Verification

- [x] 6.1 Add/adjust widget or route tests: initial route is Home; `/settings` and `/demo` resolve; Settings shows four tabs and Bluetooth entry
- [x] 6.2 Run `flutter analyze` and relevant `app/hmi` / `cyber_hal` tests; fix regressions from route/bootstrap changes
- [x] 6.3 On-device smoke (when board available): Home assets + animation fallback; Settings Wi‑Fi/BT/brightness; Demo route still opens trimmed smoke UI
