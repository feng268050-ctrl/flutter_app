# power-efficiency-modes Specification

## Purpose

Operator-selectable SoC load / thermal profiles (`performance` / `balanced`): board helper + `/var/lib/hal/power.conf`, HAL API, and Flutter continuous-paint policy. Energy savings MAY occur as a side effect but are not the normative KPI.

## Requirements

### Requirement: Dual thermal load profiles

The appliance SHALL expose exactly two operator-selectable SoC **load / thermal** profiles with tokens `performance` and `balanced`. Mode `performance` SHALL maximize SoC clocks / responsiveness and allow full Flutter decorative and transition animation. Mode `balanced` SHALL reduce sustained hardware load and heat by applying a lower clock policy (governor and/or max-freq cap) and by reducing non-essential Flutter continuous paint / animation. Energy savings MAY occur as a side effect but MUST NOT be the normative success criterion. When no persisted mode exists, the system SHALL behave as `performance`.

#### Scenario: Default is performance

- **WHEN** `/var/lib/hal/power.conf` is absent or lacks a valid `mode` key
- **THEN** boot restore and HAL getMode SHALL treat the effective mode as `performance`

#### Scenario: balanced reduces soft and hard sustained load

- **WHEN** the operator selects `balanced`
- **THEN** the board helper applies the balanced clock / cpuidle profile
- **AND** the HMI continuous-paint / animation policy reduces or disables non-essential motion

### Requirement: Persist mode under power.conf

The selected mode SHALL be persisted at `/var/lib/hal/power.conf` as `mode=performance` or `mode=balanced`. The preference MUST NOT be stored solely in App JSON under `/var/lib/hmi/`. Cold boot SHALL restore the last mode before `hmi.service` starts.

#### Scenario: Mode survives reboot

- **WHEN** the operator sets `balanced` and the device reboots
- **THEN** `/var/lib/hal/power.conf` still contains `mode=balanced`
- **AND** the early boot oneshot applies the balanced hardware profile before the HMI process starts

#### Scenario: Mode not in common-settings.json

- **WHEN** the operator changes load profile from the Power Mode settings page
- **THEN** the authoritative write is `/var/lib/hal/power.conf`
- **AND** `/var/lib/hmi/common-settings.json` is not required to store the mode

### Requirement: Board helper applies hardware profiles

The image SHALL provide a board helper under `/usr/libexec/board/` (operator symlink under `/usr/bin/`) that applies the hardware profile for a given mode:

- **performance:** set CPU cpufreq and available DMC/GPU/NPU devfreq governors to `performance` when listed in `available_governors`; restore or clear any balanced CPU max-freq cap; disable deep cpuidle states whose name is not `WFI`.
- **balanced:** set CPU governor to the first available of `ondemand`, `schedutil`, `powersave`; when `scaling_max_freq` is writable, cap CPU max frequency to a mid operating point from the available table (board-tuned nearest OPP); keep **all** available devfreq governors on `performance` (GPU ondemand before Weston leaves a black desktop; NPU ondemand → DVFS errors; DMC ondemand breaks VOP rate programming); re-enable deep cpuidle states previously disabled for performance.

Invoking the helper with an explicit mode argument SHALL persist that mode to `power.conf`. Invoking with no mode argument SHALL read `power.conf` (default `performance`) and apply without requiring a UI.

#### Scenario: Explicit balanced apply persists

- **WHEN** an operator runs `set-power-mode balanced` (or equivalent `set-performance-mode balanced`)
- **THEN** governors / max-freq / cpuidle follow the balanced profile
- **AND** `/var/lib/hal/power.conf` contains `mode=balanced`

#### Scenario: Boot oneshot restores without args

- **WHEN** `cpu-performance.service` (load profile oneshot) starts on boot with `mode=balanced` persisted
- **THEN** the helper applies balanced without rewriting the operator choice to `performance`

### Requirement: Flutter continuous-paint policy follows mode

The LWS HMI App SHALL load the effective load profile at startup and keep an app-wide continuous-paint / animation policy in sync with HAL mode changes:

- **performance:** retain current full decorative and transition animation behavior (including home looping WebP decorations when those assets are used; Home Monitor / Settings / AI Vision quick-action tiles MAY scale on press with the Home-QA gray overlay).
- **balanced:** disable or snap non-essential page/chrome transitions (including Settings / Monitor / Engineer tab slide bodies); replace home looping decorative WebP with static fallback imagery (oversized paced plates MUST NOT paint); set `MediaQuery.disableAnimations` and Theme `splashFactory` to **`CyberPressInkSplash`** so Material / CyberUI ink targets (list rows, buttons, cards, tiles) paint a flat Home-QA press dim (`CyberPressFeedback.overlay`, ARGB `0x66000000`) instead of an expanding ripple. Home Monitor / Settings / AI Vision entries MUST keep that overlay and MUST NOT scale on press under `balanced`. Quick / Engineer mode entries and product top tabs SHALL use the same overlay press language (no ink ripple). Functional progress UX (hold-confirm, OTA/upgrade progress, alarm attention) MUST remain usable.

#### Scenario: Home decoration static in balanced

- **WHEN** mode is `balanced` and the Home route shows decorative side assets
- **THEN** looping animated WebP playback is not required
- **AND** a static fallback image (or equivalent still presentation) is shown instead

#### Scenario: Press feedback replaces ripple in balanced

- **WHEN** mode is `balanced` and the operator presses a Material `InkWell` / `CyberButton` / list row that uses Theme splash
- **THEN** the splash MUST NOT be an expanding ripple
- **AND** a flat press dim matching Home-QA overlay gray SHALL be shown instead

#### Scenario: Home quick-action tiles do not scale in balanced

- **WHEN** mode is `balanced` and the operator presses Home Monitor, Settings, or AI Vision
- **THEN** the tile MUST NOT scale down on press
- **AND** the Home-QA gray press overlay SHALL still appear

#### Scenario: Mode switch applies clocks immediately; HMI policy on next seat

- **WHEN** the operator switches from `performance` to `balanced` in OS Settings Power Mode
- **THEN** the board helper applies the balanced clock/cpuidle policy without requiring a reboot
- **AND** when product HMI becomes the active seat again it reads `/var/lib/hal/power.conf` and applies continuous-paint / animation policy

### Requirement: OS Settings Power Mode page exposes mode control

**OS Settings** SHALL expose **Power Mode** under Display & Sound with a detail page that selects 性能 / 均衡 (localized: Performance / Balanced; tokens `performance` / `balanced`). Operator-facing copy MUST NOT present the mode primarily as “省电” / energy saving. Changing the selection SHALL call the HAL load-profile API (persist + apply). Product HMI Common Settings MUST NOT expose Power Mode; HMI still reads the persisted mode for continuous-paint policy. The mode MUST NOT be nested under the Display brightness page.

#### Scenario: Operator selects均衡 on Power Mode page

- **WHEN** the operator opens OS Settings → Power Mode and selects the balanced / 均衡 option
- **THEN** HAL setMode(`balanced`) is invoked
- **AND** `/var/lib/hal/power.conf` contains `mode=balanced`

#### Scenario: Mode not on Display page

- **WHEN** the operator opens OS Settings → Display or HMI Common Settings → Display
- **THEN** the Display page MUST NOT offer the performance / balanced selector

#### Scenario: HMI Settings has no Power Mode entry

- **WHEN** the operator opens product HMI Common Settings
- **THEN** Power Mode is not listed
