## 1. Dependencies and package skeleton

- [x] 1.1 Add `flutter_gpiod` dependency to `packages/cyber_hal/pubspec.yaml` and resolve/lock
- [x] 1.2 Sketch public exports in `lib/gpio.dart` for StatusLedBank, Buzzer, GpioButton, RotaryEncoder (+ event types) without breaking existing imports yet
- [x] 1.3 Document dual backends (`gpiod` + `sysfs_innohi`) + stub selection in package README gpio section
- [x] 1.4 Ensure no ynh960/SoC pin, `GPIO_N`, or `/sys/class/gpio_innohi/…` literals are introduced as runtime maps in `packages/cyber_hal/lib/**` (fixtures/tests/docs only)

## 2. Config schema v2 + v1 adapter

- [x] 2.1 Extend `GpioConfig` parsing for `version: 2`, `devices[]`, variable channel/device lists, per-binding `scheme`, chip/offset **and** arbitrary sysfs label/path, device capability flags
- [x] 2.2 Implement v1 `lines[]` → synthetic `status_led` bank adapter for existing `led_red` / `led_yellow` / `led_green`
- [x] 2.3 Add golden/unit tests for v1 and v2 fixtures: dual addressing, fewer/more channels, omitted buzzer, alternate sysfs path
- [x] 2.4 Add a test that a minimal config with one LED channel and no buzzer does not touch default pin constants

## 3. Dual line backends

- [x] 3.1 Implement shared logical-line interface dispatched by `scheme`
- [x] 3.2 Implement `sysfs_innohi` set/get (preserve current path/label behavior + classic export fallback)
- [x] 3.3 Implement `gpiod` chip resolve + line request/release via `flutter_gpiod` (set/get, `active_low`)
- [x] 3.4 Implement gpiod edge subscription helper; sysfs debounced poll helper for inputs
- [x] 3.5 Implement in-memory stub line/device backend for host tests
- [x] 3.6 On gpiod `EBUSY` / request failure, raise structured error (no silent sysfs fight)

## 4. Status LED bank

- [x] 4.1 Implement `StatusLedBank` Off / Steady / Blink with config blink timings on logical lines
- [x] 4.2 Preserve same-mode Blink no-op and `force` Off rewrite behavior
- [x] 4.3 Wire level listeners for App overlay parity with current `GpioLevelListener`
- [x] 4.4 Unit tests for independent channels + blink idempotency (stub + sysfs-shaped fixtures)

## 5. Buzzer, button, rotary encoder

- [x] 5.1 Implement `Buzzer` on/off + finite beep/pattern cancel
- [x] 5.2 Implement `GpioButton` debounce + long-press (edges on gpiod; poll on sysfs)
- [x] 5.3 Implement `RotaryEncoder` quadrature decode + debounce (+ optional direction invert); prefer gpiod scheme
- [x] 5.4 Unit tests with stub edge/poll injection for short/long press and CW/CCW / bounce suppression

## 6. GpioHal façade

- [x] 6.1 Add device open APIs on `GpioHal` (`openStatusLed` / `openBuzzer` / `openButton` / `openEncoder` or equivalent)
- [x] 6.2 Route each binding to gpiod, sysfs_innohi, or stub per scheme / defaults
- [x] 6.3 Keep temporary `openLine` for migration or mark deprecated once LED consumers moved
- [x] 6.4 Dispose releases gpiod lines, cancels timers/subscriptions, and drops sysfs handles

## 7. Product App config and consumers

- [x] 7.1 Update `app/lws_hmi/assets/hal/gpio.json` to v2: RGB via `sysfs_innohi` (`GPIO_5/4/7`) with recorded gpiod map (chip3:9 / chip3:10 / chip4:21)
- [x] 7.2 Add `panel_buzzer` from `BELL` (confirm sysfs node name on device); record gpiod chip3:27
- [x] 7.3 Update `gpio.sim.json` for stub/sim Status LED (+ optional buzzer)
- [x] 7.4 Migrate `GpioLedController` to Status LED bank API; keep public LedColor / IndicatorMode surface
- [x] 7.5 Fix App gpio tests (controller, pin map / golden) for new config shape

## 8. Bring-up

- [x] 8.1 Ensure `/dev/gpiochip*` access when scheme is gpiod (udev/group or document root)
- [x] 8.2 On-device smoke: RGB Steady/Blink/Off via Status LED on sysfs scheme; optional gpiod attempt only if line free
- [x] 8.3 On-device smoke: BELL beep if present; leave button/encoder config out until pads known

## 9. Docs and verification

- [x] 9.1 Update `packages/cyber_hal/README.md` and cross-link `docs/ynh960-io-pinmux-ledger.md` for dual backend + pin table
- [x] 9.2 Do **not** remove sysfs backend as part of this change’s done criteria
- [x] 9.3 Run `flutter analyze` / package tests for `cyber_hal` and affected `lws_hmi` tests
