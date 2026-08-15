## 1. Kernel / DTS unhog

- [x] 1.1 Stop building `gpio_innohi`; disable `own-gpio` hog for HAL pads (GPIO_4/5/7, BELL) **and** GPIO_8 (silk WG_D1); do not reintroduce Wiegand chardev
- [x] 1.2 Convert `USB_HOST_PWREN*` to standard DT `gpio-hog` (or regulator-gpio) output-high so host VBUS does not depend on `gpio_innohi`
- [x] 1.3 Delete `overlay/kernel/innohi/`; apply-overlay strips owned `source "innohi/Kconfig"` / `drivers-y := innohi/` (no stub tree)
- [x] 1.4 Update pinmux ledger + kernel READMEs: product lines are gpiod; silk WG_D0/D1 = GPIO_7 (green LED) / GPIO_8 (unclaimed spare); no `/dev/wiegand_*`

## 2. HAL / product catalog

- [x] 2.1 Set `app/lws_hmi/assets/hal/gpio.json` document `backend` and chassis RGB / buzzer schemes to `gpiod` (keep label/path as comments/docs fields)
- [x] 2.2 Adjust `packages/cyber_hal` tests that assume product default `sysfs_innohi`; keep a sysfs fixture for the generic backend
- [x] 2.3 Confirm HMI can open `/dev/gpiochip*` (root or gpio group); document if udev is required

## 3. Halt / boot defaults

- [x] 3.1 Drive Status LED / buzzer off on `hmi.service` stop (HAL dispose or ExecStop)
- [x] 3.2 Add a shutdown/halt oneshot that `gpioset`s product LED/buzzer offsets low if HMI is already gone
- [x] 3.3 Verify RGB defaults off at HMI start (Force Off) with no `gpio_innohi` default-value

## 4. Verify / docs

- [x] 4.1 Device smoke: `gpio_innohi` absent; PWREN hogged; HMI `cyber_hal:chassis_rg` on 105/106/149; `verify-env` / `verify-boot` ALL PASS; libgpiod tools (`gpioset`/`gpioinfo`/`gpioget`) present after rootfs bake
- [x] 4.2 Update `verify-env` / pinmux quick-check that still `ls /sys/class/gpio_innohi`
- [x] 4.3 Bake `libgpiod` tools (`BR2_PACKAGE_LIBGPIOD_TOOLS` in platform + prebuilt fragment); on-device smoke confirms all six CLI tools
