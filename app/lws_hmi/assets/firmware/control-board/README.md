# Control-board firmware (bundled)

Checked-in `.bin` files for **内置控制板固件升级** (Product Home -> Modbus).

## Naming

`LSW01H####S####.bin` — HW = four digits after `H`, SW = four digits after `S`
(example: `LSW01H1000S1017.bin` -> HW 1000, SW 1017).

## Selection

At runtime the App lists this directory and **automatically selects the newest
software version** among bins whose hardware version matches the live control
card. Multiple bins may be kept (e.g. historical or multi-HW); only the latest
matching HW is offered for upgrade.

Do not place product/APK/rootfs OTA packages here.
