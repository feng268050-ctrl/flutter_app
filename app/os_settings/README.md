# OS Settings (`app/os_settings`)

**Cyber OS system Settings app** — the full platform configuration UI for embedded appliances. Also used for **factory / after-sales** knobs that end users do not touch daily (e.g. UI Scale). Installed to `/opt/os_settings`; launched on demand via `os-settings.service` (not boot default).

HMI Settings (`app/lws_hmi`) is a **simplified, product-customized** subset. Role policy: [`docs/settings-apps-roles.md`](../../docs/settings-apps-roles.md). Implementation plan: [`docs/os-settings-app-plan.md`](../../docs/os-settings-app-plan.md).

## Pages (platform scope)

| Group | Destinations |
|-------|----------------|
| Basic Info | About, Operating System, Storage |
| Network | Wi‑Fi, Ethernet, Bluetooth, Proxy, SSH |
| Date & Time | Date & Time |
| Locale | Country/Region, Language, Unit |
| Display & Sound | Display (brightness, auto-sleep, **ui_scale** for factory/field, wallpaper), Sound (volume only), Power Mode |
| Input | Keyboard, Mouse, USB OTG |

Does **not** include product welding UI, Modbus thresholds, cloud services, camera/LED, OTA upgrade flows, or `gpio.json` / `modbus.json`.

## Entry / exit

- **From HMI:** Device Info → tap Device SN 5× → `switch-to-os-settings`
- **Back to HMI:** OS Settings status bar **Exit** → `switch-to-hmi`
- Only one Flutter seat active (`hmi.service` ↔ `os-settings.service` `Conflicts=`)

## Build & deploy

```bash
APP=os_settings make build-app
APP=os_settings make push-app    # restarts os-settings.service
```

Rootfs auto-includes when `app/os_settings/pubspec.yaml` exists (`make build-rootfs`).

## Dependencies

Path packages: `cyber_hal`, `cyber_ui`, `cyber_ime`. Flutter **3.41.9** (repo pin). Shared HAL prefs with HMI under `/var/lib/hal/`.
