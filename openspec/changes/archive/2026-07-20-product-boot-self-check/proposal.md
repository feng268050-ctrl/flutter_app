## Why

lws-ui runs a **开机自检** (boot self-check) once per process on first Home entry: a Frost dialog that walks Monitor→Alarm Information Modbus checks plus camera ICMP, with Settings / “don’t show again” to disable future runs. lws-hmi only has a disabled Misc stub (“Show Startup Self-Check”), so operators lose that first-boot confidence loop after migrating to Flutter-pi.

## What Changes

- Add a **product boot self-check** pipeline matching lws-ui behavior: one-per-process Cyber dialog over Home, incremental checking→pass/fail/skip rows, footer with “don’t show again” + Close, 3s auto-dismiss.
- Evaluate the same **nine items** (controller / pump / gun / temps / wire feeder / camera ICMP) using existing Modbus attribute semantics and a bounded camera ping.
- Persist the enable flag under `/var/lib/hmi/` (like sound-effect) and wire the Common Settings Misc switch.
- Gate overlapping async warn/camera monitors while the check is active (parity with `BootSelfCheckGate`), without blocking Home first paint or changing the initial route away from Home.
- **Out of scope:** Ground-lock alarm toggle; full HomePromptQueue (Wi‑Fi/OTA/bind prompts); MediaMTX preview; replacing `verify-boot` / `verify-env` operator scripts; CyberIME.

## Capabilities

### New Capabilities

- `product-boot-self-check`: Once-per-process Home overlay self-check dialog, item pipeline, gate/suppress rules, Settings persistence, camera ICMP check.

### Modified Capabilities

- `settings-ui`: Wire Misc “Show Startup Self-Check” to a real persisted preference (no longer a dead stub).
- `product-home-ui`: First Home entry MAY overlay boot self-check without delaying Home first paint or changing initial route.
- `linux-settings-persist`: Document the boot-self-check preference path under `/var/lib/hmi/`.
- `hmi-app-navigation`: Clarify that initial route remains Home; self-check is an overlay, not a replacement route (unless explicitly documented otherwise).

## Impact

- **App:** new `features/boot_self_check/` (coordinator, evaluator, dialog UI, settings store); `HomePage` / `LwsHmiApp` hooks; `common_settings_tab.dart` Misc switch; optional board-profile / config key for camera host IP.
- **cyber_ui:** reuse `CyberOverlayHost` / dialog freeze capture for growing footer (plan §6.3.3).
- **cyber_hal / Modbus:** synchronous or short-lived attribute reads for the checklist (respect existing serial spacing); no new RTU protocol.
- **Tests:** unit tests for evaluator + store; widget/nav smoke that Home still paints first.
- **OpenSpec:** new main capability after archive; Settings/Home/persist/nav deltas as above.
