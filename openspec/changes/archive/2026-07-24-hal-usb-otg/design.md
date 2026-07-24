## Context

Three Micro-USB roles (debug / mtp / host) via Settings and `UsbOtg.setMode`. Prior iterations tried status-bar icons and attach/detach detection; **ynh960 sticky PHY/VBUS makes that unreliable**. This design **drops connection detection** and keeps mode switching only.

## Goals / Non-Goals

**Goals:**

- `UsbOtg`: `getMode` / `setMode` / `apply` / `getSupport` / `pickerModes`.
- Modes **`debug` | `mtp` | `host`**; persist `/var/lib/hal/usb-otg.conf`; policy `/etc/usb-otg.ini`.
- Settings → USB OTG switches mode; services follow (`ssh-debug-usb` / MTP / host).
- MTP on `/userdata/storage`; plug-ssh when `mode=debug` + VBUS gate (existing); host tears down gadgets.
- `SshDebug` under `hal/network`.

**Non-Goals:**

- Attach/detach edge streams, `isAttached` for product UI, status-bar USB icon, insert picker push.
- Fixing ynh960 VBUS/bvalid sticky detect in DTS (separate if needed).
- MSC U-disk; macOS Finder-native MTP.

## Decisions

### D1 — Mode switching only

| `mode` | Behavior |
|--------|----------|
| `debug` | peripheral + plug-ssh on VBUS |
| `mtp` | peripheral + MTP |
| `host` | host role; no gadget |

Boot `apply` restores conf (default debug) unless `auto_host_support` selects host at runtime.

### D2 — No attach product API

HAL MUST NOT require Apps to watch cable presence for this change. Shell `attached` if present returns detached / unused by HMI. Remove HMI icon host and status-bar USB glyph.

### D3 — Plug-ssh VBUS gate unchanged

`usb-plug-ssh-vbus-check` may still start/stop ECM from extcon for **debug connectivity**; that is service lifecycle, not App-visible attach UX.

## Risks

- Operators get no on-screen “USB connected” cue — accepted.
- Sticky PHY still affects gadget re-enum after unplug — toggle mode or replug; DTS later.
