## Context

lws-ui Device Information / Common Settings use FrostUI cards with **untitled** Device Info groups and **titled** Common Settings groups; HMI today uses Material `SettingsSectionHeader` + `Card`/`ListTile` chrome and mostly chevron sub-pages. CyberUI already provides Frost successors (`CyberCard`, `CyberSwitch`, `CyberSegmentedControl`, `CyberCapsuleSlider`, `CyberVolumeSlider`, `CyberButton`, `CyberDialog`). App gen-l10n (`AppLocalizations`, `en-US`/`zh-CN`/`zh-TW`) is the string path after `hmi-ui-i18n`. Wi‑Fi HAL already exposes rich `WifiConnectionState` + `WlanIpv4Config`; the UI still opens a bottom sheet instead of a Details page. Camera Type sits on Device Information while the IP Camera page still shows IP/URL/MediaMTX/Retry.

## Goals / Non-Goals

**Goals:**

- CyberUI card/row chrome for Device Information + Common Settings (and touched Wi‑Fi / Camera sub-pages).
- lws-ui item/sub-page parity for those two tabs (plus Wi‑Fi Details / IP Settings), excluding 5×-tap secrets.
- No visible group section titles; comments only.
- Camera as its own Common Settings group; lean Status / Type / Version page; dedupe Device Information.
- Keep HMI-only extras (Bluetooth, LAN SSH, RGB LED, Mouse, Keyboard, USB OTG, Misc overlays).
- All new/changed operator strings via AppLocalizations (3 locales), not bilingual-only UX.

**Non-Goals:**

- Advanced Settings / Custom Home redesign.
- Porting lws-ui secret taps.
- Full product OTA download/apply pipeline if not already present (UI may call a thin check API or show deferred status).
- Removing HMI-only Network/Input rows to match lws-ui’s smaller inventory.
- Changing portable `IpCameraController` topology contracts beyond Settings presentation / version read helpers.

## Decisions

### 1. Evolve `settings_chrome` onto CyberUI cards; drop visible section headers

Replace Material `Card` group shell with `CyberCard` (or shared Settings group wrapper around it). Keep row helpers (`SettingsNavRow`, `SettingsValueRow`, `SettingsSwitchRow`, new inline control rows) but restyle for Cyber tokens / click sound. **`SettingsSectionHeader` MUST NOT render operator-visible titles** on Device Information, Common Settings, Camera, or Wi‑Fi pages touched by this change — delete call sites; optionally keep the widget as a no-op deprecated helper or remove it. Group intent stays in **Dart comments** above each `SettingsGroup` / `CyberCard`.

**Alternatives:** Keep uppercase headers “for accessibility” — rejected (explicit product request). Use invisible semantics-only headers — optional later; not required for v1.

### 2. Common Settings interaction model: inline Cyber controls where lws-ui is inline

| Concern | Approach |
|---------|----------|
| Language | Keep **3** locales (`en-US` / `zh-CN` / `zh-TW`). Prefer `CyberSegmentedControl` (or equivalent) on the Common Settings card when layout fits 1280×800; otherwise CyberUI Language sub-page. **Do not** shrink to lws-ui’s EN/ZH-only segmented control. |
| Unit | Inline `CyberSegmentedControl` (IN / MM) bound to `CommonSettingsStore`. |
| Brightness | Inline `CyberCapsuleSlider` → HAL `Backlight`. |
| Auto Screen Off | Inline segmented options → HAL `AutoSleep` (same policy set as today). |
| Volume | Inline `CyberVolumeSlider` → media audio. |
| Sound Effects | Inline segmented Effect 1/2/3 → `ButtonFeedback` / sound-effect store. |
| Date & Time | lws-ui-like: **Automatic** `CyberSwitch` + Set Date / Set Time / Set Time Zone rows (dialogs) + sync status line; may absorb most of `DateTimeSettingsPage` into the tab (sub-page retained only if needed for overflow). |
| Network / Input / Misc / LED / Camera | Keep nav rows + existing sub-pages; Camera moved out of Input. |

RGB LED stays a **separate card after** Display & Sound controls (existing order rule), without a visible “Display & Sound” title.

**Alternatives:** Keep all Display & Sound as chevron pages — rejected for Frost parity. Force 2-option Language — rejected by i18n requirement.

### 3. Device Information row set and chrome

Untitled CyberUI cards (comments: Identity / Versions / Platform or Focus):

1. **Identity:** Model (+ QR), Device SN, Welding Gun SN (localize; alias of current Gunhead SN data).
2. **Versions:** System Version; Process Library Version (from process-library meta when available); Firmware / Control Card Version (map existing Modbus control-card field to the lws-ui “Firmware Version” label unless a distinct firmware register exists); Laser; Wire Feeder. **Omit Camera Version** here (lives under Camera). Keep Kernel Version and Display Stack as HMI-only rows if still useful — place in Versions / Platform cards without duplicating Camera Type.
3. **Focus:** Focus Scale Reference only (Camera Type removed).

Footer (lws-ui parity): **Check for Updates** + **Automatically check for updates** checkbox. If product OTA client is not ready, wire to a documented no-op / “Unavailable” status dialog — do not invent a full OTA stack in this change.

**Exclude:** 5×-tap env picker and ADB enable.

### 4. Wi‑Fi Details + IP Settings

New pages under settings presentation:

- **WifiDetailsPage** — entry from connected SSID row (and connected scan row if applicable). Fields: IP Mode, IP Address, Subnet Mask (from prefix), Gateway, DNS, Signal Strength, Link Speed (extend HAL if missing), Security (from AP capabilities / profile), Frequency, MAC Address (extend HAL if missing). Actions: **IP Settings**, **Forget Network** (Cyber confirm dialog).
- **WifiIpSettingsPage** — DHCP vs Static segmented control; edit static fields via CyberIME dialogs; Apply writes `WlanIpv4Config` / existing HAL apply path.

Replace the connected-row bottom sheet as the primary details UX. Disconnect may remain available only if lws-ui parity needs it; Details+Forget is the required path.

### 5. Camera group + page reshape

- Common Settings: **Camera** nav row in its **own** card group (not under Input). Title key becomes Camera (ARB); route may keep file name `ip_camera_settings_page.dart` or rename for clarity.
- Page body rows (before preview/demo record):
  1. **Status** — single value combining product UI phase and MediaMTX/relay readiness (e.g. Connected / Establishing / Failed / Relay …). No separate MediaMTX / MediaMTX detail rows. **No Retry button**; background session retry policy unchanged.
  2. **Camera Type** — same `product.ini` mapping as today’s Device Information.
  3. **Camera Version** — fetch/display camera app version (lws-ui-style `GET …/System/deviceinfo` → `appVersion`, or existing product helper); `-` when unavailable.
- Preview + demo Record remain below (existing `ip-camera` requirements), without showing IP or Preview URL text.
- Device Information **MUST NOT** show Camera Type or Camera Version.

### 6. i18n

Add/adjust parent ARB keys (`cameraText`/`ipCameraText` → Camera, `cameraType`, `cameraVersion`, Status labels, Wi‑Fi Details strings already partly present). Run `make l10n`. No bilingual-only Language UX.

## Risks / Trade-offs

- **[Risk] Inline Display & Sound crowds the Common Settings scroll on 800px height** → Mitigation: keep compact Cyber row heights; allow Language overflow to a sub-page if 3-segment control clips.
- **[Risk] Link speed / MAC / security not on `WifiConnectionState` today** → Mitigation: extend Linux Wi‑Fi session parsers in the same change; show `-` / Unavailable until populated.
- **[Risk] Camera Version HTTP competes with health probe policy** → Mitigation: bounded, cached, non-SETUP GET (same as lws-ui); never use as sole connectivity probe.
- **[Risk] OTA footer without backend confuses operators** → Mitigation: clear unavailable/deferred dialog; no fake success.
- **[Trade-off] HMI keeps more Network/Input rows than lws-ui** → Accept; parity is “lws-ui ⊆ HMI”, not equality.

## Migration Plan

1. Chrome primitives + remove section headers on Device Info / Common Settings.
2. Inline Display & Sound + Date & Time reshaping; keep stores/HAL bindings.
3. Wi‑Fi Details + IP Settings pages; wire connected row.
4. Camera group move + page row rewrite; Device Information dedupe.
5. ARB + `make l10n`; analyze/tests; device smoke (`build-app` / `push-app`).

Rollback: revert App settings presentation commits; HAL field additions are additive.

## Open Questions

- Exact mapping label: keep “Control Card Version” vs rename to “Firmware Version” when only one Modbus field exists — default to lws-ui **Firmware Version** label on the existing control-card value unless product confirms a distinct register.
- Whether Kernel Version / Display Stack remain after parity trim — default **keep** as HMI-only (no Camera Type).
- OTA check API availability on board — confirm during apply; otherwise deferred status UI.
