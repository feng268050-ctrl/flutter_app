## 1. Settings chrome (CyberUI, no group titles)

- [x] 1.1 Evolve `settings_chrome.dart` group shell from Material `Card` to CyberUI (`CyberCard` / shared wrapper); keep nav/value/switch row helpers with Cyber tokens + click sound
- [x] 1.2 Remove visible `SettingsSectionHeader` usage from Device Information, Common Settings, Wi‑Fi, and Camera pages; retain group names as Dart comments only
- [x] 1.3 Add any missing inline row helpers needed for segmented / capsule / volume controls on Common Settings

## 2. Device Information CyberUI + lws-ui row set

- [x] 2.1 Rebuild `device_information_tab.dart` with untitled CyberUI cards: Identity (Model+QR, SN, Welding Gun SN), Versions (System, Process Library when available, Firmware/control-card, Laser, Wire Feeder; keep Kernel / Display Stack if retained), Focus (Focus Scale Reference only)
- [x] 2.2 Remove Camera Type (and any Camera Version) from Device Information
- [x] 2.3 Wire Process Library Version from process-library meta when available; map Firmware label to existing Modbus control-card value unless a distinct register exists
- [x] 2.4 Add Check for Updates + Automatically check for updates footer; unavailable/deferred dialog if OTA client missing
- [x] 2.5 Localize remaining hardcoded Device Information strings via AppLocalizations; do **not** implement 5×-tap secrets

## 3. Common Settings CyberUI + lws-ui interaction parity

- [x] 3.1 Rebuild `common_settings_tab.dart` untitled cards: Network (Wi‑Fi, HTTP Proxy, LAN SSH, Bluetooth), Display & Sound inline Cyber controls, RGB LED card after Display & Sound, Date & Time Automatic + conditional rows, Input (Mouse / Keyboard / USB OTG), Camera (own card), Misc switches
- [x] 3.2 Inline Language (3 locales), Unit, Brightness, Screen Off, Volume, Sound Effects with CyberUI; keep store/HAL bindings; avoid bilingual-only Language UX
- [x] 3.3 Fold Date & Time Automatic / Set Date / Set Time / Set Time Zone (+ status line) onto Common Settings using `DateTimeController` + Cyber dialogs; trim or repurpose `DateTimeSettingsPage` as needed
- [x] 3.4 Move Camera out of Input into its own group; rename operator label to Camera (ARB)

## 4. Wi‑Fi Details + IP Settings

- [x] 4.1 Extend HAL Wi‑Fi link exposure if Details needs missing fields (link speed, MAC, security); show Unavailable/`-` until populated
- [x] 4.2 Add `WifiDetailsPage` with lws-ui field set + IP Settings / Forget Network (Cyber confirm); wire connected SSID row to push Details (replace bottom-sheet primary path)
- [x] 4.3 Add `WifiIpSettingsPage` (DHCP/Static segmented + CyberIME field editors + Apply via existing wlan IPv4 HAL)
- [x] 4.4 Remove visible Wi‑Fi page section headers (“WLAN” / “NETWORKS”); keep CyberUI chrome consistency

## 5. Camera settings page reshape

- [x] 5.1 Rewrite Camera settings rows: Status (merged connection + MediaMTX/relay), Camera Type, Camera Version; remove IP, Preview URL, MediaMTX, MediaMTX detail, and Retry
- [x] 5.2 Implement Camera Version fetch/cache (deviceinfo `appVersion` or product helper) with `-` fallback; keep preview + demo Record below
- [x] 5.3 Update page title / navigation to Camera; adjust tests that assert IP Camera / Retry / URL rows

## 6. l10n + verification

- [x] 6.1 Add/update parent ARB keys (Camera rename, Status, Camera Type/Version, Device Information / Wi‑Fi Details gaps); run `make l10n`
- [x] 6.2 Update widget/store tests for Device Information (no Camera Type), Common Settings (no section headers, Camera group), Wi‑Fi Details navigation, Camera Status rows
- [x] 6.3 Run `flutter analyze` (pinned SDK) under `app/hmi/` and targeted tests; device smoke via `make build-app` / `make push-app`
