#!/bin/sh
# Drive ynh960 product Status LED + buzzer pads inactive (active-high → low).
# Used by hmi.service ExecStop and gpio-product-off.service at halt.
# Prefer gpioset (libgpiod tools); fall back to classic sysfs export.
set -u

# chip:offset or linux# — keep in sync with app/lws_hmi/assets/hal/gpio.json
# red gpiochip3:9 / 105; yellow chip3:10 / 106; green chip4:21 / 149; bell chip3:27 / 123

drive_gpioset() {
	command -v gpioset >/dev/null 2>&1 || return 1
	gpioset gpiochip3 9=0 10=0 27=0 2>/dev/null || true
	gpioset gpiochip4 21=0 2>/dev/null || true
	return 0
}

drive_sysfs_export() {
	# shellcheck disable=SC2043
	for n in 105 106 149 123; do
		if [ ! -e "/sys/class/gpio/gpio${n}" ]; then
			echo "$n" >/sys/class/gpio/export 2>/dev/null || continue
		fi
		echo out >"/sys/class/gpio/gpio${n}/direction" 2>/dev/null || true
		echo 0 >"/sys/class/gpio/gpio${n}/value" 2>/dev/null || true
	done
}

if ! drive_gpioset; then
	drive_sysfs_export
fi
exit 0
