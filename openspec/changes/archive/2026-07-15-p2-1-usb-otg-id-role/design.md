## Context

P2.1 shipped two USB paths on ynh960:

| Path | Hardware | Baseline before this change |
|------|----------|------------------------------|
| Micro-USB OTG | On-board receptacle | `usbdrd` + `u2phy0_otg`, fixed peripheral → plug-ssh |
| 1 mm expansion | Pin-header → adapter | `usbhost_dwc3` + `u2phy0_host`, HID keyboard |

Operators want the **same Micro-USB jack** for either PC debug (USB-SSH) or a USB-A keyboard (via OTG adapter). Archive `p2-1-usb-keyboard` deferred ID dual-role; this change tried `dr_mode=otg` + IDDIG, then **pivoted** after board evidence showed common OTG adapters leave **ID floating** (`USB-HOST` stays 0), and forced-`host` idle **hides PC VBUS**.

**Shipped control path (board-validated 2026-07-15):** manual **Debug over USB** preference — not automatic ID follow.

## Goals / Non-Goals

**Goals:**

- Micro-USB can run as **peripheral (plug-ssh)** or **host (HID keyboard)** without a DTS rebuild.
- Role selection is **operator-controlled** via Demo **Debug** group + persisted preference (default plug-ssh).
- Plug-ssh starts only when Debug over USB is **on** and OTG reports VBUS (`USB=1`).
- Keyboard on Micro-USB (OTG adapter) when Debug over USB is **off**, reusing flutter-pi / libinput.
- 1 mm expansion keyboard remains independent.
- Demo labels: **Debug over USB** / **Debug over LAN**; ledger documents the model.

**Non-Goals:**

- Soft IME / FrostIME (P4).
- Bluetooth / wireless keyboards.
- Replacing the 1 mm host path.
- Relying on Micro-USB **ID pin** for automatic role (proven unreliable with field adapters).
- Changing MaskROM / RockUSB Loader flash procedure.
- Persisting LAN SSH debug across reboot (stays session-only).

## Decisions

### D1 — Keep kernel `dr_mode=otg` (capability), do not trust ID for product UX

**Choice:** DT sets `usbdrd_dwc3` `dr_mode = "otg"` with `extcon = <&usb2phy0>` so userspace can `otg_mode` → `peripheral` / `host`. Product logic does **not** auto-follow IDDIG.

**Board evidence:** With USB-A keyboard + cheap micro-OTG adapter, `USB-HOST` never asserts; forcing `otg_mode=host` enumerates the keyboard (`17ef:6190`). Forced `host` as idle blinds PC attach (`USB` stays 0).

### D2 — Manual Debug over USB preference (primary)

**Choice:** `/usr/lib/lws-hmi/usb-otg-mode.sh` + `/var/lib/lws-hmi/usb-debug` (`1`/`0`, missing → **on**).

| Preference | PHY | Plug-ssh | Micro-USB use |
|------------|-----|----------|----------------|
| ON (default) | `peripheral` | VBUS → `g_ether` / `usb0` | PC data cable |
| OFF | `host` | stopped | OTG adapter + keyboard |

Boot + extcon udev run `usb-otg-mode.sh apply` (systemd oneshot, not long `udev` RUN). Demo toggle: **Debug over USB**.

**Alternatives rejected:** pure ID follow; heuristic “USB=1 wait for UDC then host” (broke slow Mac USB-SSH / raced with forced host).

### D3 — Plug-ssh gated on preference + VBUS

**Choice:** `usb-plug-ssh-vbus-check.sh` starts `lws-hmi-usb-plug-ssh.service` only when pref is debug-on **and** extcon `USB=1` (and not fighting host). Host mode always stops the unit.

### D4 — Keyboard path unchanged at Flutter layer

**Choice:** No Dart HID decode. Host mode + OTG adapter → `/dev/input` → flutter-pi. Demo keyboard copy points at Debug over USB OFF. 1 mm host overlay (`lws-hmi-ynh960-usb-host.dtsi`) stays enabled.

### D5 — Demo Debug group: USB + LAN

**Choice:** One **Debug** section after HTTP/Proxy:

| Toggle | Default | Persist | Backend |
|--------|---------|---------|---------|
| **Debug over USB** | ON | `/var/lib/lws-hmi/usb-debug` (userdata via prefs-bind) | `usb-otg-mode.sh` |
| **Debug over LAN** | OFF | No | existing `enable-ssh-debug.sh` / `lws-hmi-lan-ssh.service` |

### D6 — Boot / flash unchanged

**Choice:** U-Boot / MaskROM / Loader still use device mode for RockUSB. Linux-only OTG mode preference.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Operator leaves Debug over USB ON while plugging keyboard | Demo copy + status line; dial OFF before OTG keyboard |
| Pref lost on flash without userdata | defaults ON (plug-ssh); prefs-bind to `/userdata/lws-hmi` |
| udev kills long scripts | oneshot `systemctl start --no-block` |
| Confused with ID-based OTG cables | Ledger: ID not used for product switch |

## Migration Plan

1. ~~Spike ID~~ → concluded ID unreliable for adapters in use.
2. Land `dr_mode=otg` + dual-role Kconfig (done).
3. Land `usb-otg-mode.sh` + VBUS gate + boot/udev apply (done).
4. Demo Debug group + keyboard copy (done).
5. **Board validation (2026-07-15):** Debug over USB ON → USB-SSH (`make devices`); OFF → host (`otg_mode=host`, plug-ssh inactive); Demo labels updated — **PASS**.

**Rollback:** Restore fixed `peripheral` + VBUS-only plug-ssh; remove Demo USB toggles / `usb-otg-mode.sh`.

## Open Questions

1. ~~ID routed?~~ **Closed for UX:** treat as unreliable; manual Debug over USB. Schematic confirmation still nice-to-have, not blocking.
2. Extcon string table — see `notes.md` (diag only).
3. ~~OTG host VBUS~~ — PHY `USB_VBUS_EN` sufficient when `otg_mode=host`.
