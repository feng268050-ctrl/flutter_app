## Why

Today’s `cyber_hal` GPIO stack is a thin **sysfs line** API (`GpioHal` / `GpioLine`) bound to Innohi `gpio_innohi` paths and classic `/sys/class/gpio` export fallbacks. That works for the three chassis indicator LEDs, but it does not model the usual appliance GPIO roles (status lights, buzzer, tactile keys, rotary encoder), cannot listen for edges cleanly, and is a poor fit for debounce / long-press. Linux GPIO character-device access via a Dart gpiod client (`flutter_gpiod`) gives edge events and chip/line addressing—while ynh960 still exposes product lines through **`/sys/class/gpio_innohi`** (owned by Innohi `own-gpio`). The portable device API must therefore support **both** `/dev/gpiochip*` and legacy sysfs class bindings, chosen per line in config.

## What Changes

- Evolve `hal/gpio` toward **use-case devices** (Status LED bank, Buzzer, Button with long-press, RotaryEncoder with debounce), keeping App LED **policy** in the product App.
- **All pin / path / chip maps live only in App-owned `gpio.json` (or profile-pointed asset).** HAL device types and channel ids are abstract; boards MAY enable fewer/more devices, different channel sets, different `/sys/class/…` paths, or gpiod chip/offset—by editing config, not by forking HAL Dart. Portable HAL MUST NOT hard-code ynh960 (or any board) GPIO numbers, Innohi labels, or sysfs paths.
- Add a Linux **gpiod** backend (`flutter_gpiod` → `/dev/gpiochip*`) for chip+offset bindings and edge-driven inputs.
- **Keep and formalize** the existing **sysfs** backend (`gpio_innohi` label/path, plus classic `/sys/class/gpio` fallback) so lines still claimed by `own-gpio` remain controllable without fighting the kernel hog.
- Config v2: each device/channel declares binding **scheme** + addressing; document-level defaults only—never baked pin tables in code.
- ynh960 example map (for the product `gpio.json` / docs only, not HAL constants): RGB `GPIO_5/4/7` ↔ gpiochip3:9 / 3:10 / 4:21; buzzer candidate `BELL` ↔ gpiochip3:27.
- **BREAKING** for App code that embeds sysfs paths or SoC numbers in Dart; migrate to device/channel ids resolved from `gpio.json`.

## Capabilities

### New Capabilities

- `hal-gpio-devices`: Use-case GPIO device APIs (StatusLed, Buzzer, Button, RotaryEncoder); device/channel inventory entirely config-driven (variable count and ids).
- `hal-gpio-gpiod-backend`: Dual Linux line backends—character-device gpiod **and** compatible `gpio_innohi`/sysfs—plus stub/sim; per-binding scheme selection and edge vs poll input rules.

### Modified Capabilities

- `hal-gpio-config`: Schema is the sole pin/path map; devices + per-line schemes (chip/offset **or** arbitrary sysfs path/label); capabilities expand beyond set/blink/read.
- `linux-gpio-rgb-led`: Indicator plumbing goes through Status LED HAL; ynh960 may keep `gpio_innohi` bindings while gpiod bindings remain valid alternatives when lines are free.
- `dart-hal`: `hal/gpio` described as device-oriented GPIO with dual Linux backends.

## Impact

- **Package:** `packages/cyber_hal` gpio module + `flutter_gpiod`; retain sysfs writers for Innohi class.
- **App:** `gpio.json` / `gpio.sim.json`, `GpioLedController` → Status LED; optional `panel_buzzer` from `BELL`.
- **DTS / docs:** Align with `overlay/kernel/rockchip/ynh960-own-gpio.dtsi` and `docs/ynh960-io-pinmux-ledger.md` (no required DTS change for dual-backend v1).
- **Rootfs:** `/dev/gpiochip*` access when using gpiod; sysfs path needs no new daemon.
- **Non-goals:** RGB policy; Modbus; encoder UI; removing `gpio_innohi` from the kernel; assuming all lines are free for gpiod while `own-gpio` hogs them.
