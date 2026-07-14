## Why

P1 / P1.5 delivered a bootable flutter-pi HMI and device-side debug loop, but product I/O is still missing: the board cannot yet prove **Modbus RTU** access to the lower computer or **side-panel RGB GPIO** control on Linux. **P2** closes that gap on ynh960 so later phases (P2.5 Android dual-target, P5 business Modbus) can reuse a verified Linux stack instead of inventing one under schedule pressure.

## What Changes

- Migrate **Modbus RTU** from lws-ui (historically labeled “Modbus-MTU” in plans) onto Flutter/`flutter_libserialport` for Linux **`/dev/ttyS5`**, keeping the **lws-ui register contract**; rename misspelled types/identifiers during migration (`Filed` → `Field`, plan wording `MTU` → `RTU`).
- Migrate **GPIO RGB indicator** control to Linux (sysfs / gpiod / Innohi `own-gpio` as available), using the **same abstract pin numbers as lws-ui** (`GpioLedConfig`: red=4, yellow=3, green=6) and the same modes (**STEADY_ON / BLINK / OFF**).
- Replace the P1 Hello World home with a **P2 demo UI**: simple `label: value` Device Information rows plus **three mutual-exclusive LED control rows** (one per color × Steady / Blink / Off).
- Device Information fields for this demo:
  - **Device SN** — from board **iSerial** identity (same source as USB gadget `iSerial` / `read-device-serial.sh`), **not** Modbus
  - **Gunhead SN**, **Firmware Version**, **Laser Version**, **Wire Feeder Version** — from Modbus (lws-ui register mapping)
  - Missing / failed values display **`-`**
- Correct `docs/flutter-pi-hmi-plan.md`: tri-color LEDs are **红/黄/绿** (not 蓝); “Modbus-MTU” → **Modbus RTU**.

**Non-goals (P2)**: Android APK / emulator (P2.5); FrostUI/IME; camera version / eth0; OTA / Check Update; full business Modbus polling beyond device-info reads needed for demo; quantity business LED policy (`RgbLedDecision`) beyond manual test modes.

## Capabilities

### New Capabilities

- `linux-modbus-rtu`: Linux Modbus RTU client over `/dev/ttyS5` with lws-ui register parity (device-info reads for P2 demo; spelling-corrected Dart types).
- `linux-gpio-rgb-led`: Linux GPIO driver for side-panel R/Y/G indicators (pins 4/3/6), modes Steady / Blink / Off.
- `p2-device-demo-ui`: Flutter home demo listing the five device-info rows and three exclusive LED mode rows.

### Modified Capabilities

- `flutter-hello-world-app`: Home screen acceptance shifts from “Hello, World!” text to the P2 device-info + LED demo (same `/opt/hmi` deployment layout).

## Impact

- **App** (`app/hmi/`): new Modbus/GPIO Dart modules, pubspec deps (`flutter_libserialport` and any GPIO helper), home UI rewrite.
- **Rootfs / platform**: serial device permissions for HMI user/`hmi.service`; GPIO export/access path; optional Buildroot fragment enables if needed (libgpiod / udev rules).
- **Docs**: `docs/flutter-pi-hmi-plan.md` P2 wording (RTU, 绿 not 蓝); register-contract notes as needed under change design/spec.
- **Downstream**: P2.5 ports the same App abstractions to Android (`YBHAPI`); P5 expands Modbus beyond demo reads.
- **Hardware**: wiring and board bring-up are owned by the integrator; software exposes the same logical pins/modes as lws-ui.
