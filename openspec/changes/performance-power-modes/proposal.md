## Why

The appliance today always locks CPU/DMC/GPU to `performance` governors (and disables deep cpuidle) via `cpu-performance.service` / `set-performance-mode.sh`, while the Flutter HMI runs full decorative and transition animations. That maximizes snappiness but keeps sustained SoC **load and heat** high. Operators need a single **效能** switch: a **性能模式** that keeps max clocks and full motion, and a **均衡模式** whose primary goal is **lower hardware duty cycle and SoC temperature** (not battery life or AC watt-hours) — by capping clocks and cutting continuous UI/GPU work — without forking the image or teaching sysfs.

## What Changes

- Introduce two operator-visible **thermal / load profiles**: `performance` (性能) and `balanced` (均衡), defaulting to `performance` (preserves today’s boot KPI / jank assumptions).
- Extend the board helper so it can apply either profile (CPU/DMC/GPU governors, optional max-freq cap, cpuidle policy), not only “always performance”.
- Persist the selected mode under HAL userdata and restore it at boot before HMI start (same early path as today’s `cpu-performance.service`).
- Add a `cyber_hal` API so the App can read/set the mode and apply hardware side-effects without shelling out ad hoc from widgets.
- Drive Flutter **animation / continuous-paint policy** from the mode: performance = current full motion; `balanced` = reduce/disable non-essential animations and looping decorations (page transitions, home WebP loops, decorative CyberUI motion) to cut sustained GPU/UI work, while keeping functional feedback usable.
- Expose the switch on Common Settings → Display, with l10n for en-US / zh-CN / zh-TW (labels emphasize **load/heat**, not “省电”).
- Update boot verify expectations so a persisted `balanced` mode is not flagged as a false failure when governors are intentionally not `performance`.

## Capabilities

### New Capabilities

- `power-efficiency-modes`: Dual soft+hard thermal/load profiles (`performance` / `balanced`), persistence, boot restore, HAL API, Flutter continuous-work policy, and Settings UX. (Capability id kept; **intent is SoC load/heat reduction**, not energy metering.)

### Modified Capabilities

- `os-path-layout`: Board helper / operator command naming for applying load profiles (generalize beyond one-shot “set performance”).
- `hmi-systemd-boot`: Early boot unit applies the **persisted** load profile (not hard-coded performance-only).
- `linux-settings-persist`: Persist mode under `/var/lib/hal/` (dedicated conf or documented key).
- `shell-hw-persist`: Document load-mode as a shell/HAL-restored preference.
- `settings-ui`: Display sub-page includes the performance / balanced control.
- `dart-hal`: Linux (+ stub) HAL surface for get/set load profile.

## Impact

- **Overlay / board**: `set-performance-mode.sh` (or successor), `cpu-performance.service`, `boot-verify.sh`, `post-build.sh` symlink, rootfs verify lists.
- **`packages/cyber_hal`**: New output load-profile API + Linux/stub backends; prefs path constants.
- **`app/lws_hmi`**: Display settings row, app-wide animation/continuous-paint policy, home decorative WebP gating, l10n ARBs.
- **`packages/cyber_ui`** (optional / minimal): Prefer App-owned policy wiring over large CyberUI API churn.
- **Docs / AGENTS rebuild table**: Overlay + App paths when shipping.
- **Non-goals for this change**: Battery / AC energy optimization as a product KPI, backlight dimming as a primary lever, automatic thermal-triggered mode switching, GPU/Weston compositor FPS caps beyond governor + animation policy, Android HAL backends. Follow-up heat levers (camera preview / AI daemon duty) MAY be added later under the same mode.
