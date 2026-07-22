## Why

Pressing the machine e-stop physically de-energizes the laser and wire feeder, so their Modbus communication bits go active as a side effect of the intentional disconnect. The product must not treat that as a real fault: no warn popup and no history row for laser/wire-feeder comm alarms while e-stop is latched. lws-ui already clears those bits in convert; this HMI still forwards raw bits into the `cyber_alarm` path.

## What Changes

- While `machine.emergency_stop` is active, suppress **laser communication** (`alarm.laser_comm` → H022) and **wire feeder communication** (`alarm.wire_feeder_comm` → W001) on the **warn/alarm path only**: no rising-edge episode arming, no modal presentation, no historical log insert.
- When e-stop becomes active and either code was already armed, emit a synthetic clear (falling) so any open dialog / active episode for those codes tears down.
- When e-stop clears, resume normal edge behavior from live Modbus bits (a still-true bit may rise again as a real fault).
- Status checks (Alarm Information lights, boot self-check, other raw Modbus consumers) MUST keep observing the true Modbus bits — do not mask status UI.
- Do **not** change `packages/cyber_hal` Modbus decode, attribute ids, or `app/hmi/assets/hal/modbus.json`.
- Do **not** suppress other laser/wire-feeder alarm codes (e.g. H023+, W002, laser e-stop H029) or unrelated comm faults (gun, camera, C001).

## Capabilities

### New Capabilities
- `estop-comm-alarm-suppress`: Product policy that masks H022/W001 on the App alarm signal path while machine e-stop is active, matching lws-ui e-stop comm-bit reset semantics without mutating HAL reads.

### Modified Capabilities
- `cyber-alarm`: Clarify that product Modbus adapters MAY drop or rewrite signal edges before the coordinator when product safety/UI policy requires it; episode policy in the package stays transport-agnostic.

## Impact

- `app/hmi` warn stack: primarily `ModbusAlarmAttributeAdapter` (or a thin filter in front of `WarnAlarmCoordinator`) must watch `machine.emergency_stop` and gate H022/W001 **signal events only**.
- Alarm Information / Monitor live bits and other status checks continue to use raw attribute values from the same adapter monitor feed.
- `packages/cyber_alarm`, `packages/cyber_hal`, and `modbus.json` stay unchanged except optional wording in the `cyber-alarm` spec.
- Unit tests in `app/hmi` for e-stop rising/falling interaction with H022/W001.
