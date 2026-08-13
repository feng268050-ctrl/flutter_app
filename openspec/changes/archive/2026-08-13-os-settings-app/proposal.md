## Why

Platform system settings today live inside the product HMI (`app/lws_hmi`) Settings shell, mixed with welding-specific Advanced / Custom Home / cloud / peripheral pages. Operators and OEM work need a normal **OS Settings** app (`app/os_settings`, distinct from product HMI Settings) that shares OEM `board_profile` + `cyber_hal` without product gpio/modbus, installs beside `/opt/hmi` on the same rootfs, and replaces the abandoned Factory Test second-app slot — without a second flash path that risks wiping `/userdata`.

Canonical role policy: [`docs/settings-apps-roles.md`](../../../docs/settings-apps-roles.md). Plan detail: [`docs/os-settings-app-plan.md`](../../../docs/os-settings-app-plan.md).

## What Changes

- **Add** Flutter app `app/os_settings` → `/opt/os_settings` (non-HMI; Flutter **3.41.9** pin; path deps `cyber_hal` / `cyber_ui` / `cyber_ime` / shared settings chrome as needed).
- **Replace** rootfs auto-include / verify / docs convention `factory_test` → **`os_settings`**.
- **Add** board lifecycle: `os-settings-launch.sh`, static `os-settings.service` (no `WantedBy=multi-user`), `/usr/bin/os-settings` CLI, `switch-to-os-settings` / `switch-to-hmi`, bidirectional `Conflicts=` with `hmi.service`.
- **HMI entry:** Device Info → tap **Device SN 5×** → `switch-to-os-settings` (failure Toast, stay in HMI). OS Settings **Exit** → `switch-to-hmi`.
- **Ship** OS Settings IA as **multiple untitled frosted SettingsGroup cards**. Entry order:
  - Basic Info: About, Operating System, Storage
  - Network: Wi‑Fi, Ethernet, Bluetooth, Proxy, SSH, **Cloud Environment**
  - Date & Time
  - Locale: Country/Region, Language, Unit
  - Display & Sound: Display (**incl. UI Scale**), Sound (volume only), **Power Mode**
  - Input: Keyboard, Mouse, USB OTG  
  Same list→push layout landscape and portrait (no master-detail).
- **Copy** (HMI keeps shortcut): About identity reads, Wi‑Fi, Proxy, Date & Time, Country/Region, Language, Unit, Display (brightness / auto-sleep / wallpaper; **no** UI Scale in HMI), Sound (HMI keeps sound-effect picker).
- **Migrate** (OS Settings owns; remove HMI Settings entry): Ethernet, Bluetooth, SSH, Keyboard, Mouse, USB OTG, **Power Mode** (HAL `power.conf`; HMI still **reads** for continuous-paint).
- **OS-only factory/field:** **UI Scale** (`display.conf` `ui_scale`; **`1.0` = physical 1:1 / no rematch**), Cloud Environment tier (`/var/lib/network/cloud.conf`).
- **Ethernet UX:** Match Wi‑Fi Details — shared **IPv4 Address / DNS** groups (Automatic/Manual + inline IME); **cable link** under the interface switch; **MUST NOT** use a separate “Configure IP → DHCP/Manual nav” pattern.
- **Persistence:** Platform prefs use `/var/lib/hal/*` (and network/BT paths). OS Settings **MUST NOT** read/write `/var/lib/hmi/common-settings.json` (that file is HMI `textSize` only).
- **HMI Common IA (post-split):** Network → **Date & Time** → Locale (Country/Language/Unit) → **Display + Sound + Camera** (one card; **RGB LED row hidden**, code retained) → Misc. Power Mode / Input / Ethernet / BT / SSH absent.
- **Bluetooth** alias = `Brand + " " + Model`. **Operating System → Security** Secrets Seal read-only.
- **Do not** move Advanced / Custom Home / product cloud services / camera-as-business / peripheral OTA into OS Settings.
- **BREAKING** (build/docs): `factory_test` → `os_settings`.
- **BREAKING** (HMI Settings): drop migrated entries; regroup Common as above.

## Capabilities

### New Capabilities

- `os-settings-app`: Independent OS Settings Flutter app — multi-card untitled frost IA, platform pages (copy + migrate + OS-only), Exit, Bluetooth Brand+Model alias, Secrets Seal, Ethernet IPv4/DNS parity with Wi‑Fi Details, UI Scale semantics, Cloud Environment, no product gpio/modbus, no `common-settings.json`.
- `os-settings-app-lifecycle`: Overlay launchers, static `os-settings.service`, CLI safety (`--stop-hmi`), `switch-to-*`, HMI SN×5 entry / failure toast, mutual exclusion with `hmi.service`.

### Modified Capabilities

- `multi-app-build-select`: Auto-include / examples from `factory_test` → `os_settings`.
- `buildroot-lws-hmi-image`: Rootfs verify `/opt/os_settings`.
- `settings-ui`: HMI removes migrated rows; Common regroup (Date & Time before locale; Display+Sound+Camera; LED hidden; no Power Mode); OS Settings entry via Device SN 5×.
- `hmi-systemd-boot`: `Conflicts=` with `os-settings.service`.
- `dart-hal`: Platform versions / Secrets Seal; Ethernet DNS mode; `ui_scale` identity semantics via App `matchEmbedderDensity`.
- `linux-bluetooth`: Alias = Brand + space + Model.
- `p2-device-demo-ui`: Drop Demo/orphan routes for migrated features.
- `host-ota-publish`: `factory_test` wording → `os_settings`.

## Impact

- New: `app/os_settings/**`; overlay launch/unit/CLI/switch helpers; shared IPv4/DNS chrome as needed.
- Product App: SN×5 entry; remove migrated pages; Common IA regroup; retain `LoadProfile` read for paint policy; `textSize` stays in `common-settings.json`.
- Build: `APP=os_settings make build-app` / `push-app`; rootfs auto-includes when source exists.
- Docs SoT: `docs/settings-apps-roles.md`, `docs/os-settings-app-plan.md`.
