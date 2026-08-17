#!/bin/sh
# Drive product Status LED / OUT pads inactive (active-high → low).
# Used by hmi.service ExecStop and gpio-product-off.service at halt.
# Prefer gpioset (libgpiod tools); fall back to classic sysfs export.
set -u

board_id=""
if [ -x /usr/libexec/board/board-id.sh ]; then
	board_id="$(/usr/libexec/board/board-id.sh 2>/dev/null || true)"
elif [ -f /run/hmi/board_id ]; then
	board_id="$(tr -d '[:space:]' </run/hmi/board_id)"
fi

# Keep in sync with app/lws_hmi/assets/hal/gpio.ynh960.json / gpio.ek3562.json
drive_gpioset_ynh960() {
	command -v gpioset >/dev/null 2>&1 || return 1
	# red chip3:9 / 105; yellow chip3:10 / 106; green chip4:21 / 149; bell chip3:27 / 123
	gpioset gpiochip3 9=0 10=0 27=0 2>/dev/null || true
	gpioset gpiochip4 21=0 2>/dev/null || true
	return 0
}

drive_sysfs_ynh960() {
	for n in 105 106 149 123; do
		if [ ! -e "/sys/class/gpio/gpio${n}" ]; then
			echo "$n" >/sys/class/gpio/export 2>/dev/null || continue
		fi
		echo out >"/sys/class/gpio/gpio${n}/direction" 2>/dev/null || true
		echo 0 >"/sys/class/gpio/gpio${n}/value" 2>/dev/null || true
	done
}

# OUT0–3 = PCA9535 @ i2c-1 0x20 (lab gpiochip6 base 495 → linux 495–498)
drive_gpioset_ek3562() {
	command -v gpioset >/dev/null 2>&1 || return 1
	gpioset gpiochip6 0=0 1=0 2=0 3=0 2>/dev/null || true
	return 0
}

drive_sysfs_ek3562() {
	for n in 495 496 497 498; do
		if [ ! -e "/sys/class/gpio/gpio${n}" ]; then
			echo "$n" >/sys/class/gpio/export 2>/dev/null || continue
		fi
		echo out >"/sys/class/gpio/gpio${n}/direction" 2>/dev/null || true
		echo 0 >"/sys/class/gpio/gpio${n}/value" 2>/dev/null || true
	done
}

case "$board_id" in
ek3562)
	if ! drive_gpioset_ek3562; then
		drive_sysfs_ek3562
	fi
	;;
*)
	# ynh960 / unknown: keep historical SoC pads
	if ! drive_gpioset_ynh960; then
		drive_sysfs_ynh960
	fi
	;;
esac
exit 0
