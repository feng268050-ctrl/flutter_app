# P2.1 USB keyboard — desk spike notes (before board)

## Topology (operator-confirmed)

| Path | Hardware | Software |
|------|----------|----------|
| Micro-USB OTG | On-board receptacle | `usbdrd_dwc3` + `u2phy0_otg`, `dr_mode=peripheral`, `g_ether` plug-ssh |
| Expansion USB | **1 mm pin-header** → adapter | `usbhost_dwc3` + `u2phy0_host` (+ `combphy1_usq` HS-only) |

## Desk mapping (from Innohi `customer_board_ynh960.dtsi.orig`)

- Innohi already sets `&usbhost_dwc3 { phys = <&u2phy0_host>; status = "okay"; }` and `&combphy1_usq`.
- Plug-ssh work had **force-disabled** those nodes + set `CONFIG_USB_DWC3_GADGET=y` (gadget-only), which blocks host.
- Fix: dual-role Kconfig; `lws-hmi-ynh960-usb-host.dtsi`; stop blanketing host off in the patch script.

## VBUS / `USB_HOST_PWREN*`

- Labels `USB_1` / `USB_2` / `USB_3` on gpio4 **PA0/PA1/PA2**, default high.
- Previously dropped from `own-gpio` because EVB **RGMII** used the same pads.
- Product **RMII** does **not** use PA0/PA1/PA2 → restored in `lws-hmi-ynh960-own-gpio.dtsi`.

## Still need on device (task 4.3) — DONE 2026-07-15

Operator smoke passed: enum → Demo typing → arrows → NumLock LED → hold-to-repeat.
See §「typing failure」「caret arrows」「software key auto-repeat」below and
`docs/ynh960-io-pinmux-ledger.md` §4.1.1.

## 2026-07-15 — typing failure root cause

Kernel HID enum + libinput seat were fine (`event3` keyboard). flutter-pi disabled all
text/raw keyboard input because:

1. **Missing XKB data** — `BR2_PACKAGE_LIBXKBCOMMON` without `BR2_PACKAGE_XKEYBOARD_CONFIG`
   → `failed to add default include path /usr/share/X11/xkb`.
2. **Missing Compose stubs** — no `/usr/share/X11/locale` (no Xorg) →
   `couldn't find a Compose file for locale "C"` → same fatal path in `keyboard.c`.

Fix in tree:

- `overlay/buildroot/chips/lws_hmi_flutter.config`: `BR2_PACKAGE_XKEYBOARD_CONFIG=y`
- fs-overlay: minimal `/usr/share/X11/locale/{compose.dir,locale.alias,C/Compose,...}`
  + `/etc/default/keyboard` (avoid pulling full `XLIB_LIBX11` / `XORG7`)

Smoke after rebuild: flutter-pi stderr must **not** contain
`Could not initialize keyboard configuration`.

## 2026-07-15 — caret arrows + NumLock LED

flutter-pi patches (applied via `FLUTTER_PI_APPLY_PACKAGE_PATCHES` post-rsync hook
in `flutter-pi.compile.mk` — Buildroot skips the normal Patching step for
`SITE_METHOD=local`; use `make rebuild-flutter-pi` to bake into prebuilt/):

- `overlay/buildroot/package/flutter-pi/0001-text-input-arrow-keys.patch` —
  Left/Right (and keypad) move the text_input caret (`model_move_*`); needed
  because raw key events are not forwarded to Flutter.
- `overlay/buildroot/package/flutter-pi/0002-sync-keyboard-leds.patch` —
  clear keyboard LEDs on device add (match fresh xkb), then sync
  NumLock/CapsLock/ScrollLock LEDs after each key via `libinput_device_led_update`.

`scripts/apply-overlay.sh` installs these into the SDK flutter-pi package dir
(stashed for prebuilt rootfs; restored during `br-compile-flutter`).

Source pin: `.cache/flutter-pi/src` @ `37bd9773c1938e5f76208bc4e8632fdbbb4190ff`.


## 2026-07-15 — software key auto-repeat

libinput does not generate key repeats. Added flutter-pi userspace repeat via
`sd_event` timer (660 ms delay, 40 ms / 25 Hz interval) in
`overlay/buildroot/package/flutter-pi/0003-key-repeat.patch` (after 0001/0002).
Repeats only re-fire `on_utf8_character` / `on_xkb_keysym` (not xkb state or gtk).
