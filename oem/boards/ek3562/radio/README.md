# ek3562 OEM radio (RTL8821CU, onboard SoC USB)

The Wi‑Fi module is **soldered on the motherboard** and wired to the **SoC USB
host** (same enumeration as a dongle: `lsusb` → `0bda:c811` / `c82b` / `c82c`).

**Driver:** mainline **rtw88** (`rtw_8821cu`), enabled in
`overlay/kernel/rockchip/ek3562-wifibt.config`.

**Firmware:** `rtw8821c_fw.bin` under `/lib/firmware/rtw88/` from Buildroot
`linux-firmware` (`lws_hmi_wifi_rtw88.config`). Do **not** ship `*.ko` here.

Optional vendor-specific blobs (non-standard for rtw88) may be dropped in
`firmware/` with a `manifest.json` when needed. Until then this directory stays
README-only.
