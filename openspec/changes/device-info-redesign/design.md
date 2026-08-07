## Context

Device Information (`DeviceInformationTab`) today uses three untitled CyberUI cards: identity (Model / SN / Welding Gun SN), versions (System → OTA, Kernel, Process Library, Control Board → upgrade, Laser, Wire Feeder), and Focus Scale Reference. Camera Version already exists via `CameraDeviceInfoCache` on the Camera settings page and cloud snapshot packing, but Settings UI specs explicitly forbid it on Device Info. HAL `SysInfo.storage` (`df -B1` on board-profile mounts, default `/` and `/userdata`) is collected and unused by Settings. System Upgrade (`SystemUpgradePage`) shows System Version + `cyber_upgrade_ui` check/progress chrome only.

## Goals / Non-Goals

**Goals:**

- Reorder Device Info so identity is Model+SN, versions include Camera Version and exclude Kernel / Process Library, storage appears as an iOS-style bar group, and Welding Gun SN + Focus Scale Reference form the last group
- Surface Kernel Version and Process Library Version on System Upgrade (check / non–progress-only mode)
- Reuse existing HAL storage snapshots and camera version cache; keep untitled-card Settings vocabulary

**Non-Goals:**

- Changing OTA download/apply behavior, auto-check policy, or Control Board upgrade flow
- Removing Camera Version from Camera settings, or adding Camera Type to Device Info
- Fine-grained storage category accounting (apps / media / caches) beyond mount-level `df` data
- New HAL APIs or board-profile mount schema changes (unless a mount is missing in practice)
- Storage management actions (clear cache, delete files)

## Decisions

### D1 — Four untitled Device Info groups (order fixed)

| # | Group (code comment only) | Rows |
|---|---------------------------|------|
| 1 | Identity | Device Model (QR), Device SN |
| 2 | Versions | System Version (nav), Camera Version, Control Board Version (nav), Laser Version, Wire Feeder Version |
| 3 | Storage | iOS-style bar + used/available summary text |
| 4 | Accessory | Welding Gun SN, Focus Scale Reference |

**Rationale:** Matches the operator ask (gun SN + focus last; camera with versions; storage below versions). Keeps Modbus/firmware nav rows with other component versions. Alternatives considered: keep Gun SN in identity (rejected — user wants it last); put storage last (rejected — accessory pair is explicitly last).

### D2 — Camera Version on Device Info via shared cache

Wire `CameraDeviceInfoCache` (same instance as Settings / cloud `cameraVersionFetch`) into `DeviceInformationTab`. Display the same normalized string as Camera settings (`-` when unavailable). Do not show Camera Type on Device Info.

**Rationale:** One fetch path avoids divergent formatting. Spec change explicitly supersedes the prior “MUST NOT show Camera Version” rule. Alternative: duplicate HTTP read (rejected — race and inconsistency).

### D3 — Kernel + Process Library only on System Upgrade (check mode)

In `SystemUpgradePage` when not progress-only / apply UI, show read-only rows for Kernel Version (`SysInfo` / existing kernel source) and Process Library Version (`ProcessLibraryScope` / existing source) near System Version, before or above the check-card chrome. Progress-only / in-apply sessions keep current progress-only UI (no requirement to show those rows during burn).

**Rationale:** Those versions support “what am I upgrading from?” without cluttering About. Alternative: keep them on both surfaces (rejected — user asked to migrate/merge onto System Upgrade).

### D4 — Storage bar: mount-segment iOS style from `SysInfo.storage`

Add a small Settings widget (e.g. `SettingsStorageBar`) that:

1. Reads `SysInfoSnapshot.storage` for board mounts (typically `/`, `/userdata`)
2. Renders a single full-width rounded bar with **colored used segments** (one per mount with known `totalBytes`/`freeBytes`) and a trailing **available** segment (sum of free bytes across those mounts, or free of `/userdata` if product prefers “operator free space” — default: **sum of free across listed mounts**, with used = total−free per mount)
3. Shows a short legend and/or caption: used / available in human units (GB/MB), localized

No per-folder media accounting. Colors: distinct, muted, CyberUI-friendly (avoid purple/glow clichés); available segment light/gray like iOS Settings → General → iPhone Storage.

**Rationale:** HAL already provides per-mount totals; category breakdown would need new tooling. Alternative: userdata-only bar (acceptable fallback if root totals are misleading on A/B images — prefer dual-segment if both mounts report).

### D5 — Spec deltas only; no new capability folder

Update `settings-ui` and `ota-upgrade-ui`. Storage UI is Settings presentation over existing HAL, not a new product capability name.

## Risks / Trade-offs

- **[Risk] Camera Version fetch latency / offline camera** → Show `-` immediately; refresh async via shared cache (same as Camera page); do not block tab paint  
- **[Risk] Rootfs `df` size confuses operators (A/B / read-only root)** → Legend labels mounts clearly (System / User data); prefer userdata-weighted caption if UX review prefers  
- **[Risk] Spec scenarios still forbid Camera Version on Device Info** → MODIFIED requirements must replace those scenarios completely at archive time  
- **[Trade-off] No file-level reclaim UI** → Bar is informational only; matches “About” not “Storage Manager”

## Migration Plan

1. Ship App UI + l10n via `make build-app` / `push-app` (no rootfs/HAL rebuild required for display-only reuse of existing `SysInfo`)
2. Rollback: revert App; HAL storage collection already shipped and unused by other Settings surfaces
3. Archive OpenSpec change after apply + verify on device (Device Info order, System Upgrade rows, storage bar with real `df`)

## Open Questions

- Exact segment coloring tokens (use CyberUI palette vs App-local constants) — resolve during implement to match adjacent Settings rows
- Whether Process Library Version on System Upgrade is hidden when empty (parity with today’s “when available” Device Info behavior) — **default: show row with `-` when empty**, consistent with other version rows
