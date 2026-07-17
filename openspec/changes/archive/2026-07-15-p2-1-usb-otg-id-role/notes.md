# P2.1 Micro-USB OTG — spike / validation notes

## Topology

| Path | Controller | PHY |
|------|------------|-----|
| Micro-USB OTG | `usbdrd` `fcc00000.usb` | `u2phy0_otg` (`fe8a0000` / extcon0) |
| 1 mm expansion host | `usbhost` `fd000000.usb` | `u2phy0_host` |

Kconfig: `CONFIG_USB_DWC3_DUAL_ROLE=y`.

## ID / extcon facts (2026-07-15)

| Observation | Result |
|-------------|--------|
| PC micro-B cable | `USB=1`, `USB-HOST=0` |
| USB-A keyboard + common micro-OTG adapter | **`USB-HOST` stays 0** (ID floating / unused) |
| `echo host > otg_mode` + keyboard | **PASS** — Lenovo Calliope `17ef:6190`, `*kbd*` node |
| Forced `host` as idle | **PC USB=1 hidden** — breaks USB-SSH detection |
| Heuristic auto (wait UDC → host) | Broke / raced with Mac USB-SSH |

**Conclusion:** Product UX does **not** use ID auto-role. Manual **Debug over USB** preference.

Extcon keys on `extcon0`: `USB`, `USB-HOST`, `USB_VBUS_EN`, `SDP`/`CDP`/`DCP`/`SLOW-CHARGER`. Host VBUS drive: PHY `USB_VBUS_EN` when `otg_mode=host`. Expansion VBUS: `USB_HOST_PWREN*` / `gpio_innohi` `USB_*`.

## Shipped control path

| Piece | Role |
|-------|------|
| `usb-otg-mode.sh` | `debug` / `host` / `status` / `apply` |
| `/var/lib/hmi/usb-debug` | `1` = Debug over USB on (default if missing), `0` = host |
| Boot + extcon udev | `systemctl start --no-block usb-otg-role.service*.service` → `apply` |
| `usb-plug-ssh-vbus-check.sh` | plug-ssh only if pref on + `USB=1` |
| Demo | **Debug over USB** + **Debug over LAN** |

## Board validation (2026-07-15) — PASS

| Test | Result |
|------|--------|
| Debug over USB **ON** + PC cable | `otg_mode=peripheral`, plug-ssh active, `usb0` UP, `make devices` shows **USB-SSH** |
| Debug over USB **OFF** | `usb-debug=off`, `otg_mode=host`, plug-ssh inactive (ready for OTG keyboard) |
| Demo labels | Debug over USB / Debug over LAN (pushed via `make push-app`) |
| LAN Debug | Unchanged session-only helpers (`enable-ssh-debug.sh`) |

Operator flow: leave Debug over USB ON for PC; turn **OFF** before plugging keyboard on OTG adapter; use Debug over LAN only when needed (not saved across reboot).
