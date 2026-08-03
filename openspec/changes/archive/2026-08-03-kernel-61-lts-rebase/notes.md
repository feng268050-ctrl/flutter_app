# kernel-61-lts-rebase — implementation notes

## Tip lock (2026-08-03)

| Field | Value |
|-------|--------|
| Owned baseline | `linux-sdk/kernel-6.1` `SUBLEVEL=99` (`uname -r` → `6.1.99`) |
| kernel.org 6.1 LTS tip | **6.1.180** ([releases.json](https://www.kernel.org/releases.json), moniker `longterm`, released 2026-07-30) |
| Floor | ≥ 6.1.180 (met by tip) |
| Locked pin | **6.1.180** |
| Pin SoT (git) | `overlay/kernel/KERNEL_6_1_SUBLEVEL` + `docs/linux-sdk-vendor-import.md` |
| Vendor SDK ≥ floor? | No — owned tree still 6.1.99; no newer Innohi drop adopted for this change |

## 1.1 Baseline inventory (Rockchip / Innohi vs vanilla 6.1.99)

Owned tree is **gitignored** (`linux-sdk/`), **no nested `.git`** — stable catch-up uses a 3-way merge workdir (vanilla 6.1.99 / vendor / vanilla 6.1.180), not `git merge` inside the monorepo.

| Area | Notes |
|------|--------|
| `innohi/` | Top-level out-of-tree (~250M): GPIO/MCU/wiegand, video bridges, **large vendor Wi‑Fi trees** (rtl8821CU, rtl8852BE, qca206X, …) |
| `drivers/rknpu/` | Rockchip NPU (~23 files) |
| `drivers/gpu/drm/rockchip/` | Vendor DRM (~100 files) |
| `drivers/net/wireless/aic8800/` | Product Wi‑Fi/BT path (~131 files) |
| `arch/arm64/boot/dts/rockchip/ynh*.dts*` | Innohi board DTs (ynh512…570, **ynh960**, ynh962) + product `ynh960-*.dtsi` after overlay squash |
| `arch/arm64/configs/rockchip_linux_*` | Vendor defconfig family; product fragments `ynh960-*.config` |

Generic subsystems (`net/`, `fs/`, `kernel/`, …) follow 6.1.99 + Rockchip delta — prefer **upstream stable** on conflict outside vendor paths.

## 1.4 Product overlay / FIT boards to rebase

**FIT inventory** (`board/rk356x-fit-boards.txt`): `ynh960` only (emulator not in FIT).

**Patches** (`overlay/kernel/patches/`):

| Patch | Intent |
|-------|--------|
| `0001-drm-gem-handle-objects-without-funcs-on-release.patch` | DRM GEM release safety |
| `0004-gt9xx-prefer-dt-cfg-protocol-b.patch` | Touch |
| `0005-icplus-ip101a-disable-aps-ynh960.patch` | Ethernet PHY |
| `0006-rockchip-drm-skip-init-without-display-subsystem.patch` | DRM without display |
| `0007-rockchip-sip-skip-smc-without-rockchip-dt.patch` | SIP/SMC without RK DT |
| `0009`–`0011` | Mali midgard/bifrost + `rockchip_post_csc` `MIN`/`MAX` vs `linux/minmax.h` |

`0008-rk808-rtc-reenable-probe` was **removed** on purpose (`apply-overlay.sh`: restore from `.lws-hmi.orig`, do not re-add 0008).

All of the above were **regenerated** against clean 6.1.180 baselines (task 3.1); round-trip apply → REJ=0.

**DTS / config fragments** (`overlay/kernel/rockchip/`):

- DTS: `ynh960-{linux-root,display,evb-trim,npu-vop,optee,own-gpio,panel-init,rtc,touch,uart5-gmac,uart7-pwm,usb-gadget,usb-host}.dtsi`
- Config: `ynh960-{bt-hid,display,eth,kernel-trim,rtc,touch,usb-gadget,wifibt}.config`, `emulator-virtio.config`

## Merge log

| Step | Detail |
|------|--------|
| Method | 3-way git merge workdir under `linux-sdk/.lws-kernel-lts-merge/` (base=vanilla 6.1.99 tarball, ours=owned tree, theirs=vanilla 6.1.180 tarball) |
| Upstream refs | `tarballs/linux-6.1.{99,180}.tar.xz` from cdn.kernel.org |
| Jump | Single jump 6.1.99 → **6.1.180** (no staged intermediates) |
| Conflicts | 47 files; generic → upstream; Rockchip DRM/PHY/SPI/gpio/sdhci/dwmac-rk/optee → vendor; combined drm_gem product recovery + upstream `!data` guard; both stmmac macros; USB dwc3 helpers both kept |
| Pitfall | Kernel `.gitignore` lists `innohi` → first vendor commit omitted it; `rsync --delete` wiped `kernel-6.1/innohi`. Restored from Docker volume `lws-hmi-sdk` (still on 6.1.99) and `git add -f` |
| Follow-up fix | `serial8250_tx_dma_flush` moved after Rockchip `#endif` so it is not rockchip-`#if`-only |
| Follow-up fix | `phy-rockchip-inno-usb2.c`: dropped orphaned `vbus_attach = …` left by taking vendor hunks while an upstream assign survived — first `make build-kernel` failed compile but still packed **stale 6.1.99** Image |
| Follow-up fix | Mali midgard/bifrost + `rockchip_post_csc`: `MIN`/`MAX` clash with `linux/minmax.h` under `-Werror` → overlay patches `0009`–`0011` |
| Follow-up fix | `8250_dw.c`: starfive pdata → `dw8250_skip_set_rate_data` (vendor symbol gone after tip merge) |
| Follow-up fix | `hub.c`: drop `USB_QUIRK_AUTO_SUSPEND` check (macro lost when taking upstream `quirks.h`; quirks.c entries also upstream); restore `USB_QUIRK_AUTO_SUSPEND` as `BIT(19)` for UVC |
| Follow-up fix | `dwc3/core.c`: missing `}` after `dwc3_get_clocks` (ours+theirs concat) |
| Follow-up fix | `dwmac-rk-tool.c`: `tx_status`/`rx_status` → 6.1.180 stmmac desc API (no `netdev_stats*`) |
| Follow-up fix | `bcmdhd/wl_cfg80211.c`: only gate `cfg80211_port_authorized` on `6.1.100` (do **not** broaden REGULATORY `6.2.0` gates) |
| Follow-up fix | `xhci.h`: restore Rockchip `XHCI_U2_BROKEN_SUSPEND` as `BIT_ULL(50)` (bit 47 taken by upstream `XHCI_WRITE_64_HI_LO`) |
| Follow-up fix | `cpufreq_interactive.c`: 5-arg `cpufreq_frequency_table_target(..., min, max, relation)` |
| Follow-up fix | `optee/supp.c`: keep 6.1.180 IDR/`processed` lifecycle; Rockchip interruptible wait + `shutdown` freeze/reboot abort |
| Overlay refresh | Regenerated `0001`/`0004`–`0007`/`0009`–`0011` against clean 6.1.180 baselines; `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` → **REJ=0** |
| Owned tree | `linux-sdk/kernel-6.1` now `SUBLEVEL=180` + `innohi/` present |
| Gate | Must `strings Image \| grep 'Linux version'` → `6.1.180` before accepting FIT — **met** (`#102` Image / FIT 2026-08-03) |

Conflict resolver one-shot: `openspec/changes/kernel-61-lts-rebase/resolve-remaining.py` (historical).

## Acceptance (2026-08-03)

| Check | Result |
|-------|--------|
| Pin | **6.1.180** |
| Host Image | `strings Image` → `Linux version 6.1.180` (`#102` SMP) |
| Deploy | `make upgrade` stream → inactive A (`rootfs_a` + `boot`); try-boot armed |
| Device `uname -r` | **6.1.180** (`Linux buildroot 6.1.180 #102 SMP … aarch64`) |
| Slot | `root=PARTLABEL=rootfs_a` |
| HMI | `hmi.service` active; Weston + flutter-wayland-client under cgroup |
| Net | `eth0` UP, `wlan0` UP (aic8800_*), `usb0` USB-SSH UP |
| Display/touch | rockchip-drm + VOP2 bound; goodix-ts / gt9xx probe OK |
| NPU | `[drm] Initialized rknpu 0.9.8` |
| Notes | Early `Call trace` WARN stacks from `rockchip_combphy` reset + pinctrl gpio (non-fatal; board stayed up). Rootfs also needed `external/rkwifibt/.../wl_cfg80211.c` `cfg80211_port_authorized` gate → `6.1.100`. |
| Floor coverage | Tip **6.1.180** ≥ floor; post-6.1.99 High stable content included by full tip merge (no cherry-pick CI). |
| Optional 4.4 | **Done 2026-08-03** — NFS/SUNRPC client stack disabled in `ynh960-kernel-trim.config`; 9P kept via later `emulator-virtio.config`; BT/CFG80211/USB_GADGET/MODULES/IO_URING left on (product need). |

## Post-acceptance: silent audio (2026-08-03)

| Item | Detail |
|------|--------|
| Symptom | ALSA/PCM/`mpg123` OK; ClassD/`hp-ctl` OK; **no audible output** |
| Root cause | Upstream 6.1.y pinctrl: `gpio_request_enable` always forces `RK_FUNC_GPIO`. Rockchip I2S TDM samples LRCK via `GPIOD_ASIS` on pin 37 (`gpio1-5`); remux stole LRCK from `fe410000.i2s` → digital silent to codec |
| Evidence | Boot WARN `pin 37 already requested by fe410000.i2s; switch mux … to GPIO`; LRCK GPIO stuck `hi` during play |
| Fix | Overlay `0012-pinctrl-rockchip-keep-mux-on-shared-gpio-request.patch` — if pin already has mux owner + non-GPIO mux, keep mux (warn `keep mux … (shared GPIOD_ASIS)`); `scripts/apply-overlay.sh` lists `pinctrl-rockchip.c` |
| Verify | After `build-kernel` + `upgrade`: dmesg keep-mux; LRCK samples `hi`/`lo` during `mpg123`; audible path restored |

## 4.4 kconfig attack-surface trim (2026-08-03)

| Item | Detail |
|------|--------|
| Change | Extend `overlay/kernel/rockchip/ynh960-kernel-trim.config`: disable `NFS_FS` / NFSv2–v4 / `LOCKD` / `SUNRPC*` client stack |
| Keep | Product: BT, CFG80211, USB_GADGET, MODULES, IO_URING, USER_NS, NETFILTER; emulator: 9P/virtio re-enabled by later `emulator-virtio.config` |
| Verify | Volume `.config` + device `/proc/config.gz`: `# CONFIG_NFS_FS is not set`; `uname -r` 6.1.180; `hmi.service` active after upgrade |
