## Context

ynh960 product GPIO (side RGB, BELL, GPIO_1…8, USB_HOST_PWREN*) is claimed by `gpio_innohi` (`compatible = "gpio-innohi"`, `/sys/class/gpio_innohi/<label>`). The driver `gpiod_get`s each child and never releases them, so `flutter_gpiod` request of the same pad returns EBUSY. HAL already records chip/offset in `app/lws_hmi/assets/hal/gpio.json` but ships `backend` / `scheme` `sysfs_innohi`.

`gpio_innohi` also registers `syscore_ops.shutdown` that drives **every** hogged output low (LEDs off, and USB_HOST_PWREN* off). Removing the driver without a replacement drops that halt behavior.

This change is the kernel/userspace cutover the earlier `gpiod-gpio-hal` work explicitly deferred.

## Goals / Non-Goals

**Goals:**

- Product HAL lines (RGB + BELL at minimum) are requestable on `/dev/gpiochip*` without EBUSY.
- Shipping LWS `gpio.json` uses scheme `gpiod`.
- `gpio_innohi.c` is not in the universal Image after cutover.
- Board enable lines that HAL does not own (USB host VBUS PWREN) stay asserted without the Innohi class.
- Equivalent of “indicators off at halt” is preserved.
- Sysfs HAL backend remains for boards that still expose a `/sys/class/…` value node.

**Non-Goals:**

- AIC8800, Modbus, encoder/button hardware.
- Replacing `flutter_gpiod`.
- Using `/sys/class/leds` (`gpio-leds`) as the product LED API (still a vendor-style sysfs class, not gpiod).
- Changing App RGB policy.

## Decisions

### D0 — Userspace gpiod owns product lines; kernel does not hog them

**Choice:** Delete/stop building `gpio_innohi`. Do **not** replace product LEDs with DT `gpio-hog` or `gpio-leds` (both keep the line kernel-owned → EBUSY). Leave GPIO_4/5/7, BELL, and unused GPIO_* children **unclaimed**. HAL `gpiod` requests them when HMI starts and Force-Off on open (already specified).

**Alternatives:** `gpio-leds` — rejected (user asked for gpiod, not another `/sys/class`). Keep `gpio_innohi` and only flip JSON — rejected (lines stay hogged).

### D1 — Board enable lines use standard DT hog / regulator, not gpio_innohi

**Choice:** USB_HOST_PWREN{1,2,3} stay **kernel-owned** via `gpio-hog` (output-high) or an existing regulator/fixed-gpio binding so 1 mm host VBUS does not depend on the Innohi class. HAL MUST NOT request those offsets.

**Alternatives:** Leave PWREN floating — rejected (host ports die). Keep entire `gpio_innohi` just for PWREN — rejected (defeats cleanup).

### D2 — Halt: HMI releases then a shutdown helper drives product lines low

**Choice:** `hmi.service` ExecStop (or HAL dispose) drives Status LED / buzzer off and releases gpiod lines. A small oneshot on `shutdown.target` / `halt.target` then `gpioset`s the same chip/offset map (from a board file or reused gpio.json export) to output-low so a crashed HMI does not leave lamps on. PWREN hogs may stay high until the rail dies (acceptable vs gpio_innohi’s global pull-low).

**Alternatives:** Tiny syscore driver that only pulls LED pads — extra in-tree code for three GPIOs; skip unless halt helper proves racy. `gpio-leds` default-state=off — conflicts with D0.

### D3 — Product JSON default becomes `gpiod`; sysfs backend stays generic

**Choice:** `backend: "gpiod"` and per-channel `scheme: "gpiod"`. Keep `label` / `path` as documentation only (silk `GPIO_7`, historical sysfs). HAL sysfs writer still accepts any configured path; it MUST NOT assume `/sys/class/gpio_innohi` exists.

### D4 — Access

**Choice:** HMI already runs as root on the appliance; `/dev/gpiochip*` is usable. If a later non-root seat appears, add `gpio` group + udev — not a blocker for this change.

## Risks / Trade-offs

- [LEDs float between kernel init and HMI open] → pinctrl GPIO function + HAL Force-Off on start; accept brief undefined until HMI (today gpio_innohi sets default-value from DTS, overlay already `"0"` for RGB).
- [HMI crash leaves a lamp on until reboot] → shutdown oneshot `gpioset`; document residual if helper missing.
- [PWREN halt no longer goes low] → VBUS may stay until power cut; prefer hog high for runtime correctness.
- [Half-upgrade: new App + old Image] → gpiod EBUSY; keep sysfs fields in JSON unused; do not ship App-only without kernel.
- [Half-upgrade: new Image + old App] → sysfs class gone, old App writes missing nodes → dark LEDs. Ship kernel + App together (`build-kernel` + `build-app` / `push-app`).
- [GPIO_8 silk WG_D1 still looks like Wiegand] → pinmux ledger §2.1; no character device.

## Migration Plan

1. Implement kernel/DTS unhog + PWREN hog; `FORCE_KERNEL_IMAGE=1 make build-kernel`.
2. Flip `gpio.json` + HAL tests; `make build-app` / `push-app`.
3. Add halt helper if ExecStop alone is insufficient on device.
4. Delete `gpio_innohi.c` from `overlay/kernel/innohi/` (or stop `obj-y`).
5. Rollback: restore driver + `sysfs_innohi` JSON (A/B slot).

## Open Questions

- Exact DT syntax for PWREN (`gpio-hog` vs `regulator-gpio`) — pick whichever matches existing Rockchip USB VBUS enable on this tree.
- Whether GPIO_8 needs a HAL device or stays unused (unclaimed).
