## Why

P2.1 board I/O still lacks **external USB HID keyboard** smoke: touch is proven, but operators cannot confirm **USB host (1 mm pin expansion)** → HID → flutter-pi before P4 soft-IME or P5 text-heavy UI. ynh960 only populates **Micro-USB OTG** on-board; other USB goes through a **1 mm pin-header** adapter. Shipping Demo + host bring-up closes the last P2.1 hardware gap without waiting for FrostIME.

## What Changes

- Prove **wired USB HID keyboard** on ynh960’s **1 mm pin USB host expansion** (not Micro-USB OTG): enumerate, `/dev/input` appears, keys reach flutter-pi / Flutter focus.
- Enable / fix the **USB host controller + VBUS** path for that expansion if DTS/Kconfig currently leave it disabled (Micro-USB OTG remains plug-ssh peripheral).
- Add a minimal **P2.1 Demo section**: focused text field + best-effort connected status (bring-up UI — not product IME).
- Update plan §12, I/O ledger, and smoke notes when device validation lands.
- **Non-goals**: soft keyboard / `frost_ime` (P4); Bluetooth keyboards; Micro-USB OTG dual-role auto host/gadget; changing plug-ssh; Android until P2.5.

## Capabilities

### New Capabilities

- `linux-usb-hid-keyboard`: USB host (1 mm expansion) HID keyboard enumeration and key delivery into flutter-pi/libinput.

### Modified Capabilities

- `p2-device-demo-ui`: Demo home gains a USB keyboard smoke section (focus + text entry / presence).
- `buildroot-lws-hmi-image`: Ensure USB HID / host controller bits for the expansion host path remain in the image (or document kernel fragment / DTS).

## Impact

- **Kernel / DTS**: re-enable or correct the **USB host** node wired to the 1 mm expansion without touching Micro-USB OTG `usbdrd` peripheral for plug-ssh; USB HID Kconfig if trimmed; VBUS/`USB_HOST_PWREN*` if required after spike.
- **App**: Demo UI section on `p2_demo_page.dart`; prefer native Flutter key handling over a heavy platform controller.
- **Docs**: `docs/flutter-pi-hmi-plan.md` §12; `docs/ynh960-io-pinmux-ledger.md`; `app/hmi/README.md` smoke steps.
- **Bench**: 1 mm → USB host adapter required for keyboard smoke.
- **Not in scope**: OTG ID dual-role on Micro-USB (optional later product feature).
