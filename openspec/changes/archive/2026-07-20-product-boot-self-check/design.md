## Context

lws-ui ships a mature **开机自检** (`BootSelfCheckCoordinator` / `Evaluator` / `Dialog` / `Settings` / `Gate`) documented in `lws-ui/openspec/specs/boot-self-check/spec.md`. It overlays Home once per process, walks nine Alarm-Information-aligned checks, and suppresses overlapping warn/camera monitors until done.

lws-hmi already has:
- Product Home as initial route (first-paint KPI)
- Monitor Alarm Information + `GunAlarmTelemetry` / Modbus attribute IDs
- Cyber dialog/overlay host with freeze/manual capture guidance for growing footers
- Prefs pattern (`SoundEffectStore` → `/var/lib/hmi/…`)
- Disabled Misc stub for “Show Startup Self-Check”

Gaps: no coordinator, no dialog pipeline, no camera ICMP helper, no persistence, no gate.

## Goals / Non-Goals

**Goals:**

- Behavioral parity with lws-ui boot self-check on Flutter-pi (trigger, items, statuses, Settings, don’t-show-again, auto-dismiss, gate).
- Preserve Home-first paint: self-check is a **post-frame overlay**, not a replacement `initialRoute`.
- Reuse CyberUI overlay + Modbus attribute semantics already used by Monitor.

**Non-Goals:**

- Porting Android Room / cloud `commonSettings.showBootSelfCheck` sync.
- Full `HomePromptQueue` (Wi‑Fi init, OTA, bind, lock prompts).
- Ground-lock Misc toggle.
- MediaMTX / video preview as part of camera check (ICMP only).
- Calling `verify-boot` / `verify-env` from the App.
- Perfect glyph-clip / live blur while the dialog body grows (use frozen/manual sample).

## Decisions

### 1. Overlay on Home, not a dedicated route

**Choice:** Keep `initialRoute = Home`. After first Home frame (and when enabled + not completed in-process), show a Cyber modal overlay.

**Alternatives:** `/self-check` as initial route — rejected (conflicts with `hmi-app-navigation` / first-paint KPI and differs from lws-ui).

### 2. Feature module layout

**Choice:** `app/hmi/lib/features/boot_self_check/` with:

| Piece | Role |
|-------|------|
| `boot_self_check_settings.dart` | Persist `show` bool (default **true**) at `/var/lib/hmi/boot-self-check` |
| `boot_self_check_gate.dart` | Process-wide `isActive` / `isCompletedInProcess` |
| `boot_self_check_item.dart` | Enum of 9 items + status enum |
| `boot_self_check_evaluator.dart` | Snapshot + per-item pass/fail/skip |
| `boot_self_check_coordinator.dart` | `startWhenHomeEntered`, pipeline, dismiss callbacks |
| `presentation/boot_self_check_dialog.dart` | Cyber overlay UI |

Mirror lws-ui naming where practical for cross-repo review.

### 3. Modbus evaluation strategy

**Choice:** Perform a **bounded blocking/async snapshot** of the attributes needed for the checklist (controller readiness + alarm bits + gun temp values), then evaluate items in order with min visible step (~50 ms) like lws-ui.

Controller ready ≈ valid device-type / equivalent catalog attribute (`deviceType > 0` parity). Map items to existing IDs:

1. Controller comm  
2. `alarm.laser_comm` (pump)  
3. `alarm.gun_comm`  
4. Driver temp alarm + temp value present  
5. Gun motor temp alarm + value  
6. Protective mirror temp alarm + value  
7. Collimator temp alarm + value  
8. `alarm.wire_feeder_comm`  
9. Camera ICMP  

**Skip rules (parity):** Modbus unavailable / host stub → Modbus items SKIPPED; controller not ready → later Modbus items SKIPPED; camera still runs when applicable.

**Alternatives:** Drive entirely from live `GunAlarmTelemetry` watches — rejected for first slice (async race vs synchronous dialog pacing); may share helpers later.

### 4. Camera ICMP

**Choice:** App helper (e.g. `Process.run` `ping -c 1 -W 1 <host>`) with host from board profile / product config key (e.g. `camera_ip` or `camera_host`).  

- Production board: always attempt (fail if host missing or ping fails).  
- Host/macOS / missing config: SKIPPED (document as host-dev behavior).

**Alternatives:** HTTP `GET /System/deviceinfo` — rejected (lws-ui explicitly ping-only). Defer camera item entirely — rejected (parity gap).

### 5. Dialog UX / Cyber blur

**Choice:** `CyberOverlayHost` / `showCyberDialog` with **firstFrame or manual re-sample after footer layout** so growing rows don’t drag realtime blur (plan §6.3.3 / lws-ui MANUAL capture). Rows: append Checking… then update Pass/Fail/Skipped. Footer: checkbox + Close; auto-dismiss **3 s** unless touched; scrim dismiss **off**.

### 6. Gate vs async monitors

**Choice:** While gate active, suppress product warn popups / camera-monitor start if those exist; after dismiss, clear gate and allow Monitor/Home telemetry as today. If warn popup pipeline is not yet ported, gate is still required API so later P4 warn work can honor it.

### 7. Settings wiring

**Choice:** Misc switch reads/writes `BootSelfCheckSettings`; “don’t show again” calls `setEnabled(false)` on dismiss. Toggle does **not** run the check immediately (lws-ui parity).

## Risks / Trade-offs

- **[Risk] Modbus snapshot slows Home feel** → Mitigation: start only after first frame; per-item timeouts (~3 s); skip when link down; never change initial route.  
- **[Risk] No camera IP in current board profile** → Mitigation: add optional binding; production without IP = FAIL (honest); host = SKIP.  
- **[Risk] Device-type attribute naming differs from Android `DeviceStatus.deviceType`** → Mitigation: map explicitly in evaluator + unit tests against catalog IDs.  
- **[Risk] Warn/camera monitors incomplete in HMI** → Mitigation: implement gate now; wire suppressors as those features land.  
- **[Trade-off] Sync-style pipeline on async Modbus HAL** → Prefer one-shot reads with timeout rather than inventing a second poller.

## Migration Plan

1. Land store + Settings switch (default on).  
2. Land evaluator + dialog + Home hook behind same pref.  
3. `make build-app` / `make push-app`; cold-start with Modbus attached and detached.  
4. Rollback: set pref off or revert App feature folder; no rootfs schema beyond a single prefs file on userdata.

## Open Questions

1. Exact board-profile key for camera host (confirm with product / lws-ui `DeviceModelConfig.getCameraIp()` source).  
2. Which Modbus attribute is the authoritative **deviceType > 0** stand-in in the current catalog (confirm during implement).  
3. Whether any deferred Home prompts exist yet that must wait on `onComplete` (likely none today).
