## Why

lws-ui already ships **home-only bundled control-board firmware upgrade** (APK assets → Modbus transfer after operator confirm). lws-hmi has matching l10n strings and the Modbus `upgrade` register map, but no Flutter bootstrap, version gate, transfer state machine, or bundled `.bin` asset pipeline. Operators on Linux HMI therefore cannot refresh the control card from the product App without online product OTA (still deferred to P4). Dev/ops also need a host-side control-board-only flash path analogous to lws-ui `make sync-firmware`, without conflating it with OS `make upgrade`.

## What Changes

- Port lws-ui **内置控制板固件升级** into the Flutter HMI: discover bundled `LSW01H####S####.bin` under `assets/firmware/control-board/` (auto-select newest SW for matching HW), gate on live control HW/SW, prompt only on Product Home, then transfer via Modbus.
- Introduce a **typed firmware asset root** `app/lws_hmi/assets/firmware/<type>/`; this change only lands `control-board/` (leaves room for future sibling firmware types). Declared via parent `assets/firmware/` in `pubspec.yaml`. No repo-root mirror / sync script.
- CyberUI confirm / blocking progress / success / fail dialogs using existing `bundledFirmware*` l10n, with a **bounded dialog width** (not full-screen stretch).
- Modbus transfer aligned with lws-ui `ControllerUpgradeHandler`: contiguous FC16 frames (info ≈10 / data = header+CRC+reserved+payload only / end ≈14 words), **not** a full `upgrade` group rewrite. Adds `writeHoldingRegisters` on `cyber_hal` + App `ModbusRtuClient` for those frames; exclusive session pauses competing live poll.
- Confirm success semantics: prefer live HW/SW match after end; treat `0x1212` as success; tolerate brief `0x0202` before declaring fail; after successful end, confirm-wait expiry MAY count as success (boards often apply without latch).
- Host helper **`make upgrade-control-board`**: SSH-upload one selected control-board `.bin`, write `/run/hmi/upgrade-control-board.cmd`, App watcher starts the same Modbus path **without** Home confirm or same-version gate. Naming is a subset of the host `make upgrade` family but MUST remain control-board-only (no rootfs / boot / OEM / GPT / factory).
- In-app `FirmwareUpgradeCoordinator` so a future product OTA path cannot flash the control board concurrently; **do not** implement online zip OTA, Settings “Check for Updates”, cloud `command.check_update` / `command.update_system`, or host A/B rootfs OTA.
- Keep Device Information OTA footer unavailable/deferred; on success refresh displayed Firmware Version (`device.control_card_version`) when live Modbus data is available.
- Product Home re-evaluates when returning to Home (`RouteAware` / `appRouteObserver`) after Modbus + versions are ready, without blocking first paint.

## Capabilities

### New Capabilities

- `startup-bundled-firmware-upgrade`: Home-only detection; typed `assets/firmware/control-board/` packaging with newest-matching-HW auto-select; filename HW/SW gate; mandatory Home confirm; contiguous Modbus FC16 flash; confirm/progress/result UX (bounded dialog width); success refresh of control SW; mutual exclusion with a future in-app OTA firmware path; and explicit host operator helper `make upgrade-control-board` (no confirm / no version gate; control-board-only).

### Modified Capabilities

- `product-home-ui`: Product Home SHALL host the bundled-firmware check/prompt after Modbus + control versions are available (including re-check on return to Home), without blocking first paint or cold start, and without prompting on non-home routes.

## Impact

- `app/lws_hmi/` — `features/bundled_firmware/` (version gate, asset discovery, packet builder, Modbus upgrade handler, coordinator, Home bootstrap, Cyber dialogs, `/run/hmi/upgrade-control-board.cmd` watcher); `HomePage` + `appRouteObserver` wiring; `ModbusRtuClient.writeHoldingRegisters`.
- `packages/cyber_hal` — `ModbusHal.writeHoldingRegisters` for contiguous holding FC16 (product OTA frame lengths).
- Assets / build — `app/lws_hmi/assets/firmware/control-board/*.bin` + `pubspec.yaml` `assets/firmware/` entry for `make build-app`.
- Host tooling — `scripts/upgrade-control-board.sh`, Makefile / README / AGENTS.md `upgrade-control-board` target (subset of upgrade naming; not OS image stream).
- Modbus — existing `assets/hal/modbus.json` `upgrade` + `status` groups; transfer protocol as above.
- Explicitly **out of scope**: product/APK/rootfs OTA UI, Settings check-update client, cloud OTA commands, host SSH `make upgrade` for OS images, factory flash, other firmware types under `assets/firmware/` beyond `control-board/`, process-library bundled import, repo-wide Cyber dialog width refactor (only bundled-firmware dialogs constrained here).
