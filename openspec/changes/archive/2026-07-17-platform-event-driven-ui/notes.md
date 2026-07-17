# platform-event-driven-ui — notes

## Rename

Formerly sketched as `wifi-event-driven-state`; renamed to cover **all** Demo live OS surfaces.

## Explicitly out of event migration

| Surface | Why |
|---------|-----|
| Modbus SN / alarm temps | Serial request/response domain; optional Demo refresh OK |
| RGB LED modes | HMI is authority |
| Orientation | Pref + `systemctl restart hmi`; no mid-session OS stream |
| HTTP probe | On-demand Future, not continuous monitor |
| Audio **playing** | Already process/event based (`playing` Stream) |

## P0 vs P1

- **P0:** Ethernet, Wi‑Fi, Bluetooth, LAN SSH, USB keyboard  
- **P1:** timedate1/timezone, backlight inotify, ALSA volume notify, optional http-proxy inotify  
