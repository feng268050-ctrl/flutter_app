## Context

Product HMI (`app/lws_hmi` → `/opt/hmi`, `hmi.service`) already embeds a four-tab Settings shell that mixes platform controls (Wi‑Fi, locale, display, input, …) with welding-only Advanced / Custom Home / cloud / peripheral pages. Multi-app Make already supports non-HMI `APP=<id>` → `/opt/<APP>` and once planned an auto-included `factory_test` second app that was never sourced. Platform direction (`docs/settings-app-plan.md`, `platform-os-oem-sdk-plan.md`) is a separate OS-style Settings Flutter app sharing OEM `board_profile` + `cyber_hal`, not product gpio/modbus, on the same rootfs.

## Goals / Non-Goals

**Goals:**

- Scaffold and ship `app/settings` → `/opt/settings` with CyberUI OS Settings IA (flat list; landscape master-detail / portrait push).
- Replace `factory_test` auto-include / verify / docs with **`settings`**.
- Mutual-exclusion lifecycle with HMI (`Conflicts=`, switch scripts, safe CLI).
- Copy vs migrate platform pages per plan §4; Bluetooth alias = Brand + `" "` + Model; Storage Secrets Seal status; OS version probes via HAL.
- Document rebuild commands (`APP=settings make build-app` / `push-app`; rootfs ensure).

**Non-Goals:**

- Factory Test /产测 App; gpio/modbus in OEM rootfs pack.
- Settings as default desktop or dual Flutter clients on one seat.
- Moving Advanced / Custom Home / cloud / product peripheral versions / HMI App OTA into Settings.
- `cyber_hal` Android backends; full `migrate-secrets` wizard in Settings.
- Changing kernel orientation mid-session as layout strategy (App adaptive only).

## Decisions

### 1. App id and install prefix

| Item | Choice |
|------|--------|
| Directory / `APP=` | `settings` |
| Device path | `/opt/settings` |
| Second-app slot | Replaces planned `factory_test`; no `app/factory_test` |

Reuse `scripts/app-select.sh` non-HMI path (`APP_OPT_NAME=settings`). No dedicated `make build-factory-test`-style target.

**Alternatives:** `system_settings` / `platform_settings` — rejected; plan locks `settings` and `/opt/settings`.

### 2. Lifecycle: static unit + Conflicts + switch helpers

| Component | Behavior |
|-----------|----------|
| `settings.service` | **static** (no `WantedBy=multi-user.target`); `Conflicts=hmi.service` |
| `hmi.service` | Keep multi-user enable; add `Conflicts=settings.service` |
| `settings-launch.sh` | Same preflight as `hmi-launch.sh`; `BUNDLE=/opt/settings` |
| `/usr/bin/settings` | Default: refuse if `hmi.service` active; `--stop-hmi` then foreground |
| `switch-to-settings` / `switch-to-hmi` | `systemctl start` peer (Conflicts stops the other) |
| Ctrl+C on CLI | Does **not** auto-start HMI; only Exit / `switch-to-hmi` |

**Alternatives:** Hidden Kernel×5 entry (old factory plan) — rejected. Parallel Wayland clients — rejected (GPU/session contention).

### 3. HMI entry / Settings Exit

- HMI: explicit **System Settings** (or gear) invokes `switch-to-settings`; on failure Toast and stay in HMI.
- Settings: prominent **Exit** → `switch-to-hmi`.

### 4. IA: flat ordered list, no plan group headers

Top-level rows (order fixed by plan): About → Operating System → Storage → Wi‑Fi → Ethernet → Bluetooth → Proxy → SSH → 日期和时间 → Country/Region → Language → Unit → Display → Sound → Power Mode → Keyboard → Mouse → USB OTG → Exit (chrome).

Logical “Basic Info / Network / …” names are code modules only — **must not** render as section headers.

### 5. Copy vs migrate ownership

| Mode | Settings | HMI |
|------|----------|-----|
| **Copy** | Implement (clone or shared package) | Keep |
| **Migrate** | Implement then own | Remove page + nav + Demo orphans |

Migrate set: Ethernet, Bluetooth, SSH, Keyboard, Mouse, USB OTG.  
Copy set: About identity, Wi‑Fi, Proxy, Date & Time, Country/Region, Language, Unit, Display, Sound, Power Mode (HMI General → same HAL `/var/lib/hal/power.conf`).

Short-term: copy Dart from HMI and converge later into shared packages when drift hurts. Keyboard Restart after migrate MUST restart **Settings** (or `systemctl restart settings`), never implicitly `start hmi` while Settings owns the seat.

### 6. HAL extensions for OS + Storage

- Extend `SysInfo` and/or a dedicated read-only **PlatformVersions** reader for: os-release, kernel (existing), SELinux mode, BusyBox, glibc, wpa_supplicant, BlueZ, OpenSSL, OpenSSH, GStreamer, Flutter pin, Buildroot pin.
- Soft-fail each probe → UI shows `—`; never throw out of isolate.
- Secrets Seal row: query existing `KekProvider` / `backendId` (`software` \| `op-tee`); no migrate wizard in this change.
- Settings loads OEM `BoardProfile` only — **no** product gpio/modbus assets.

### 7. Bluetooth alias policy

On Settings Bluetooth stack start (and when identity becomes readable): `setAlias("{Brand} {Model}")` via existing HAL / `/var/lib/bluetooth/adapter-alias`. Missing identity → safe placeholder (e.g. Model-only or prior default), not hardcoded product marketing strings as the target end state.

### 8. Build / verify / docs

- `ensure-rootfs-apps`: when `app/settings/pubspec.yaml` exists, ensure `/opt/settings`.
- `verify-rootfs-overlay`: require Settings AOT tree without engine/ICU/JIT when source exists.
- Update AGENTS rebuild table, README, make-commands, multi-app + image specs, `app/README.md`.

### 9. Phased delivery (maps to tasks)

A scaffold + lifecycle + entry → B Basic Info → C Network (copy then migrate) → D Date/locale → E Display/Sound/Power Mode → F Input migrate → G HMI cleanup / Demo / docs acceptance.

## Risks / Trade-offs

- [Two Flutter clients fight the seat] → Bidirectional `Conflicts=`; CLI refuses grab without `--stop-hmi`.
- [Copied pages drift] → Prefer shared packages when practical; tasks allow copy-first with explicit converge follow-up.
- [Migrated deep links / Demo orphans] → Grep routes / `pushSettingsPage`; update `p2-device-demo-ui`; optional delete whole P2 Demo.
- [Language/Unit/Power Mode dual App] → Same HAL stores (`locale.conf` / `power.conf`); HMI re-reads on return.
- [Keyboard Restart starts wrong unit] → Document restart-Settings-only; never auto-start HMI from Settings keyboard apply.
- [Version probe fragility] → Soft-fail + unit tests on parsers; no hard dependency in UI isolate.
- [Rootfs size] → No welding assets in Settings; ban second engine in bundle; watch ext2 budget.
- [Stale factory_test docs] → Sweep scripts/specs/AGENTS in same change.

## Migration Plan

1. Land scaffold + overlay units without requiring operators to leave HMI (SSH `systemctl start settings` for bring-up).
2. Ship pages incrementally; migrate HMI removals only after Settings page reaches parity for that feature.
3. Rootfs: `make build-rootfs` after `app/settings` exists auto-includes both trees; field boards use normal `upgrade` (no `/userdata` wipe).
4. Rollback: omit Settings entry in HMI and leave `/opt/settings` unused; HMI copy pages remain until migrate commits land.
5. No GPT / OEM partition format required.

## Open Questions

- Exact HMI chrome for System Settings (Home gear vs product Settings shell row) — product UX choice; behavior is `switch-to-settings` either way.
- Whether Phase G deletes the entire P2 Demo route or only orphan sections — delete when no retained value; not a Settings blocker.
- Shared presentation package timing (immediate vs post-copy) — deferred to implementation; copy-first is acceptable.
