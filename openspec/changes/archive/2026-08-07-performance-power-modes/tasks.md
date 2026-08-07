## 1. Board helper and boot restore

- [x] 1.1 Extend `/usr/libexec/board/set-performance-mode.sh` to accept `performance|balanced`, apply the thermal-first matrix from design (governor + optional `scaling_max_freq` mid OPP + GPU/DMC + cpuidle), persist `mode=` to `/var/lib/hal/power.conf` when given an arg, and restore from conf when invoked with no args (default `performance`)
- [x] 1.2 Add `/usr/bin/set-power-mode` symlink (keep `set-performance-mode`); update `post-build.sh` and `verify-rootfs-overlay.sh` lists
- [x] 1.3 Update `cpu-performance.service` Description to load-profile restore; keep oneshot + `Before=hmi.service` behavior (no-arg helper)
- [x] 1.4 Update `boot-verify.sh` governor/max-freq checks to honor persisted `power.conf` mode (no false FAIL on intentional balanced)

## 2. HAL load-profile API

- [x] 2.1 Add public load-profile enum + interface under `package:cyber_hal/output` (tokens `performance` / `balanced`; prefs path for `power.conf`)
- [x] 2.2 Implement Linux backend (read/write conf + invoke board helper) and stub in-memory backend; wire board bindings
- [x] 2.3 Add package unit tests for stub round-trip and Linux conf parse/default behavior (injectable paths/helper)

## 3. App continuous-paint policy and Settings UX

- [x] 3.1 Add app-wide load-profile / continuous-paint scope loaded at startup from HAL; update on setMode
- [x] 3.2 Gate home decorative WebP loops to static fallbacks under balanced; snap/reduce non-essential Settings/chrome transitions; replace Material/CyberUI ripples with Home-QA press dim (`CyberPressInkSplash`); Home QA tiles overlay-only (no scale); keep functional progress UX
- [x] 3.3 Add Common Settings **Power Mode** untitled card (after Display & Sound, before RGB LED) with Unit-style nav → `PowerModeSettingsPage`; options 性能 / 均衡 (en: Performance / Balanced; not 节能); wire to HAL; add l10n (`make l10n`)
- [x] 3.4 Add App widget/unit tests for policy gating and Power Mode sub-page invoke where practical

## 4. Docs and verification

- [x] 4.1 Update notes that claim “always performance governors” without mode context; document balanced as thermal/load reduction (not energy KPI)
- [x] 4.2 Host verify: `flutter analyze` / package + App tests; on device: `set-power-mode balanced` / `performance`, check thermal/freq behavior, `verify-boot`
