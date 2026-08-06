## Context

Today the ynh960 line boots with `cpu-performance.service` → `/usr/libexec/board/set-performance-mode.sh`, which:

1. Sets CPU cpufreq + DMC/GPU **devfreq** governors to `performance` when available.
2. Disables deep **cpuidle** states (keeps WFI only) to avoid wake-latency jank.

That profile is correct for snappy HMI and boot KPI, but there is no operator way to trade clocks + continuous UI/GPU work for **lower sustained SoC load and heat**. Product intent for the second mode is **thermal / load reduction**, not battery life or “省电” marketing. Common Settings hosts a dedicated **Power Mode** entry (Unit-style nav → sub-page, own card). Flutter decorative work (home WebP loops, page transitions, CyberUI ripples) is independent of governors and must be gated in-App because it keeps the GPU/UI threads painting.

Constraints: keep default = today’s performance behavior; no Android HAL backends; prefer verb-noun helpers under `/usr/libexec/board/`; persist under `/var/lib/hal/` (not App `common-settings.json`) so boot can restore **before** HMI start.

## Goals / Non-Goals

**Goals:**

- Two named modes: **performance** (性能) and **balanced** (均衡 / Balanced).
- Primary success metric for `balanced`: lower sustained CPU/GPU/DDR **clocks and busy time** → lower SoC temperature under typical HMI idle/Home use (vs performance). Energy draw may fall as a side effect; it is not the KPI.
- Soft+hard coupling: switching mode applies SoC clock policy **and** Flutter continuous-paint / animation policy.
- Persist + cold-boot restore before `hmi.service`.
- HAL portable API (Linux + stub) + Display Settings UX + l10n (copy must not imply “省电” as the goal).
- `verify-boot` understands both modes.

**Non-Goals:**

- Optimizing wall-power or battery runtime as a primary requirement.
- Using backlight / AutoSleep as the main `balanced` levers (those are panel watts / UX idle; weak SoC thermal levers).
- Automatic thermal trip → mode switching (may be a later feature).
- Per-core manual MHz pickers in UI.
- Weston / DRM FPS caps separate from governors + App paint policy.
- Shipping camera/AI duty-cycle gating in v1 (recommended follow-up under the same mode).
- Large CyberUI public API redesign.

## Decisions

### D1 — Persist at `/var/lib/hal/power.conf` (`mode=…`)

- **Choice:** Dedicated `power.conf` with key `mode=performance|balanced` (default when missing: `performance`). Filename keeps “power profile” vocabulary; semantics are **load/thermal profile**.
- **Why not `display.conf`:** Clocks are board-wide, not a display attribute.
- **Why not App JSON:** Boot unit must restore clocks before Flutter starts.
- **Alternatives considered:** `properties.ini` — rejected (factory tunables). Token `powersave` — rejected for operator/docs clarity (sounds like energy saving).

### D2 — Extend existing board helper (minimal rename churn)

- **Choice:** Extend `/usr/libexec/board/set-performance-mode.sh` to:
  - Accept optional arg `performance|balanced`.
  - With no arg: read `power.conf` (missing → `performance`) and apply.
  - With arg: apply **and** persist `mode=` to `power.conf`.
  - Prefer operator name `/usr/bin/set-power-mode`; keep `set-performance-mode` as compatibility entry.
- **Unit:** Keep basename `cpu-performance.service`; update Description to “CPU/DMC/GPU load profile”; oneshot restore-on-boot.

### D3 — Hardware profile matrix (thermal-first)

| Knob | performance | balanced |
|------|-------------|----------|
| CPU `scaling_governor` | `performance` if available | Prefer `ondemand`, else `schedutil`, else `powersave` |
| CPU `scaling_max_freq` | restore policy max (or clear cap) | Cap to a mid OPP when the freq table allows (e.g. ~50–70% of max, pick nearest available); if uncappable, rely on governor only |
| DMC/GPU `devfreq` governor | `performance` if available | Prefer `simple_ondemand`, else `ondemand` |
| Deep cpuidle (`name != WFI`) | **disable** | **re-enable** (helps idle average heat; secondary to clock cap under active UI) |

- **Why max-freq cap:** Pure `ondemand` still ramps to top OPP under scroll/paint → heat spikes remain. A **hard ceiling** is the direct thermal lever; governor choice then handles below-cap dynamics.
- **Why still change governors / GPU-DMC:** Locked `performance` on GPU/DDR keeps high idle clocks and heat even with quieter UI.
- **Why not backlight:** Panel backlight dominates wall power more than SoC junction temperature; out of scope for this mode’s primary story.
- **Alternatives considered:** Sticky `powersave` (min freq only) — too sluggish for interactive HMI; rejected as sole policy.

Exact mid OPP MAY be board-tuned in the helper (ynh960 table) with a safe fallback if sysfs is SCMI-limited.

### D4 — HAL API under `hal/output`

- **Choice:** Public enum `{ performance, balanced }` (wire tokens `performance` / `balanced`) with `getMode` / `setMode`.
- **Export:** `package:cyber_hal/output` (e.g. `power_mode.dart` or `load_profile.dart`).
- **Backend:** OS helper + `power.conf`; stub in-memory.

### D5 — Flutter continuous-paint policy (App-owned)

- **Choice:** App-level scope loaded at startup from HAL, updated on Settings change.
- **performance:** Current full decorative and transition animation.
- **balanced:** Cut **sustained** GPU/UI work — snap non-essential transitions; replace home looping WebP with static fallbacks; honor reduced-motion where applicable. Keep functional progress (hold-confirm, OTA, alarms) perceptible.
- **Rationale:** Looping Home WebP and chrome transitions are continuous heat contributors on this platform, independent of “省电”.

### D6 — Settings UX

- **Choice:** Common Settings gains an **independent untitled card** for **Power Mode** (en: Power Mode; zh-CN: 效能模式), placed **after Display & Sound and before RGB LED + Camera**. The card has one **SettingsNavRow** with trailing summary (Performance / Balanced), matching **Unit** chrome: tap → push `PowerModeSettingsPage` (or equivalent). The sub-page lists the two options; selection calls HAL `setMode` and updates soft policy immediately (no HMI restart for soft side).
- **Why not under Display:** Power/clocks are board-wide load policy, not a display attribute; a separate group matches product “General” IA and keeps Display focused on brightness / screen-off.
- **Why Unit-style sub-page:** Same discoverability and selection pattern operators already know; avoids cramming a third control onto Display.
- **Copy:** Avoid “节能” as the primary label so operators do not expect battery semantics; Balanced / 均衡 MAY mention lower heat in help text.

### D7 — Boot verify

- **Choice:** Honor `power.conf`; `performance` expects performance governors; `balanced` MUST NOT require `performance` governors / uncapped max freq.

### D8 — Follow-up heat levers (same mode, later)

Under `balanced`, later slices MAY also: pause/throttle camera preview + MediaMTX when not on Monitor; reduce AI daemon inference duty; lengthen non-critical Modbus/status polling. Not required for v1 ship of clocks + animation policy.

## Risks / Trade-offs

- **[Risk] Mid OPP cap feels sluggish under load** → Mitigation: pick mid-high OPP (not min); default remains performance; document thermal intent.
- **[Risk] SCMI board lacks classic `scaling_max_freq`** → Mitigation: apply whatever is available (governor + GPU/DMC + soft policy); do not fail the mode.
- **[Risk] Operators still read it as “省电”** → Mitigation: UI/copy = 均衡 / Balanced; Settings help text MAY mention 降低发热.
- **[Risk] Mode apply races with boot unit** → Mitigation: idempotent helper; boot only reads conf.
- **[Trade-off] Unit still named `cpu-performance.service`** → Accept for churn; rename later if desired.

## Migration Plan

1. Ship extended helper + `power.conf`; missing conf → performance ≡ old behavior.
2. Ship HAL + App UI + paint policy together.
3. Rollback: revert App/HAL; helper defaults to performance.

## Open Questions

- Exact mid OPP for ynh960 (measure once on device: thermal delta vs scroll latency).
- Whether Power Mode sub-page help text should explicitly say “降低发热” in zh-CN.
- Operator binary: only `set-power-mode` long-term vs keep `set-performance-mode` forever.
