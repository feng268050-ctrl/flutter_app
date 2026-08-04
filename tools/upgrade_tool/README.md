# Rockchip upgrade_tool (host USB flash)

Vendored Rockchip **command-line** `upgrade_tool` binaries for `make flash` / `make devices` RockUSB paths. Shared CLI docs: `命令行开发工具使用文档.pdf`.

| Host OS | Directory | Binary | Version (revision.txt) |
|---------|-----------|--------|-------------------------|
| macOS | `macos/` | `upgrade_tool` | v2.44 |
| Linux (x86_64) | `linux/` | `upgrade_tool` | v2.44 |
| Windows | `windows/` | `upgrade_tool.exe` | v2.23 |

`scripts/flash-usb.sh` selects the subdirectory from `uname -s` (`Darwin` / `Linux` / `MINGW*`·`MSYS*`·`CYGWIN*`).

## Provenance

- **macOS / Linux v2.44:** Rockchip Linux SDK `tools/` packages (`upgrade_tool_v2.44_for_*`).
- **Windows v2.23:** Rockchip `win_upgrade_tool` / `upgrade_tool_v2.23_for_window` (community mirror used for bootstrap; prefer Innohi/Rockchip package when aligning to v2.44).

Windows is older than macOS/Linux; replace `windows/` when a newer official CLI is available.

## Host requirements

- **Linux:** RockUSB devices use USB vendor `2207`. Install a udev rule so non-root users can talk to the device, or run flash as root. Host binary is **x86_64** only.
- **Windows:** Install Rockchip USB drivers (DriverAssistant). Run `make flash` from **Git Bash** or **MSYS2** (same Makefile/bash scripts as macOS/Linux). Native PowerShell/`cmd` is not supported for this path.
- **macOS:** No extra Rockchip driver; use a powered USB hub when Maskrom is flaky.

## Usage

```bash
make devices
make reboot-loader   # live Linux HMI over USB-SSH, or adb on Android
make flash           # Maskrom: ul then uf; Loader: uf only
```

Image: default `output/firmware/<APP>/<FACTORY_SKU>/factory.img` (or `IMAGE=` / migration `update.img`).
