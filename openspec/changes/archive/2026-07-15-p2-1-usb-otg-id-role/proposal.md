## Why

P2.1 proved USB HID on the **1 mm host expansion**, while Micro-USB stayed plug-ssh-only. Operators need the **same Micro-USB jack** for PC USB-SSH **or** a USB-A keyboard (OTG adapter). Automatic **ID-pin** dual-role was tried; board bring-up showed common OTG adapters leave ID floating, so auto-role is not a reliable product control. Ship **manual Debug over USB** (persisted) plus existing session-only **Debug over LAN**.

## What Changes

- Keep kernel **`dr_mode=otg`** so Micro-USB can be peripheral or host via `otg_mode`.
- **Do not** auto-select role from IDDIG for Demo/product UX.
- Add **`usb-otg-mode.sh`** + `/var/lib/lws-hmi/usb-debug` (default **on**): ON → peripheral + VBUS plug-ssh; OFF → host + stop plug-ssh (keyboard).
- Demo **Debug** group: **Debug over USB** (persisted) and **Debug over LAN** (default off, not persisted).
- Gate plug-ssh on preference + VBUS; update diag / ledger / keyboard copy.
- **Non-goals**: soft IME (P4); Bluetooth keyboards; replacing 1 mm host; RockUSB flash redesign; persisting LAN SSH.

## Capabilities

### New Capabilities

- `usb-otg-id-role`: Micro-USB host↔peripheral capability and **manual** USB Debug preference (ID auto-role deferred / non-normative).

### Modified Capabilities

- `linux-usb-hid-keyboard`: Keyboard MAY attach via Micro-USB when USB Debug is off (host); 1 mm path remains.
- `usb-plug-ssh-debug`: Plug-ssh only when USB Debug on + VBUS; must not fight host mode.
- `p2-device-demo-ui`: Debug group (Debug over USB / Debug over LAN); keyboard copy updated.
- `buildroot-lws-hmi-image`: `dr_mode=otg` + helpers / units for preference apply.

## Impact

- **Kernel / DTS:** `lws-hmi-ynh960-usb-gadget.dtsi` → `dr_mode=otg`.
- **Userspace:** `usb-otg-mode.sh`, VBUS gate, boot/udev apply oneshots.
- **App:** `DebugDemoSection`, `UsbDebugController`.
- **Docs:** pinmux ledger §4.1; plan notes.
- **Validation (2026-07-15 board):** Debug over USB ON → USB-SSH listed; OFF → `otg_mode=host`, plug-ssh inactive — **PASS**.
