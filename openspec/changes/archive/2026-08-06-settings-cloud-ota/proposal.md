## Why

`make publish` and the on-device download → verify → extract → apply path already work (host `make upgrade`). Cloud channel JSON parsing and coordinator wiring are in progress, but Settings still embeds Check for Updates / auto-check as a Device Information footer, and the full-screen upgrade progress page is a minimal Material scaffold that does not match CyberUI Settings / product chrome. Operators need an **lws-ui–shaped OTA Settings sub-page** plus a **system-aligned upgrade progress page** so cloud check-and-download feels like the rest of the HMI.

## What Changes

- Keep `cyber_ota` accepting published channel manifests (`url` / `package_url`) and the cloud download → verify → apply pipeline via `SystemOtaCoordinator`.
- **Add a dedicated Settings OTA sub-page** (lws-ui `DeviceInformation` check + `UpgradeActivity` idle UX, HMI vocabulary): `SettingsScaffold` + CyberUI untitled cards — current system version, **Check for Updates**, **Automatically check for updates**, and when a newer channel exists show version / optional notes with **Update Now** (and dismiss / later). Device Information **navigates into** this sub-page instead of hosting the OTA footer controls inline.
- **Redesign the dedicated system upgrade progress page** to use product design elements (CyberUI page status bar / fill tokens, Settings/Cyber card or panel chrome, `HmiButton` / Cyber progress patterns, phase labels already used for download/verify/extract/burn). Host `make upgrade` and cloud/WS sessions share this page. No laser/job controls; non-cancelable during write.
- Auto-check: prompt toward the OTA sub-page / Update Now gate; never auto-apply.
- WS `command.check_update` / `command.update_system` stay on the same manifest adapter; update_system still safe-shuts down onto the redesigned upgrade progress page.
- Host tests + smoke checklist (Settings OTA sub-page → Update Now → progress page).
- **Non-goals:** reworking `make publish`, host SSH package layout, RockUSB/`flash`, A/B apply internals, or Ed25519 trust (`.sig` remains the write gate). Do not require publish to add `title`/`content` (optional if present; otherwise version-based copy).

## Capabilities

### New Capabilities

<!-- None — extends existing Settings / OTA UI capabilities. -->

### Modified Capabilities

- `cyber-ota`: Accept host-published channel manifest field `url` as the archive location (alias of `package_url`); document `.sig` discovery against that URL.
- `ota-upgrade-ui`: Dedicated **Settings OTA sub-page** for check / auto-check / Update Now; dedicated **upgrade progress page** restyled to CyberUI / product chrome; both drive `cyber_ota` cloud (and host) sessions.
- `settings-ui`: Device Information exposes a navigation entry to the OTA sub-page (not an inline OTA footer); sub-page uses shared Settings scaffold / CyberUI cards.
- `device-cloud-websocket`: `command.check_update` / `command.update_system` consume the same channel-manifest adapter; apply UI is the redesigned upgrade progress page.

## Impact

- **`packages/cyber_ota`:** Channel JSON parse (already landed / in this change).
- **`app/lws_hmi`:** New OTA Settings page under `features/system_ota` or `features/settings/presentation/pages/`; Device Information row + `pushSettingsPage`; restyle `SystemUpgradePage`; coordinator navigation unchanged in role.
- **Cloud contract:** unchanged (`/view/…/staging|release.json`, package from `url` + `.sig`).
- **Docs / AGENTS:** `make build-app` + `make push-app`; update smoke for sub-page path.
