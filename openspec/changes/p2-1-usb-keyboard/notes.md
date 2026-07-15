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

## Still need on device (tasks 1.1 / 1.2 / 4.3)

```bash
lsusb
ls -l /dev/input/by-id/*kbd* 2>/dev/null
dmesg | grep -iE 'usb|hid|dwc3|xhci'
# Focus Demo "USB keyboard" field and type
```

Confirm 1 mm adapter pinout and that Micro-USB plug-ssh still works concurrently.
