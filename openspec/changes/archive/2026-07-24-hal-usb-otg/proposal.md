## Why

Micro-USB OTG must support three operator-selected roles: **PC debug** (ECM+SSH), **MTP** file access to `/userdata/storage`, and **USB host** for peripherals. Mode is chosen in **Settings** (or forced by board policy). **Cable attach/detach detection, status-bar USB icon driven by attach, and insert push/notify are explicitly out of scope** — ynh960 PHY signals are too unreliable for product UX.

## What Changes

- Portable **`cyber_hal` `UsbOtg`**: get/set **`mode`** (`debug` | `mtp` | `host`), `apply`, `getSupport` / picker mode list. **No** attach/detach streams, **no** `isAttached` product contract, **no** insert notifications.
- Persist **`/var/lib/hal/usb-otg.conf`**; board policy **`/etc/usb-otg.ini`** (`debug_only`, `auto_host_support`).
- **mtp**: MTP gadget on `/userdata/storage`; **debug**: existing plug-ssh on VBUS when mode=debug; **host**: peripheral gadgets torn down.
- Settings → USB OTG: switch among allowed modes. **No** status-bar USB connection icon. **No** insert mode-picker dialog driven by cable edges.
- CyberUI OTG mode-picker dialog MAY remain as a reusable presentational widget for Settings-like UIs, but MUST NOT be required for cable attach.
- Keep **`SshDebug`** under `hal/network`; LAN SSH settings; Demo Debug removed (already done).

## Capabilities

### New Capabilities

- `hal-usb-otg`: `UsbOtg` mode API only (no attach/detach product requirements).
- `usb-otg-mtp`: MTP gadget for `mode=mtp`.
- `cyber-ui-usb-otg-mode-dialog`: Optional reusable mode list chrome (not cable-driven).

### Modified Capabilities

- `usb-otg-id-role` / `usb-plug-ssh-debug` / `dart-hal` / `settings-ui` / `os-path-layout` / `buildroot-lws-hmi-image` / HID wording: three-mode apply; **drop attach/icon/notify requirements**.
- `product-home-ui`: **MUST NOT** require a USB OTG attach status-bar icon.

## Impact

- Strip HMI `UsbOtgIconHost`, status-bar USB glyph, HAL attach watch / `attached` polling semantics used for UI.
- Shell `usb-otg-mode.sh` keeps `debug|mtp|host|status|apply`; `attached` MAY remain as a no-op/debug aid returning detached, not a product signal.
- Docs: remove attach/icon promises; note VBUS/PHY sticky issues are not solved in this change.

## Out of scope (abandoned)

- Reliable plug/unplug detection on ynh960 for status-bar or push.
- Insert-time mode dialog / attach event streams for Apps.
- networkd-based USB link detect for the OTG icon.
