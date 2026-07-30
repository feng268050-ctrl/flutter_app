# Control-board firmware (source)

Checked-in `.bin` files for **内置控制板固件升级** (Product Home → Modbus).

## Naming

`LSW01H####S####.bin` — HW = four digits after `H`, SW = four digits after `S`
(example: `LSW01H1000S1017.bin` → HW 1000, SW 1017).

## Multi-version

Keep **multiple** bins in this directory (historical SW and/or multiple HW).
`make prepare-app-assets` / `make build-app` copies **only the newest SW per HW**
into `assets/.generated/firmware/control-board/` for the Flutter ship tree.

`make upgrade-control-board` still reads **this source directory** (full history /
`FIRMWARE_BIN=` override), not the generated ship tree.

## Runtime

At runtime the App lists the shipped assets and selects the newest software
version among bins whose hardware version matches the live control card.

Do not place product/APK/rootfs OTA packages here.
