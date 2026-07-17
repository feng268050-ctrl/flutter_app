# P2.1 notes — audio / backlight / orientation

## Choices locked at implement time

| Topic | Decision |
|-------|----------|
| Audio path | **Process + `mpg123`/`aplay` + `amixer`** (no Flutter audio plugin) |
| Test track | `assets/audio/shanghai_tan.mp3` from lws-ui `res/raw/shanghai_tan.mp3` |
| Speaker route | Re-assert `amixer sset 'Playback Path' 'RING_SPK_HP'` (ParamUpdate + `hmi-launch.sh` + App) |
| Volume | **ALSA mixer** (primary, OS-style) + mpg123 remote `V` soft gain; **latest-wins** coalesce; never restarts decode |
| Playback state | mpg123 `@P` (0=stop / 2=play) + process exit → `Stream<bool> playing` drives Play/Stop button |
| Backlight | Prefer `/sys/class/backlight/backlight/brightness` (panel pwm4 / MainServer). Skip `led-*-pwm`. |
| Orientation | `/var/lib/hmi/display-orientation` → flutter-pi `-o`; apply via `systemctl restart hmi` |
| ALSA packages | `lws_hmi_p2_io.config`: alsa-lib, alsa-utils (amixer/aplay), mpg123 — **needs `make build-rootfs`**, not `push-app` alone |
| uart7 vs pwm14 | Boot log `gpio3-20 already requested by fe6b0000.serial` — disable unused `&uart7` via `ynh960-uart7-pwm.dtsi` (**needs `make build-kernel`**) |

## Device smoke

**PASS** (2026-07-14, ynh960): Demo play / volume / brightness OK; track-end Play/Stop synced via `@P`.

```bash
# Backlight
ls /sys/class/backlight/
cat /sys/class/backlight/backlight/brightness /sys/class/backlight/backlight/max_brightness
echo 20 > /sys/class/backlight/backlight/brightness   # should dim

# Audio (after rebuild with mpg123/amixer)
which mpg123 amixer
amixer scontrols
amixer sset 'Playback Path' 'RING_SPK_HP'
mpg123 /var/lib/hmi/audio/shanghai_tan.mp3     # after App has extracted once

# Confirm uart7 conflict gone after kernel rebuild
dmesg | grep -E 'gpio3-20|fe700020|uart7' || echo 'no conflict'
journalctl -u hmi.service -n 80 --no-pager | grep -E 'media-audio|backlight'
```

## Residual (non-blocking)

1. Optional CLI `speaker-test`/`aplay` recheck for manufacturing scripts.
2. Orientation Demo already covered in plan checklist; re-confirm after major launch-script changes.
