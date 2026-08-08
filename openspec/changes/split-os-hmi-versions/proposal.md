## Why

Today a single “System Version” (Flutter `pubspec` / `kSystemVersion`) represents both the product identity and the whole-device OTA channel, while `/opt/hmi` can already be hot-swapped unsigned via `make push-app`. Operators need independent OS (rootfs) and HMI (app) versioning so the app can be packaged, signed, published, and upgraded on the same secure path as control-board / camera firmware—without forcing a full A/B rootfs burn for every app change.

## What Changes

- **BREAKING**: Split “System Version” into **OS Version** (stamped in rootfs) and **HMI Version** (Flutter app `pubspec` / Dart constants). First OS Version is **1.0.0**.
- Whole-device / A/B cloud OTA and Settings “OS” identity gate on **OS Version**, not HMI app semver.
- HMI app remains baked into `build-rootfs` / factory images, but is also packable as a signed **`tar.gz`** for independent release under CDN **`lws-hmi/app/`** (+ sibling `.sig` + `release.json`).
- New **HMI Upgrade** Settings page: shows **HMI Version** + **Process Library Version**; check / download / verify / apply uses the shared upgrade UX and Ed25519 path; apply installs into `/opt/hmi` and **restarts `hmi.service`** (no A/B slot flip).
- **HMI cloud check only** — no “bundled HMI version” / newest-wins-vs-assets (unlike control-board / camera).
- Host: **`make upgrade-app`** is the signed remote app update (sign package, ephemeral host HTTP, device `download <url>`, verify, install, restart). **`make push-app`** SHALL be a Make **alias** of `upgrade-app` (same signed path; no unsigned SCP/hot-swap retained).
- Host: **`make version` / `version-bump` default to OS Version**; only with **`APP=`** do they operate on the Flutter app version (no `HMI=` alias).
- Host publish: add **`make publish-app`** mirroring peripheral firmware publish into `lws-hmi/app/`.

## Capabilities

### New Capabilities

- `os-version`: Product OS Version stamp in rootfs (initial **1.0.0**), read/display APIs, and default target for host version tooling.
- `hmi-app-cloud-ota`: Device-side HMI app channel — cloud `release.json` check, signed `tar.gz` fetch/verify, install to `/opt/hmi`, restart `hmi.service`; HMI Upgrade UI (HMI + Process Library versions).
- `host-app-upgrade`: Host `make upgrade-app` signed HTTP + device download/install path; **`push-app` is an alias of `upgrade-app`** (unsigned push removed).
- `host-app-publish`: Package/sign/publish app `tar.gz` + `.sig` + `release.json` under CDN `lws-hmi/app/`.

### Modified Capabilities

- `host-app-version`: Default `make version` / `version-bump` to OS Version; `APP=` selects Flutter app version (`kHmiVersion` / pubspec); retire “System Version” as the sole product version.
- `host-ota-publish`: Whole-device / system cloud channel version comes from **OS Version**, not HMI pubspec.
- `ota-upgrade-ui`: Device Info and upgrade pages show OS vs HMI separately; System/OS Upgrade no longer owns Process Library; HMI Upgrade owns HMI + Process Library.
- `settings-ui`: Device Information version rows / navigation for OS Version and HMI Version.
- `host-push-hmi`: **`make push-app` becomes an alias of `make upgrade-app`**; remove the unsigned SCP bulk-transfer path.
- `cyber-ota` / `host-remote-upgrade`: Clarify whole-device OTA is OS-scoped; app-only updates are out of the A/B package path (orthogonal channel).

## Impact

- **Rootfs / overlay**: New OS version file (or equivalent) baked by `build-rootfs` / apply-overlay; HAL or App sys-info reads it.
- **Flutter App**: Rename/split version constants; Device Info + System/OS Upgrade + new HMI Upgrade page; command watcher under `/run/hmi/upgrade-app.cmd`; install/restart helper (evolve former push-app apply script behind verify).
- **Host scripts / Makefile**: `app-version.sh` dual-target; `upgrade-app.sh`; `push-app` → alias; package + publish scripts; docs (`README`, `docs/make-commands.md`, `AGENTS.md` rebuild table).
- **Cloud / CDN**: New artifact prefix `lws-hmi/app/`; existing `lws-hmi/release.json` becomes OS/system channel keyed by OS Version.
- **Breaking for operators**: Settings copy and cloud OTA gating change; `push-app` is signed `upgrade-app` (no unsigned path); version bump default no longer touches the Flutter app without `APP=`.
