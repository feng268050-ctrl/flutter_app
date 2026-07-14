## Context

P1 shipped flutter-pi + Hello World on ynh960; P1.5 added USB-SSH push/debug. Product I/O still lives in **lws-ui** (Android): Modbus RTU via `modbus4j` / serial, RGB side LEDs via **YNHAPI GPIO** (`GpioLedConfig` pins red=4, yellow=3, green=6; modes `STEADY_ON` / `BLINK` / `OFF` with 1 s on / 1 s off flash).

P2 ports the **Linux** half of that I/O into `app/hmi`, with a minimal demo UI for board bring-up. Wiring is owned by the integrator; software must match lws-ui logical pins and register contracts.

Known plan/doc errors corrected in this change: “Modbus-**MTU**” → **RTU**; LED “红/绿/**蓝**” → 红/**黄**/绿.

## Goals / Non-Goals

**Goals:**

- Linux Modbus RTU client on `/dev/ttyS5` with lws-ui register addresses for P2 device-info fields.
- Linux GPIO LED control for R/Y/G with Steady / Blink / Off, pins **4 / 3 / 6**.
- Flutter demo home: five `label: value` rows + three exclusive mode rows; failures show `-`.
- Correct misspellings when porting (`Filed`→`Field`, related identifier typos such as `Cersion`→`Version`).
- Keep startup light enough that first frame still appears without waiting on Modbus success.

**Non-Goals:**

- Android / emulator (P2.5).
- Production LED policy (`RgbLedDecision` / alarm-driven indicators).
- Camera Version, Process Library, OTA buttons, FrostUI.
- Full Modbus write/poll surface beyond what the demo needs to read (scaffold may hold register maps for later P5).

## Decisions

### D1 — App-layer Modbus in Dart, not a C daemon

**Choice:** Implement Modbus RTU in Flutter using `flutter_libserialport` + a small Dart protocol layer (read holding/input registers as lws-ui does), with register constants mirrored from lws-ui.

**Why:** Matches plan (`flutter_libserialport`); one codebase for P2.5 Android later; no new rootfs service.

**Alternatives:** libmodbus native + FFI (extra Buildroot churn for P2); external Python/C tool (worse for UI binding).

### D2 — Spelling fix at the Dart API boundary

**Choice:** New Dart types use correct English (`ModbusField`, `ModbusFieldBuilder`, `ModbusReadField`, …). Do **not** preserve `Filed` typos from Java. Register **numeric addresses and wire encoding** stay identical to lws-ui.

**Why:** User request; avoids carrying known bugs into the Linux mainline.

### D3 — Device SN from iSerial identity script, not Modbus / YNHAPI

**Choice:** Read Device SN via the same stable board serial used for USB gadget `iSerial` — invoke `/usr/bin/read-serial` (or read DT/`read-device-serial.sh` output) from Dart. On empty/error → `-` (not `unknown-sn`, so UI matches the stated failure display).

**Why:** User requirement; Aligns with existing `read-device-serial.sh` / USB-SSH SERIAL selection. Android YNHAPI `getSerialNo()` is P2.5.

### D4 — Firmware Version register

**Choice:** Map **Firmware Version** to control-card software version register `DeviceStatusRegisterAddress.DEVICE_SOFTWARE_VERSION` (`0x0002`), same as lws-ui Device Information “Firmware Version”. Other Modbus fields use `DeviceInfoRegisterAddress` block (`0x0030`–`0x0039`) with the same hex-string formatting as `ModbusFieldConvert.deviceInfoConvert`.

### D5 — GPIO backend preference

**Choice:** Prefer Innohi **own-gpio** (or vendor path) that accepts the **same pin indices 3/4/6** as Android YNHAPI. If that node is unavailable or conflicted (see `docs/kernel-evb-dts-deferred.md`), fall back to documented sysfs/`libgpiod` mapping behind a single `GpioLedController` interface — pin numbers in App config remain 4/3/6.

**Why:** Product continuity with lws-ui; isolate SoC line-number churn behind one adapter.

**Blink:** Match lws-ui: 1000 ms HIGH / 1000 ms LOW on a dedicated async task per color; cancel on mode change.

### D6 — UI: exclusive mode per color row

**Choice:** Three rows (Red / Yellow / Green). Each row is a **segmented exclusive group**: Steady | Blink | Off. Selecting one mode deselects the other two **for that row only** (colors independent). Initial selection: **Off** for all (safe for bring-up; differs from Android production default green-on).

**Why:** Matches user request; avoids accidental multi-mode / flash races.

### D7 — Demo vs Hello World acceptance

**Choice:** Replace Hello World body with P2 demo; keep `app/hmi` path, overlay `/opt/hmi`, and `hmi.service` orientation. Defer Modbus open / first poll until after first frame (post-frame callback or short idle) so boot KPI path remains valid.

### D8 — Permissions

**Choice:** Ensure `hmi.service` (or supplementary group) can open `/dev/ttyS5` and the chosen GPIO device (udev/group or existing root `hmi` unit). Prefer minimal overlay/udev change over relaxing whole rootfs.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| `own-gpio` pinmux conflict with Ethernet (`gpio4-0`) | Adapter fallback + kernel note; demo can still build; LED verify waits on wiring/kernel fix |
| Modbus no slave during development | UI shows `-`; log serial/CRC errors; no crash |
| `flutter_libserialport` + flutter-pi ABI quirks | Pin package versions to Flutter 3.24.4; smoke on device early |
| Blink timers vs hot restart | Cancel timers in dispose; document `make push-app` restart behavior |
| Spelling renames confuse dual-repo mental model | Spec + short mapping table in design (Filed→Field); Java lws-ui unchanged |

## Migration Plan

1. Land Dart Modbus/GPIO libraries + demo UI behind `make build-app` / `push-app`.
2. Apply overlay permissions if needed → `build-rootfs` / `build-img` / `flash` when platform bits change.
3. Integrator wires Modbus + LEDs and runs smoke (read fields ≠ `-` when slave up; each LED mode visibly correct).
4. Rollback: previous `/opt/hmi` bundle via prior image or push older build; no DB migrations.

## Open Questions

1. Exact Linux device node for vendor GPIO (sysfs path vs char-dev) on current ynh960 DTS — resolve during implementation by probing hardware / Innohi docs; App pin API stays 4/3/6.
2. Serial parameters (baud/parity/stop) — copy from lws-ui Modbus RTU config at implementation time; document in code comments next to port open.
