## 1. Overlay paths and auto-support

- [x] 1.1 Ship `/etc/usb-otg.ini` in rootfs (`debug_only`, `auto_host_support`) on ynh960 (both false); document headless/`auto_host` packs
- [x] 1.2 Persist `/var/lib/hal/usb-otg.conf`; migrate legacy `usb-debug`; board policy `/etc/usb-otg.ini`
- [x] 1.3 Update `paths.sh`, `bind-prefs` migration list, diagnose/verify scripts for conf + auto-support stamp

## 2. Shell OTG mode helper

- [x] 2.1 Extend `usb-otg-mode.sh` for `debug` / `mtp` / `host` / `status` / `apply` using `/var/lib/hal/usb-otg.conf`
- [x] 2.2 Gate plug-ssh VBUS reconcile on `mode=debug` (not legacy pref file)
- [x] 2.3 **Abandoned:** attach/detach product signals — `attached` is no-op/diagnostic only
- [x] 2.4 Update boot/udev units and `verify-rootfs-overlay.sh` expectations

## 3. MTP userspace (`usb-otg-mtp`)

- [x] 3.1 Select and enable Buildroot/kernel MTP gadget pieces (e.g. umtprd + FunctionFS); document choice
- [x] 3.2 Add start/stop helpers: ensure `/userdata/storage` exists; start MTP for `mode=mtp`; stop on mode leave
- [x] 3.3 Enforce mutual exclusion with `g_ether` / plug-ssh and with host role

## 4. cyber_hal UsbOtg

- [x] 4.1 Add `hal/usb_otg` public API (`UsbOtg`, mode enum `debug|mtp|host`) + Linux/stub backends — **no** attach/detach streams
- [x] 4.2 Wire `BoardBindings` / profile injection (helper, auto-support/storage paths)
- [x] 4.3 Unit tests: mode read/write support; pickerModes; no attach watch tests
- [x] 4.4 Update `docs/hal-portability.md` and package README (product materials checklist)

## 5. CyberUI reusable OTG mode picker

- [x] 5.1 Add CyberUI OTG mode-picker dialog API (title + injectable options; standard copy preset; no `cyber_hal` dependency)
- [x] 5.2 Export + document in CyberUI README module map
- [x] 5.3 Widget/golden or pump tests: title `Select USB Mode`; labels Debug over USB / Media Transfer Protocol / Connect Gadget; two-mode list omits host
- [x] 5.4 Mode picker is **optional chrome** — not required for cable insert (attach UX abandoned)

## 6. Move SshDebug to network; remove debug/usb

- [x] 6.1 Move `SshDebug` / `LinuxSshDebugController` under `hal/network`; export from network barrel
- [x] 6.2 Remove `UsbDebug` / `LinuxUsbDebugController` and `hal/debug` barrel (after App cutover)
- [x] 6.3 Update App re-exports and analyze/tests

## 7. HMI App UX

- [x] 7.1 Remove Demo Debug section + `debug_demo_section` tests
- [x] 7.2 Add Settings Network LAN SSH entry immediately after HTTP Proxy
- [x] 7.3 Settings → Input → USB OTG page (mode choices per `/etc/usb-otg.ini`); persist via `setMode`
- [x] 7.4 **Abandoned:** Home status-bar USB icon / attach host — removed
- [x] 7.5 Wire AppServices; Settings mode switching only

## 8. Docs and cross-spec wording

- [x] 8.1 Update pinmux/plan/docs references from binary USB Debug to three-mode (`debug`/`mtp`/`host`) + MTP
- [x] 8.2 Align HID keyboard/mouse operator docs with `mode=host` wording
- [x] 8.3 Document that attach/icon/push are out of scope

## 9. Device verification

- [x] 9.1 Boot restores `/var/lib/hal/usb-otg.conf` (default debug); auto-host boards silent-host when USB-HOST
- [x] 9.2 Settings → Input → USB OTG changes mode; services update (no status-bar icon)
- [x] 9.3 `mode=host`: OTG keyboard/mouse — retest after CyberIME `readOnly` fix (`CyberImeTextField` accepts physical keys)
- [x] 9.4 Settings SSH Debug shows On/Off; Demo has no Debug group
- [x] 9.5 `debug_only=true` pack: Settings locked to Debug — **skipped / optional** (not required for ynh960 default pack)
