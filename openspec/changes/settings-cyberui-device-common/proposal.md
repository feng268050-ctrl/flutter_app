## Why

Device Information and Common Settings still use Material stand-ins (`Card` / `ListTile` / visible section headers) and a phone-style chevron-heavy Common Settings layout. Operators comparing with lws-ui (FrostUI) see missing Wi‑Fi connected-hotspot details, different Date & Time / Display & Sound interaction patterns, and an IP Camera page that exposes internal IP/URL/MediaMTX/retry chrome. CyberUI now covers the Frost controls needed for parity, and App gen-l10n is the string path (not lws-ui’s bilingual `values`/`values-zh`).

## What Changes

- Rebuild **Device Information** and **Common Settings** chrome with **CyberUI** (`CyberCard`, switches, segmented controls, capsule/volume sliders, buttons, dialogs) following lws-ui FrostUI composition — not Material settings stand-ins as the long-term look.
- Achieve **item/sub-page parity** with lws-ui’s Device Information and Common Settings (including Wi‑Fi Details + IP Settings). **Exclude** lws-ui’s 5×-tap hidden/debug affordances (env picker / ADB). Keep HMI-only extras already shipped (Bluetooth, LAN SSH debug, RGB LED, Mouse, Keyboard, USB OTG) unless they conflict with the Camera regroup.
- **Remove visible settings group section titles** on these surfaces (and related Common Settings / Device Information / Camera / Wi‑Fi chrome touched here). Group boundaries remain via separate cards; **code comments** may name groups (Network, Display & Sound, …) — UI MUST NOT show the label.
- Add a **Wi‑Fi connected-hotspot Details** page (and IP Settings entry) matching lws-ui fields/actions: IP mode / address / mask / gateway / DNS / signal / link speed / security / frequency / MAC; **IP Settings** + **Forget Network** (confirm). Replace the current bottom-sheet Disconnect/Forget shortcut as the primary details path.
- Restructure Camera settings:
  - Promote Camera out of Input into its **own card group**; rename operator label from **IP Camera** → **Camera**.
  - Sub-page rows: (1) **Status** (merged connection + MediaMTX phase — no separate MediaMTX rows; status value on the right); (2) **Camera Type**; (3) **Camera Version**.
  - **Do not** show Camera IP, Preview URL, MediaMTX detail rows, or a manual **Retry** control.
  - **Remove** Camera Type (and any Camera Version duplicate) from Device Information.
- Operator-visible strings for new/changed chrome use **`AppLocalizations`** / parent ARBs (`en-US` / `zh-CN` / `zh-TW` workflow). Do not regress to lws-ui bilingual-only language UX.

## Capabilities

### New Capabilities

- `wifi-connected-details`: Wi‑Fi Details + IP Settings sub-pages for the currently associated hotspot (lws-ui `WifiDetails` / `WifiIpSettings` parity on CyberUI + HAL link/IP prefs)

### Modified Capabilities

- `settings-ui`: CyberUI chrome for Device Information + Common Settings; hide group section titles; Common Settings interaction/layout parity with lws-ui; Camera as its own group (renamed); Device Information row set / OTA footer parity (minus secret taps); i18n via AppLocalizations
- `ip-camera`: Camera settings page content/behavior (Status merge, Type/Version rows, no IP/URL/retry/MediaMTX split); Device Information no longer duplicates Camera Type/Version

## Impact

- **App:** `device_information_tab.dart`, `common_settings_tab.dart`, `settings_chrome.dart` (CyberUI group/row primitives), Wi‑Fi pages (+ new details/IP settings pages), `ip_camera_settings_page.dart` (rename/routes), related tests
- **l10n:** parent ARB keys for Camera rename, Status, Camera Type/Version, Wi‑Fi Details fields/actions, Device Information labels still hardcoded; `make l10n`
- **HAL / packages:** reuse existing `WifiConnectionState` / `WlanIpv4Config` where possible; extend only if Details needs fields not yet exposed (link speed, MAC, security); Camera Version likely HTTP `deviceinfo` (or existing product session) — no MediaMTX UI retry surface
- **Out of scope:** Advanced Settings / Custom Home redesign; 5×-tap secret features; translating `cyber_ui` internals; full product OTA backend if none exists yet (UI affordances may wire to a stub/no-op with clear status until a dedicated OTA change)
