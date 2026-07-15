## Context

ynh960 P2.1 has closed speaker, backlight, rotation, Wi‑Fi, BT, RJ45 eth0, touch, and the pinmux ledger. Remaining §12 item: **external USB HID keyboard**.

**Physical USB topology (product fact):**

| Path | Hardware | Role in P2.1 |
|------|----------|----------------|
| **On-board** | **Micro-USB OTG** only populated receptacle | **plug-ssh** gadget (`g_ether` / peripheral via `lws-hmi-ynh960-usb-gadget.dtsi`) |
| **Expansion** | **1 mm pin-header** → external adapter / cabling for additional USB | **USB host** for HID keyboard (and any other host peripherals) |

Keyboard smoke therefore uses the **1 mm pin → USB host** path, **not** the Micro-USB OTG jack. OTG and host can run concurrently in principle (different controllers / PHYs once host path is enabled).

Today’s gadget overlay disables `usbhost_dwc3` / related host nodes to free the OTG PHY for peripheral. That may also have disabled (or never correctly enabled) the **host** controller that drives the 1 mm expansion. Spike must map pins → SoC USB host / PHY / VBUS.

flutter-pi already consumes **libinput** for touch; once a HID keyboard appears as `/dev/input/event*`, Flutter Focus/`TextField` should receive keys without a custom IME (soft keyboard remains P4).

## Goals / Non-Goals

**Goals:**

- Enumerate a wired USB HID keyboard on the **1 mm pin USB host expansion** and deliver printable / navigation keys into the Flutter app under flutter-pi.
- Keep **Micro-USB OTG plug-ssh** working on its own connector concurrently where hardware allows.
- Minimal Demo smoke (focusable field + presence/status) so §12 can be checked on device.
- Kernel/rootfs bits required for USB HID host on that expansion path are present and verified.

**Non-Goals:**

- Soft on-screen keyboard / `frost_ime` (P4).
- Bluetooth / wireless keyboards.
- OTG dual-role / ID-based auto host↔gadget on Micro-USB (possible later; not this change).
- Tearing down `g_ether` for keyboard use.
- Product Settings UI or Android HID path (P2.5+).

## Decisions

### D1 — Prefer native Flutter key path over a new platform controller

**Choice:** Rely on kernel HID → evdev → libinput → flutter-pi → Flutter `Focus`/`TextField`. Demo may optionally **poll presence** (`/dev/input/by-id/*-kbd*`, or `lsusb`/`udevadm`) for a status line, but MUST NOT reimplement key decoding in Dart.

**Alternatives:** full `KeyboardController` abstraction like Wi‑Fi — deferred until product needs more than smoke.

### D2 — Keyboard on 1 mm USB host expansion; Micro-USB OTG stays plug-ssh

**Choice:** P2.1 keyboard smoke uses the **1 mm pin-header host path** + bench adapter. Do **not** put Micro-USB OTG into host mode for this change. Do **not** add host↔gadget switch helpers.

Spike outcomes that drive DTS work:

1. Which SoC USB controller / PHY is wired to the 1 mm USB host pins?
2. Is VBUS on that expansion hard-wired, or does it need `USB_HOST_PWREN*` (some PWREN pads were dropped from `own-gpio` for gmac conflict)?
3. Can plug-ssh on Micro-USB OTG and keyboard on the expansion run **at the same time**? (Expected yes once host is enabled.)

**Deferred (not wrong, not now):** Micro-USB OTG dual-role via **ID pin** (host cable → keyboard; device cable → PC plug-ssh). Micro-USB OTG often exposes ID; worth a later spike if product wants one-cable flexibility. Rejected for this change as scope creep vs expansion-host bring-up.

### D3 — Kernel / image: HID + host controller for the expansion path

**Choice:** Audit and, if needed, add a fragment (e.g. `lws-hmi-usb-hid.config`) for `CONFIG_USB_HID`, `CONFIG_HID`, `CONFIG_HID_GENERIC`, and enable the correct **usbhost** / PHY nodes for the 1 mm host expansion. Adjust `lws-hmi-ynh960-usb-gadget.dtsi` (or a sibling overlay) so Micro-USB OTG stays peripheral **without** leaving expansion host disabled.

### D4 — Demo UI: Keyboard smoke section on P2 home

**Choice:** `KeyboardDemoSection` with:

- Status: keyboard detected / not detected (best-effort).
- Focused `TextField` / multiline for typing smoke.
- Short note: keyboard on **1 mm USB host expansion**; Micro-USB OTG = plug-ssh; not product soft IME.

Wire near other I/O demos; failures non-fatal; post-frame init only.

### D5 — Docs ledger

**Choice:** Extend `docs/ynh960-io-pinmux-ledger.md` with a USB ports table (Micro-USB OTG = plug-ssh; 1 mm pin = host / keyboard) + smoke commands; tick §12 when operator smoke passes.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Gadget overlay disabled the expansion host controller | Spike maps 1 mm pins → controller; re-enable host without changing OTG `dr_mode` |
| `USB_HOST_PWREN*` removed for gmac → no VBUS on expansion | Spike with meter/dmesg; alternate GPIO or hard-wired power per schematic |
| Bench adapter / pinout wrong | Document pinout or photo silk; use Innohi/known harness |
| HID events not reaching Flutter | Demo requests focus; `evtest` if Flutter silent |
| libinput seat omits keyboard | Confirm flutter-pi includes keyboard devices |
| flutter-pi disables keyboard (missing XKB/Compose) | Ship `BR2_PACKAGE_XKEYBOARD_CONFIG` + overlay Compose stubs; verify no `Could not initialize keyboard configuration` |

## Migration Plan

1. Spike on board: 1 mm adapter + keyboard; Micro-USB free for plug-ssh; record controller / VBUS / enum.
2. Kernel/DT as needed → rebuild; **do not** break Micro-USB plug-ssh.
3. Demo section + docs.
4. Operator smoke → check §12; archive change.

Rollback: revert host DTS/HID fragment; OTG gadget unchanged in intent. App Demo section is additive.

## Open Questions

1. Exact 1 mm header pinout / which USB host instance (XHCI / DWC3 host / …)?
2. Does the expansion harness provide Type-A already, or only bare D+/D−/VBUS/GND?
3. Later product need for Micro-USB OTG ID dual-role (keyboard on OTG) — track separately if requested.
