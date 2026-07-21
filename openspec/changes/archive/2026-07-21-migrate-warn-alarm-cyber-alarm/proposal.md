## Why

Monitor Alarm Information already shows live temperatures, comm lights, and an active-alarm list from HAL `alarm.*` attributes, but the product **warn system** from lws-ui (episode policy, modal presentation, historical alarm log, optional laser interrupt) is not migrated. Operators still lack the actionable warn path that Android HMI provides. This change introduces that behavior as a shared **`packages/cyber_alarm`** product-domain layer (5th stack layer), keeping HAL as a pure attribute/health source and CyberUI as chrome only.

## What Changes

- Add **`packages/cyber_alarm`**: reusable warn/alarm domain (catalog structure, episode policy, presentation ports, history repository ports) that Apps wire to HAL and CyberUI — **no** warn dialogs, episode state, or alarm-code policy inside `cyber_hal`; **no** episode state machine inside Monitor widgets or `cyber_ui`.
- Product App maps decoded `alarm.*` booleans (+ `meta.alarm_code`) onto `cyber_alarm` signal ports and presents CyberUI warn dialogs through a process-wide presentation host that implements `cyber_alarm` ports.
- Persist **historical Alarm Logs** (rising-edge episodes) via an App-owned store implementing the package repository port; Clear affects history only.
- Gate overlapping warn presentation during boot self-check (align with existing self-check specs).
- Keep Monitor Indicator semantics unchanged (run tiles Dot vs alarm Icon); do not conflate status lights with warn episodes.
- **Out of scope for this change (follow-up):** non-Modbus sources (camera C002, lens L001, zero-point H034) and laser enable interrupt — may plug into the same `cyber_alarm` ports later without redesigning HAL.

## Stack (5 layers)

```text
1. Product App      app/hmi/           wiring, locale, Modbus/camera adapters, store impl, host
2. cyber_alarm      packages/          episode engine, policy, catalog model, ports
3. CyberUI / IME    cyber_ui + ime     dialog chrome / overlay (no business policy)
4. cyber_hal        packages/          alarm.* attributes + health (+ optional remind kind)
5. OS / board       systemd · sysfs · BlueZ · serial …
```

## Capabilities

### New Capabilities
- `cyber-alarm`: Shared warn/alarm package — code catalog model, episode lifecycle, dialog presentation ports, historical log ports; transport- and chrome-agnostic. Product Apps supply adapters and UI host implementations.

### Modified Capabilities
- `product-monitor-ui`: Alarm Logs panel becomes real history (+ Clear); live active list remains; warn dialogs remain owned by App host backed by `cyber_alarm` (not Monitor-local forks).
- `product-boot-self-check`: Explicit requirement that warn presentation (via `cyber_alarm` + App host) is suppressed while self-check is active.
- `hal-modbus-config`: Clarify non-goals — HAL MUST NOT own warn dialogs/episodes; optional remind remains attribute-change kind only for App/`cyber_alarm` consumption.

## Impact

- **Package (`packages/cyber_alarm`)**: new path package (pure Dart preferred; no Flutter/HAL hard dependency for domain + ports).
- **App (`app/hmi`)**: depends on `cyber_alarm`; thin adapters (Modbus → `AlarmSignalSource`), CyberUI `WarnPresentation` host, local history store, boot `WarnGate`, Monitor history wiring, product catalog seed/locale.
- **HAL (`packages/cyber_hal`)**: no behavioral ownership of warn UI; may only continue exposing attributes/health/remind as today.
- **CyberUI (`packages/cyber_ui`)**: chrome only (existing dialog/overlay); no episode policy.
- **Assets**: `modbus.json` meta (`alarm_code` / `label`) remains the bridge; product catalog (seeded in App, structured by `cyber_alarm`) owns severity and dialog copy keys.
- **Does not** require changes to Machine Status Dot/Idle mapping or Alarm Information Icon Success/Failure/Idle indicator rules beyond documenting that lights ≠ episodes.
