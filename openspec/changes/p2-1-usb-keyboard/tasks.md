## 1. Board spike (1 mm USB host expansion)

- [x] 1.1 Desk map: Innohi `usbhost_dwc3` + `u2phy0_host` / `combphy1`; operator still confirms on board with 1 mm adapter + `lsusb` (see `notes.md`)
- [x] 1.2 Desk map: host path identified; concurrent plug-ssh expected once host re-enabled — confirm on device with Demo typing
- [x] 1.3 Map expansion → `usbhost_dwc3` / `u2phy0_host`; `USB_HOST_PWREN*` on gpio4 PA0/PA1/PA2 restored (RMII frees pads)

## 2. Kernel / image

- [x] 2.1 `lws-hmi-usb-gadget.config`: DWC3 **dual-role** + `CONFIG_USB_HID` / `HID_GENERIC` (was gadget-only)
- [x] 2.2 `lws-hmi-ynh960-usb-host.dtsi`; slim gadget dtsi; stop `patch_innohi_usbhost_off`; restore PWREN in own-gpio
- [x] 2.3 No new rootfs helpers — verify scripts unchanged

## 3. Demo UI

- [x] 3.1 Add `KeyboardDemoSection` (presence + `TextField`; 1 mm host + non-IME note)
- [x] 3.2 Wire into `p2_demo_page.dart` after first frame (with network sections)
- [x] 3.3 `UsbHidKeyboardProbe` on `/dev/input/by-id/*kbd*`

## 4. Docs and acceptance

- [x] 4.1 Update `docs/ynh960-io-pinmux-ledger.md` USB ports + smoke commands
- [x] 4.2 Note bench adapter in `app/hmi/README.md`; §12 keyboard checkbox remains for operator smoke
- [ ] 4.3 Device smoke: keyboard on 1 mm host path → enum → type into Demo (Micro-USB plug-ssh optional concurrent)
- [x] 4.4 `flutter analyze` / unit test under `app/hmi/`
