## Context

Product identity today is a single Flutter “System Version” (`app/lws_hmi/pubspec.yaml` → `kSystemVersion`). Whole-device A/B OTA (`cyber_ota`, CDN `lws-hmi/release.json`) and Device Information both key off that value, while `/opt/hmi` is also mutable via unsigned `make push-app`. Peripheral channels (control-board / camera) already prove the preferred pattern: Ed25519-signed blob + sibling `.sig`, host HTTP or CDN URL, device `download <url>` on `/run/hmi/*.cmd`, shared `cyber_upgrade_ui`.

This change introduces a durable split: **OS Version** owns the rootfs / whole-device channel; **HMI Version** owns the Flutter app tree under `/opt/hmi` and an independent cloud channel at `lws-hmi/app/`.

## Goals / Non-Goals

**Goals:**

- Stamp and display **OS Version** (start **1.0.0**) from rootfs; display **HMI Version** from the running app.
- Keep baking the current HMI into `build-rootfs` / factory images.
- Package HMI as signed `tar.gz`, publish under `lws-hmi/app/`, upgrade via the same secure path as peripherals; restart `hmi.service` after apply.
- HMI Upgrade UI shows HMI Version + Process Library Version; cloud-only version check (no bundled HMI package).
- Replace unsigned `make push-app` with signed **`make upgrade-app`**; keep **`push-app` as a Make alias** of `upgrade-app` (same signed path; no unsigned SCP retained).
- `make version` / `version-bump` default to OS; **`APP=`** selects the Flutter app (no `HMI=` alias).

**Non-Goals:**

- App-only A/B slot writes or changing the whole-device OTA archive format (still boot + rootfs + optional oem).
- Process-library cloud publish or signed HTTP for process-library (existing host upload path stays).
- Bundled-vs-cloud newest-wins for HMI (explicitly cloud-only).
- Changing control-board / camera upgrade semantics.
- Multi-app concurrent HMI installs (still one `/opt/hmi` per rootfs).
- Migrating historical CDN `lws-hmi/release.json` artifacts already published under old System Version numbering beyond documenting the cutover.

## Decisions

### D1 — OS Version stamp location

**Choice:** Bake a single-line SemVer file into rootfs, e.g. `/etc/os-version` (or `/usr/share/hmi/os-version` if we prefer product-owned path under existing conventions), written from a repo SoT such as `board/os-version.txt` or `overlay/.../etc/os-version` during `apply-overlay` / `build-rootfs`.

**Rationale:** Simple for shell, HAL, and App to read; survives independently of Flutter assets; visible in rootfs images without parsing Buildroot `/etc/os-release` PRETTY_NAME.

**Alternatives:** Embed only in `/etc/os-release` `VERSION_ID` (collides with distro semantics); keep version only in cloud `release.json` (device cannot show local OS version offline).

### D2 — HMI Version constants rename

**Choice:** Treat Flutter pubspec + generated/synced Dart constants as **HMI Version** (`kHmiVersion` / `kHmiVersionCode`); retire `kSystemVersion` as the product umbrella name (keep temporary export aliases only if needed for a one-release migration, then remove).

**Rationale:** Matches UI copy and cloud channel semantics; avoids continuing to call the app version “System”.

### D3 — Whole-device OTA gates on OS Version

**Choice:** CDN `lws-hmi/release.json` (system / OS channel) `version` and `make publish` / `ota-package` naming use **OS Version**. HMI pubspec no longer drives that channel.

**Rationale:** Rootfs contents define OS; HMI can diverge after independent app OTA.

### D4 — HMI package format

**Choice:** `tar.gz` of the installable `/opt/hmi` payload (same logical tree `build-app` stages: `libapp.so`, `flutter_assets`, optional `bin/` / `lib/`, `runtime-mode.json`, etc.), sibling Ed25519 `.sig` via existing `ota-sign.sh` / device pubkey `/etc/ota/ed25519.pub`.

**Rationale:** Mirrors whole-device and peripheral signing; install path can reuse / evolve `push-app-apply-and-restart.sh` behind verify.

**Alternatives:** rsync-only unsigned push (rejected — user requires signed path); squashfs (heavier, no existing tooling).

### D5 — Cloud layout

**Choice:** Publish under **`lws-hmi/app/`** with `release.json` shape `{ version, filename, published_at, url }` (same as peripherals). Manifest version = `v{semver}` from HMI pubspec. Filename e.g. `app-v{semver}.tar.gz` (exact pattern fixed in implementation to match publish script conventions).

**Rationale:** User-specified directory; consistent with `lws-hmi/control-board/` and `lws-hmi/camera/`.

### D6 — Device command + apply

**Choice:** Watcher on `/run/hmi/upgrade-app.cmd` (commands: `download <url>`, optional `clean`), using `SignedBlobFetch` then extract/install to `/opt/hmi` and restart `hmi.service` (same restart semantics as today’s push-app apply). Operator UI and host force both supported via `UpgradePolicy`.

**Rationale:** Parallel to `upgrade-control-board.cmd` / `upgrade-camera.cmd`; host Make target and cmd basename both use **app**.

### D7 — HMI Upgrade UI content

**Choice:** New (or retargeted) **HMI Upgrade** page: idle rows = **HMI Version** + **Process Library Version**. Move Process Library off the OS/System Upgrade page. OS Upgrade keeps OS Version (+ Kernel as today). Device Information: separate nav rows for OS Version and HMI Version.

**Rationale:** Matches user request; Process Library is app-owned data, not rootfs channel identity.

### D8 — No bundled HMI version

**Choice:** Version check compares running `kHmiVersion` to cloud `lws-hmi/app/release.json` only. Do not ship a second “bundled package version” artifact or newest-wins against assets.

**Rationale:** Explicit product rule; app already *is* the installed tree.

### D9 — Host upgrade replaces unsigned push-app

**Choice:** **`make upgrade-app`** is the canonical target (sign `tar.gz`, HTTP serve, write `download <url>` to `/run/hmi/upgrade-app.cmd`). **`make push-app` SHALL be a Make alias of `upgrade-app`** — identical signed behavior. The former unsigned SCP / staging hot-swap path MUST be removed (no opt-in to skip signing).

**Rationale:** Preserve muscle memory (`push-app`) while forcing the same security baseline as peripherals; keep the **app** vocabulary already used by `build-app`.

### D10 — Host version tooling

**Choice:**

- Default (no `APP=`): read/bump **OS Version** SoT file.
- `APP=<flutter-app-id>` (resolve via `app-select.sh`, default `lws_hmi`): existing pubspec + `app_version.dart` sync for HMI Version. **No `HMI=` / `APP=HMI` alias.**
- Keep 5-digit build encoding for the Flutter app; OS Version MAY use SemVer-only in the stamp file (build number optional — prefer SemVer-only for OS unless publish tooling requires a code).

**Rationale:** User-specified default; reuse existing `APP=` multi-app selection without new aliases.

### D11 — Relationship to rootfs bake

**Choice:** Unchanged pipeline rule: `make build-app` stages into overlay; `make build-rootfs` bakes current `/opt/hmi`. Independent HMI OTA updates the live slot’s `/opt/hmi` only; next full rootfs OTA may overwrite with the baked app unless operators publish matching versions.

**Rationale:** Factory images stay self-contained; field app fixes stay fast.

## Risks / Trade-offs

- **[Risk] OS and HMI versions diverge; support confusion** → Show both clearly on Device Info; document that full rootfs OTA resets `/opt/hmi` to the baked app.
- **[Risk] HMI tar.gz omits native companions (AI/mediamtx) and breaks runtime** → Package MUST include the same companion set `build-app` installs under `/opt/hmi`; verify in packaging script.
- **[Risk] Apply + restart kills the process mid-watcher** → Reuse detached apply/restart pattern from push-app (`setsid` / stop-wait-start) so install completes after Flutter exits.
- **[Risk] CDN cutover: old `lws-hmi/release.json` still keyed to app semver** → Publish first OS `1.0.0` system package explicitly; document that devices must understand OS vs HMI checks before relying on split.
- **[Risk] Unsigned push-app removal slows local iteration** → `push-app` / `upgrade-app` still work over USB-SSH with local sign key; accept signing cost as the security baseline.

## Migration Plan

1. Land OS Version stamp `1.0.0` + App/HAL read path; UI labels OS vs HMI (HMI still from current pubspec).
2. Wire app package / sign / watcher / install / restart; host `upgrade-app` with `push-app` as alias; delete unsigned SCP path.
3. Ship HMI Upgrade page + cloud check against `lws-hmi/app/`; move Process Library row.
4. Retarget `make publish` / system OTA UI to OS Version; publish OS `1.0.0` channel artifact.
5. Update docs / AGENTS rebuild table; remove deprecated `kSystemVersion` once callers are gone.

**Rollback:** Revert App to single System Version UI and restore prior host scripts; CDN can keep serving last known good manifests. Rootfs stamp file is harmless if ignored.

## Open Questions

- Exact on-disk path for OS Version (`/etc/os-version` vs `/usr/share/hmi/os-version`) — prefer product-owned path if `/etc/os-release` tooling is noisy; finalize during apply.
- Whether OS Version needs a numeric `versionCode` for cloud compare, or SemVer string compare only (system OTA today uses SemVer string vs `kSystemVersion`).
- Final filename pattern for app artifacts (`app-v1.0.41.tar.gz` vs including APP id).
