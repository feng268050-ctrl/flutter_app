## 1. Kernel / DTS unhog

- [ ] 1.1 Stop building `gpio_innohi.c` (`overlay/kernel/innohi/Makefile`); remove the `gpio-innohi` / `own-gpio` child hog for HAL pads (GPIO_4/5/7, BELL) so gpiod request is not EBUSY
- [ ] 1.2 Convert `USB_HOST_PWREN*` to standard DT `gpio-hog` (or regulator-gpio) output-high so host VBUS does not depend on `gpio_innohi`
- [ ] 1.3 Delete `gpio_innohi.c` (or leave a stub README note) once DTS no longer references `compatible = "gpio-innohi"`
- [ ] 1.4 Update `overlay/kernel/innohi/README.md` and pinmux ledger: product lines are gpiod; silk `GPIO_N` / WG_D0/D1 remain labels only

## 2. HAL / product catalog

- [ ] 2.1 Set `app/lws_hmi/assets/hal/gpio.json` document `backend` and chassis RGB / buzzer schemes to `gpiod` (keep label/path as comments/docs fields)
- [ ] 2.2 Adjust `packages/cyber_hal` tests that assume product default `sysfs_innohi`; keep a sysfs fixture for the generic backend
- [ ] 2.3 Confirm HMI can open `/dev/gpiochip*` (root or gpio group); document if udev is required

## 3. Halt / boot defaults

- [ ] 3.1 Drive Status LED / buzzer off on `hmi.service` stop (HAL dispose or ExecStop)
- [ ] 3.2 Add a shutdown/halt oneshot that `gpioset`s product LED/buzzer offsets low if HMI is already gone
- [ ] 3.3 Verify RGB defaults off at HMI start (Force Off) with no `gpio_innohi` default-value

## 4. Verify / docs

- [ ] 4.1 Device: `gpioinfo` shows HAL pads not kernel-hogged; `gpioset` toggles green; HMI Status LED works; `/sys/class/gpio_innohi` absent
- [ ] 4.2 Update `verify-env` / pinmux quick-check that still `ls /sys/class/gpio_innohi`
- [ ] 4.3 Rebuild: `make apply-overlay`, `FORCE_KERNEL_IMAGE=1 make build-kernel`, `make build-app`, `make push-app`, `make upgrade` (kernel+rootfs as needed)
