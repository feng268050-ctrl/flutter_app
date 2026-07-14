# lws_hmi — flutter-pi HMI (embedded Linux)

This tree targets **ynh960 / flutter-pi** via `flutterpi_tool` (`make build-app`).
It is not a phone app: only the **`linux/`** platform stub is kept (plugin registrant /
FFI helpers). `android/` / `ios/` / `macos/` / `web/` / `windows/` are intentionally absent.

P2.5 can re-add a mobile target later, for example:

```bash
cd app/hmi
flutter create --platforms=android .
```

See [`../README.md`](../README.md) for engine pins and deploy layout.

## P2.1 platform I/O (speaker / backlight / orientation)

Reusable modules live under `lib/platform/`:

| Module | Linux backend | Notes |
|--------|---------------|-------|
| `audio/` | `mpg123`/`aplay` + `amixer` | Forces `Playback Path=RING_SPK_HP`; asset → `/var/lib/lws-hmi/audio/` |
| `backlight/` | Prefer `/sys/class/backlight/backlight` | Skip broken `led-*-pwm` clones |
| `display/` | preference file + `systemctl restart hmi` | `/var/lib/lws-hmi/display-orientation` → flutter-pi `-o` |

**Device smoke (after flash / push-app):**

1. Play — hear shanghai tan; sweep Volume slider
2. Sweep Brightness — panel dims/brightens
3. Portrait / Landscape — HMI restarts; `ps`/`tr` confirms `-o portrait_up` or `landscape_left`

On first ALSA bring-up, check amp enable and mixer control (`amixer scontrols`) if silent.

### Trace logging

Hot-path `debugPrint` (Modbus TX/RX, backlight steps, audio chatter) is **off by default** — printing every slider tick / Modbus timeout slows debug mode over USB-gadget SSH.

Enable when needed:

```bash
# example: flutterpi_tool / kernel compile with
--dart-define=LWS_HMI_TRACE=true
```
