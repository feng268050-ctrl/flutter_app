## Why

Product GPIO on ynh960 is still claimed by the vendor `gpio_innohi` driver (`/sys/class/gpio_innohi`), which **hogs** the same pads HAL already maps for gpiod (`gpiochip` + offset). Userspace `flutter_gpiod` therefore gets EBUSY unless it stays on the Innohi sysfs class. Clearing Innohi-specific kernel cargo means those lines should be ordinary Linux GPIO, addressed with modern gpiod—not a private sysfs class.

## What Changes

- Stop building/shipping `overlay/kernel/innohi/gpio_innohi.c` once lines are free. Unbind/`own-gpio` hogging so `/dev/gpiochip*` request succeeds for product LEDs, buzzer, and GPIO_8.
- Switch the LWS product `gpio.json` **runtime** scheme from `sysfs_innohi` to `gpiod` using the already-recorded chip/offset map (red `gpiochip3:9`, yellow `gpiochip3:10`, green `gpiochip4:21`, buzzer `gpiochip3:27`).
- Preserve boot-off defaults and **shutdown pull-low** currently done by `gpio_innohi` `syscore_ops.shutdown` (all hogged outputs driven 0). Kernel `gpio-leds` and/or a small userspace/systemd helper MAY own that; do not drop the behavior silently.
- Keep HAL **sysfs** backend as a generic path/label writer for other boards; it MUST NOT depend on `/sys/class/gpio_innohi` existing.
- **BREAKING:** `/sys/class/gpio_innohi/<label>/value` goes away on boards that complete the cutover. Shell/debug that still `echo` those nodes must use gpiod (`gpioset`/`gpioinfo`) or HAL.

## Capabilities

### New Capabilities

- `linux-gpio-line-ownership`: Kernel/DTS ownership of product GPIO pads—lines free for character-device gpiod (or standard `gpio-leds`); no Innohi sysfs class hog; shutdown-low equivalent.

### Modified Capabilities

- `linux-gpio-rgb-led`: Product RGB bindings are **gpiod** (chip/offset) as the shipping scheme; `GPIO_N` names remain DTS/silk identifiers only, not a required sysfs class.
- `hal-gpio-gpiod-backend`: Product Linux default is gpiod; `sysfs_innohi` is optional fallback when a board still exposes a sysfs class, not a ynh960 precondition. HAL MUST NOT require `gpio_innohi` to ship the device API.
- `hal-gpio-config`: Shipping LWS `gpio.json` document default / channel schemes SHALL be `gpiod` after cutover.
- `dart-hal`: Linux board GPIO described as gpiod-first; Innohi sysfs class is legacy, not the long-term path.

## Impact

- **Kernel:** `overlay/kernel/innohi/gpio_innohi.c` + `own-gpio` / `gpio-innohi` DTS; rebuild Image (`FORCE_KERNEL_IMAGE=1`).
- **HAL / App:** `packages/cyber_hal` already has gpiod; `app/lws_hmi/assets/hal/gpio.json` scheme flip; tests that assume sysfs_innohi as product default.
- **Docs / verify:** `docs/ynh960-io-pinmux-ledger.md`, `verify-env` / board helpers that `ls /sys/class/gpio_innohi`.
- **Rootfs:** HMI (or a gpio group) must open `/dev/gpiochip*`; no new daemon required if userspace holds lines.
- **Non-goals:** AIC8800; encoder/button hardware that is not on the board; replacing `flutter_gpiod`.
