## 1. Spike / hardware facts

- [x] 1.1 ID / adapter behavior recorded in `notes.md` (ID unreliable for auto-role)
- [x] 1.2 Extcon strings for PC cable captured; OTG adapter does not assert `USB-HOST`
- [x] 1.3 OTG host VBUS via PHY `USB_VBUS_EN`
- [x] 1.4 Pivot: do not ship ID-only auto dual-role; manual Debug over USB

## 2. Kernel / Device Tree / Kconfig

- [x] 2.1 `dr_mode=otg` in `lws-hmi-ynh960-usb-gadget.dtsi`
- [x] 2.2 DWC3 dual-role Kconfig retained
- [x] 2.3 Expansion host overlay kept; no extra ID DT required for manual mode
- [x] 2.4 Kernel/image rebuilt and flashed; PHYs OK

## 3. Plug-ssh + mode helper

- [x] 3.1 `usb-otg-mode.sh` + `/var/lib/lws-hmi/usb-debug` (default on)
- [x] 3.2 VBUS gate only when Debug over USB on; diag reports pref / mode
- [x] 3.3 Smoke: Debug over USB ON → USB-SSH (`make devices`) — PASS
- [x] 3.4 Smoke: Debug over USB OFF → `otg_mode=host`, plug-ssh stopped — PASS

## 4. Demo + docs

- [x] 4.1 Keyboard path via host mode (OTG adapter) — validated earlier with forced host
- [x] 4.2 Demo **Debug** group: Debug over USB + Debug over LAN
- [x] 4.3 1 mm host keyboard remains independent (unchanged overlay)
- [x] 4.4 Ledger / notes / design updated for manual model
- [x] 4.5 `verify-rootfs-overlay` lists `usb-otg-mode.sh`; boot unit enabled

## 5. Manual USB Debug (product path)

- [x] 5.1 Helpers + pref + boot/udev apply
- [x] 5.2 Demo labels Debug over USB / Debug over LAN
- [x] 5.3 Board validation matrix in `notes.md` — **PASS 2026-07-15**
