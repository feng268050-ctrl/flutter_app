# upgrade-buildroot-lts — implementation notes

## Tip lock (2026-08-07)

| Field | Value |
|-------|--------|
| Owned baseline | `linux-sdk/buildroot` `BR2_VERSION := 2024.02` |
| Upstream LTS tip | **2025.02.16** ([buildroot.org/downloads](https://buildroot.org/downloads/), newest `buildroot-2025.02.*`; floor ≥ 2025.02.16) |
| Floor | ≥ 2025.02.16 |
| Locked pin | **2025.02.16** |
| Pin SoT (git) | `overlay/buildroot/BUILDROOT_VERSION` + `docs/linux-sdk-vendor-import.md` |
| Vendor SDK ≥ floor? | **No** — no Innohi/Rockchip drop on 2025.02.x found at implement time; proceed with approach **A** (3-way merge upstream tip into Rockchip 2024.02 tree) |
| Download mirror | GitHub `buildroot/buildroot` tags (buildroot.org HTTPS timed out from this host) |

## 1.2 Baseline inventory (Rockchip / Innohi vs vanilla 2024.02)

Owned tree is **gitignored** (`linux-sdk/`), **no nested `.git`** — LTS catch-up uses a 3-way merge workdir (vanilla 2024.02 / vendor / vanilla 2025.02.16), same pattern as kernel-61-lts-rebase.

| Area | Notes |
|------|--------|
| `board/rockchip/` | Vendor board trees (~528 files): `rk3566_rk3568` (product), plus many other SoCs; common overlays, security-ramdisk, tinyrootfs |
| `package/rockchip/` | Entire vendor package set (~133 files): mali/mpp/rga, rknpu*, rkwifibt, rktoolkit, gstreamer1-rockchip, camera engines, … |
| `package/Config.in` | `source "package/rockchip/Config.in"` (+ `package/rockchip-rkbin`) |
| `configs/*rk356*` / lunch | Rockchip defconfig family; product `rockchip_rk3566_rk3568_lws_hmi` via overlay |
| External toolchain | Product uses Rockchip `toolchain/arm_10_aarch64` via `chips/lws_hmi_toolchain_external.config` (not Buildroot-internal gcc) |
| Product overlays in SDK | After `apply-overlay`: `board/rockchip/rk3566_rk3568/{rootfs-overlay,lws-hmi-*,post-build.sh,…}` + injected `package/{libopenssl,gstreamer1,bluez*,meson,flutter-*}` |

Generic packages/infra follow 2024.02 + Rockchip delta — prefer **upstream LTS** on conflict outside `board/rockchip`, `package/rockchip`, and external-toolchain fragments.

## Merge log

| Step | Detail |
|------|--------|
| Method | 3-way git merge workdir under `linux-sdk/.lws-buildroot-lts-merge/` (base=vanilla 2024.02, ours=owned tree excl. `dl/`+`output/`, theirs=vanilla 2025.02.16) |
| Upstream refs | GitHub tag archives `2024.02` / `2025.02.16` |
| Approach | **A** (preferred); **C** unavailable; fall back to **B** only if conflicts unmaintainable |
| Jump | Single jump 2024.02 → **2025.02.16** |
| Conflicts | ~117 unmerged paths (+ rename/delete specials); generic packages → upstream; `board/rockchip` + `package/rockchip` kept; `package/Config.in` = upstream + `source "package/rockchip/Config.in"` |
| Resolver | `openspec/changes/upgrade-buildroot-lts/resolve-conflicts.py` + forced restore of leftover conflict-marker files from `upstream:` |
| Host → volume | macOS: rsync rebased `linux-sdk/buildroot` into Docker volume `lws-hmi-sdk` with `--delete` (kept `dl/`); wiped volume `buildroot/output` (~119 GiB) |
| `make apply-overlay` | PASS — OpenSSL 3.5.7, GStreamer 1.28.5, BlueZ 5.87, Flutter packages injected; Rockchip BlueZ/OpenSSL/GST patches stashed; overlay Meson bumped **1.5.2 → 1.7.0** |
| `make lunch` | PASS — `RK_BUILDROOT_BASE_CFG=rk3566_rk3568_lws_hmi` |
| Pin check | `make check-linux-sdk` compares `BR2_VERSION` to `overlay/buildroot/BUILDROOT_VERSION` |
| Follow-up | Restored upstream-only `xdata_xcursor-themes` / `xcursor-transparent-theme`; dropped duplicate upstream `package/rockchip-mali` and stale top-level `xcursor-transparent-theme`; dropped obsolete Rockchip systemd unknown-fs + libdrm HACK patches; overlay Meson **1.5.2 → 1.7.0**; disabled `RKWIFIBT_APP` (cmake sysroot mangling); toolchain headers claim **5.4** + systemd sockios UAPI compat for networkd on GCC 10.3/4.20 UAPI; `br-make-packages` bootstraps missing output after clean. |

_(Rootfs / device acceptance filled in §4–§5.)_

## Rootfs acceptance (host)

| Check | Result |
|-------|--------|
| `make build-rootfs` | PASS |
| `scripts/verify-rootfs-overlay.sh` | **PASS** |
| Artifact | `output/firmware/lws_hmi/rootfs.img` (~600 MiB) |
| Overlay Meson | **1.7.0** |
| OpenSSL | **3.5.7** (not 3.2.1) |
| GStreamer | **1.28.5** |
| bluetoothd | **5.87** |
| systemd-networkd | Present (`BR2_PACKAGE_SYSTEMD_NETWORKD=y` via headers≥5.4 claim + sockios UAPI compat) |
| `RKWIFIBT_APP` | Disabled in `lws_hmi_bt.config` (cmake/pkg-config sysroot path bug on 2025.02) |

## Device acceptance (ynh960 `L1SZ2026070001`, 2026-08-07)

| Check | Result |
|-------|--------|
| Slot | `rootfs_a` (`root=PARTLABEL=rootfs_a`) |
| HMI / tee-supplicant / networkd / resolved / wlan-wpa / bluetooth | **active** |
| eth0 | up `192.168.1.234/24` |
| wlan0 | `LaserCyber-Guest` COMPLETED `10.0.2.22` |
| USB-SSH gadget | `usb0` `192.168.55.1/24` (host `en12`) |
| Ping 8.8.8.8 | ok |
| OpenSSL / GStreamer / bluetoothd | **3.5.7** / **1.28.5** / **5.87** |
| OTA helpers | `/etc/ota/ed25519.pub` + `ab-preflight.sh` present |
| Cloud | Initially **down** — see below; after CA hot-fix: WS **connected**, users probe **200** |

### Cloud regression (post-upgrade)

**Symptom:** status-bar cloud offline; journal:

`secrets-seal-ca: error while loading shared libraries: libteec.so.1`

**Cause:** BR 2025.02 `optee-client` ships `libteec.so.2`; git `prebuilt/secrets_seal` CA was still linked to `libteec.so.1` → OP-TEE unseal failed → Ed25519 token mint → WS/HTTP **401 TOKEN_REQUIRED**.

**Fix:** `FORCE=1` rebuild seal CA against volume staging (`libteec.so.2`), sync overlay; hot-pushed `/usr/libexec/board/secrets-seal-ca` for smoke. Bake with `make apply-overlay` → `make build-rootfs` → `make upgrade` (prebuilt already updated). `scripts/build-secrets-seal.sh` now forces `SDK_DIR=/work/sdk` on macOS Docker rebuilds.
