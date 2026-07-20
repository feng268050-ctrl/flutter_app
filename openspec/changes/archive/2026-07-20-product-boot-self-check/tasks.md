## 1. Prefs + Settings wiring

- [x] 1.1 Add `BootSelfCheckSettings` store (default enabled) at `/var/lib/hmi/boot-self-check` with warm-read + unit tests
- [x] 1.2 Wire Common Settings → Misc “Show Startup Self-Check” to the store (remove stub / `onChanged: null`)
- [x] 1.3 Expose store via a small scope or App bootstrap (mirror `SoundEffectStore` pattern)

## 2. Domain + evaluator

- [x] 2.1 Add `BootSelfCheckItem` / `BootSelfCheckStatus` enums and label helpers aligned with Alarm Information
- [x] 2.2 Implement `BootSelfCheckEvaluator` (controller ready via `device.type`, alarm/temp semantics, skip rules)
- [x] 2.3 Implement Modbus snapshot helper with per-read timeout (~3s) using existing HAL/App Modbus APIs
- [x] 2.4 Add camera ICMP helper + optional board-profile / config host key; host-missing policy per design
- [x] 2.5 Unit-test evaluator skip/pass/fail matrix (no hardware required)

## 3. Gate + coordinator

- [x] 3.1 Add `BootSelfCheckGate` (`isActive`, `isCompletedInProcess`, reset hooks for tests)
- [x] 3.2 Implement `BootSelfCheckCoordinator.startWhenHomeEntered` (enabled check, one-per-process, pipeline pacing ~50ms min step)
- [x] 3.3 On complete/dismiss: clear gate, honor “don’t show again”, invoke optional `onComplete`

## 4. Dialog UI (Cyber)

- [x] 4.1 Build `BootSelfCheckDialog` overlay using Cyber dialog/overlay host with frozen/manual blur for growing body
- [x] 4.2 Incremental rows (checking → pass/fail/skipped) + footer (don’t show again + Close)
- [x] 4.3 Auto-dismiss after 3s; disable scrim dismiss; cancel auto-dismiss on operator interaction

## 5. Home integration

- [x] 5.1 Hook first Home entry (post-frame) to start coordinator without blocking first paint
- [x] 5.2 Confirm `initialRoute` remains Home; no `/self-check` initial route
- [x] 5.3 Stub or wire gate consumers if warn/camera monitors already exist; otherwise document gate for later use

## 6. Verification

- [x] 6.1 `flutter analyze` + unit tests for store/evaluator under `app/hmi/`
- [x] 6.2 Widget/nav smoke: Home paints with self-check overlay path (pref on/off)
- [x] 6.3 Device: `make build-app` + `make push-app`; cold start with Modbus attached and detached; toggle Misc + don’t-show-again
