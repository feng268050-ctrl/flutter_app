## Why

On the ynh960 HMI image, Weston 14’s desktop-shell path auto-starts `/usr/libexec/weston-keyboard` (~23 MB RSS) as the compositor input-method client. Product soft text entry is already **CyberIME**; physical HID keyboards use XKB/libinput — neither depends on `weston-keyboard`. The client is unused overhead and should simply not run.

## What Changes

- **Always disable** Weston’s input-method client so `weston-keyboard` is not launched (runtime `weston.ini` `[input-method]` policy, plus static/post-hook defaults).
- **No** OS Settings switch and **no** new `keyboard.conf` preference — physical keyboard UX stays as today (CyberIME HID auto-hide + layout page).
- **`weston-mouse`:** not present; no change.

## Capabilities

### New Capabilities

- `weston-osk-disabled`: Product Weston HMI seat must not start `weston-keyboard` (or any `[input-method]` OSK client); CyberIME remains the soft IME.

### Modified Capabilities

- *(none at requirement level beyond the new capability; overlay/weston config only)*

## Impact

- **Overlay:** `weston-hmi-config.sh`, `etc/xdg/weston/weston.ini`, post-hook `91-weston-ini.sh`.
- **Apps / HAL / CyberIME:** no API or UI changes.
- **Memory:** ~23 MB RSS saved when the client is absent (measured on device).
- **Non-impact:** `weston-desktop-shell`, mouse prefs, physical keyboard layout / HID presence.
