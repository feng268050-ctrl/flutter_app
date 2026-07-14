## 1. Docs & scaffolding

- [x] 1.1 Confirm plan doc corrections already applied (`Modbus RTU`, 红/黄/绿) and note OpenSpec change path in any P2 checklist cross-links if needed
- [x] 1.2 Add `flutter_libserialport` (and any GPIO-related deps) to `app/hmi/pubspec.yaml`; run `flutter pub get` under pinned Flutter SDK
- [x] 1.3 Create Dart package layout under `app/hmi/lib/` for `modbus/`, `gpio/`, `device/`, and `ui/demo/`

## 2. Device SN (iSerial)

- [x] 2.1 Implement Device SN reader that invokes `/usr/bin/read-serial` (or equivalent overlay helper) and returns trimmed serial
- [x] 2.2 Map empty / error / non-zero exit to display value `-`

## 3. Linux Modbus RTU

- [x] 3.1 Port register address constants from lws-ui (`0x0002`, `0x0030`–`0x0039` as needed) into correctly spelled Dart names (`…Field…`, not `Filed`)
- [x] 3.2 Implement serial open on `/dev/ttyS5` with lws-ui-matching baud/parity/stop; soft-fail when port missing
- [x] 3.3 Implement RTU read path for Firmware Version, Laser Version, Wire Feeder Version, Gunhead SN with lws-ui formatting
- [x] 3.4 Ensure Modbus init/poll starts only after first frame (or async post-frame); failures yield `-` without crashing

## 4. Linux GPIO RGB LED

- [x] 4.1 Implement `GpioLedConfig` pins red=5, yellow=4, green=7 and `IndicatorMode` Steady / Blink / Off
- [x] 4.2 Probe and bind vendor `own-gpio` (preferred) or sysfs/`libgpiod` fallback behind one controller API
- [x] 4.3 Implement Blink as 1000 ms on / 1000 ms off with cancel-on-mode-change; colors independent
- [x] 4.4 Ensure `hmi.service` / udev permissions can access serial + GPIO; add minimal overlay rules if required

## 5. P2 demo UI

- [x] 5.1 Replace Hello World home with five `label: value` rows (Device SN, Gunhead SN, Firmware Version, Laser Version, Wire Feeder Version)
- [x] 5.2 Add three exclusive control rows (Red / Yellow / Green) each with Steady | Blink | Off; default Off
- [x] 5.3 Wire UI to Device SN reader, Modbus field refresh, and GPIO mode API
- [x] 5.4 Run `flutter analyze` (and lightweight widget/unit tests where practical for formatters / mode exclusivity)

## 6. Build, deploy, smoke

- [x] 6.1 `make build-app` (and `make apply-overlay` / `build-rootfs` / `build-img` if overlay permissions changed)
- [ ] 6.2 Deploy via `make push-app` or flash; verify demo paints without Modbus slave (dashes + LED UI) — **blocked: no USB-SSH device connected**
- [ ] 6.3 After integrator wiring: smoke Modbus fields non-dash and each LED Steady / Blink / Off on hardware — **awaiting user wiring**
- [x] 6.4 Document serial params, GPIO backend chosen, and any DTS caveats in change notes or brief app README section
