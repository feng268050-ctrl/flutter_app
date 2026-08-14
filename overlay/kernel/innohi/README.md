# `overlay/kernel/innohi/`

Thin leftover of the old vendor `kernel/innohi/` tree. **Not** a second kernel Image.

| Keep | Role |
|------|------|
| `gpio_innohi.c` | `/sys/class/gpio_innohi` (product LEDs / BELL). Planned: gpiod — see OpenSpec `gpio-innohi-to-gpiod`. |

Removed (dead / unused / not on ynh960):

- MCU (`mcu_s105`, `mcu_wdt`) — no DTS node on ynh960
- Wiegand D0/D1 character devices — pads are **GPIO_7 / GPIO_8** (silkscreen still WG_D0 / WG_D1)
- `atsh204a/` — vendor ioctl shim (`tmel_drive.c`, compatible `enc-atsh204a`); **not** the public Atmel/Linux `atmel,atsha204a` driver. ynh960 has no DT node and no I2C 0x64
- Unused forks: `input/` (gt9xx / gpio_keyboard), `video/` (LT8911 / GM8775), `power/` (fuel gauge)
- Kitchen-sink `net/` Wi‑Fi trees (never in git; AIC8800 is a separate combo driver)

Do **not** re-import the vendor kitchen sink via `scripts/import-vendor-kernel-from-sdk.sh` without updating its excludes.
