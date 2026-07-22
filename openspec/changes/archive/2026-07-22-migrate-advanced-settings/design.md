## Context

lws-ui Advanced Settings (`AdvancedSettingFragment`) groups product params and two App-only toggle groups:

1. **AI Assistance** — `AiAssistanceSettings` → Room `t_advanced_settings`; gates `OpencvStainDetectCoordinator`, `ZeroPointDetectCoordinator`, `NativeStreamDetectCoordinator`, `AiDaemonSupervisor.ai_assist_config`. Manual Zero Offset Auto is **not** gated.
2. **Dangerous Operations** — `DangerousOperationsSettings` → same table; consumed by `LaserEnableAlarmGuard` / `LaserWorkGuard` / `WarnDialogSeverity` / LED ready. Defaults all OFF. Not Modbus.

lws-hmi already has Settings shell + `SettingsSwitchRow`→`CyberSwitch` and Misc JSON for lightweight prefs. Advanced tab is placeholder. Warn-alarm App layer is landing separately; laser interrupt may lag.

## Goals / Non-Goals

**Goals:**
- Replicate lws-ui **section order and labels** on Advanced Settings using CyberUI controls.
- Persist AI + dangerous toggles in App store; expose read/write facades for other features.
- Document call/control graph so consumers do not re-implement policy in widgets.
- Prefer Cyber switches for all seven toggles (2 AI + 5 dangerous).

**Non-Goals:**
- Port Room / `FrostSwitchView` / Android facades by name into packages outside App.
- Fold AI/dangerous into `misc-settings.json`.
- Require HAL to store boolean assist/bypass flags.
- Complete Custom Home Page in this change.

## Decisions

### 1. Layout parity + CyberUI chrome

**Choice:** Scrollable column of sections matching lws-ui order. Each section: `SettingsSectionHeader` + `SettingsGroup` / Cyber card stand-in + rows. Toggles: `SettingsSwitchRow` → `CyberSwitch` (same as Misc). Dangerous rows include secondary hint text under title (EN/ZH).

**Rationale:** User asked for layout/component replicate with cyber_ui migration of controls.

### 2. Persistence: dedicated JSON, App-owned

**Choice:** `/var/lib/hmi/advanced-settings.json` via `AdvancedSettingsStore` (warm-read, soft-fail defaults). Keys mirror lws-ui field names:

- AI: `lensContaminationDetectionEnabled` (default true), `zeroPointOffsetDetectionEnabled` (default true)
- Dangerous: `keepLaserOnWhileAlarmed`, `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, `allowWorkAfterLensContamination`, `allowWorkAfterFeederAlarm` (all default false)

Numeric thresholds MAY live in the same file as cache of last-written values and/or be mirrored from Modbus attribute reads when available.

**Alternatives:** Misc JSON — rejected (wrong domain). SQLite Room — rejected for HMI Linux prefs pattern.

### 3. Control/call model for AI Assistance

```
AdvancedSettingsStore / AiAssistanceFacade
        │
        ├─► StreamDetect / stain / zero-point App coordinators (when present)
        │      early-return if disabled
        ├─► Optional daemon/config push (if HMI has AI daemon bridge)
        └─► UI switch only updates store (no Modbus)
```

- **Lens OFF** → live weld lens contamination path MUST NOT run; clear pending L001 production alert when appropriate (parity with lws-ui).
- **Zero-point OFF** → production laser-on zero-point rounds MUST NOT start; Manual Auto from Advanced Settings remains available.
- Readers MUST use facade, not InheritedWidget UI state.

### 4. Control/call model for Dangerous Operations

```
AdvancedSettingsStore / DangerousOperationsFacade
        │
        ├─► Laser enable preflight (allow-* for A001/C002/L001/W001/W002)
        ├─► Runtime work interrupt (keepLaserOnWhileAlarmed bypasses all coded interrupts)
        ├─► Warn severity (bypass → INFO vs WARN) when warn presentation exists
        └─► Ready/LED indicators use allow-* only (ignore keepLaserOn)
```

Turning a bypass **OFF** while fault active SHOULD re-evaluate interrupt (parity: `LaserWorkGuard.evaluateAndInterruptIfNeeded`). If laser interrupt not yet migrated, facade + store still ship; interrupt task marked blocked on warn-alarm follow-up.

### 5. Thresholds (Offset / Power / Temperature)

**Choice:** Phase A — UI shells + local persist and/or attribute watch when ids exist. Phase B — write holding attributes via HAL. Do not block AI/dangerous on full Modbus map.

## Risks / Trade-offs

- **[Risk] Laser interrupt not ready** → Ship store + facade + unit tests for policy pure functions; wire UI now; gate runtime interrupt behind existing warn/laser capability.
- **[Risk] AI coordinators missing on HMI** → Facade still persists; StreamDetect consumers check facade when those modules land.
- **[Trade-off] Material list chrome remains** → Accept SettingsGroup Material card until Cyber list kit exists; switches must be Cyber.

## Migration Plan

1. Store + facades + unit tests for defaults and policy helpers.
2. Advanced tab UI (Cyber switches) for AI + Dangerous; section headers for thresholds.
3. Wire available consumers (warn severity / interrupt if present).
4. Threshold Modbus bind as attrs allow.
5. Device smoke: toggle persist across restart; AI OFF skips detect; dangerous OFF blocks enable when interrupt wired.

## Open Questions

1. Exact Cyber numeric control for thresholds (stepper vs dialog) — prefer Cyber IME numeric when ready.
2. Whether AI daemon IPC exists on HMI yet for `ai_assist_config` push.
