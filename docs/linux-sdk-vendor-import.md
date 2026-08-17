# linux-sdk vendor import (W3 owned tree)

Canonical record for the Rockchip / Innohi blueprint used to seed the local
**owned** `linux-sdk/` tree. The repo keeps this file under `docs/`;
`make trim-linux-sdk` (and `TRIM=1 make extract-linux-sdk`) copies it to
`linux-sdk/VENDOR_IMPORT.md` on the developer machine.

`linux-sdk/` remains **gitignored** (and listed in `.cursorignore`) so the tree
is not committed yet — avoids monorepo / IDE index freezes. Future commit will
use Git LFS or `prebuilt/` for large binaries (Mali `.so`, firmware); never
commit `buildroot/dl/`, `buildroot/output/`, or `output/`.

## Blueprint

| Field | Value |
|-------|--------|
| Supplier | Innohi / Rockchip RK356x Linux 6.1 SDK |
| Import method | `make extract-linux-sdk SRC=<xz volumes>` |
| Host path | repo-root `linux-sdk/` (Docker volume `/work/sdk` on macOS) |
| Whitelist | [`board/linux-sdk-whitelist.txt`](../board/linux-sdk-whitelist.txt) |
| Ownership marker | `linux-sdk/.lws-owned-tree` |

Fill in when re-importing a new vendor drop:

| Field | Value |
|-------|--------|
| Package / archive name | _(e.g. rk356x_linux6.1_…)_ |
| Import date (UTC) | _(YYYY-MM-DD)_ |
| Notes / gaps vs ynh960 | _(link or short list)_ |

## Workflow

```text
# Fresh extract + trim + platform squash
TRIM=1 make extract-linux-sdk SRC=/path/to/volumes

# Or trim an existing full tree
make trim-linux-sdk
make check-linux-sdk

# Product / OEM / third-party packages (always overlay)
make apply-overlay

# macOS: refresh Docker volume after trim (deleted dirs otherwise linger)
make docker-volume-init
# or: make docker-volume-sync
```

Platform kernel **patches** and stable device script patches
(`mk-rootfs`, `post-wifibt`, …) are squashed into the owned tree by
`make squash-linux-sdk-platform` (also run at end of trim). After that,
`make apply-overlay` **skips those patch steps** when `.lws-owned-tree`
exists (`FORCE_PLATFORM_OVERLAY=1` to force re-apply). DTS, kconfig
fragments, firmware, logo, and rootfs overlay **still sync every apply**.

**Third-party / custom Buildroot packages stay on overlay** — do not move
`overlay/buildroot/package/**` or `overlay/third-party/**` into `linux-sdk`.

## Kernel 6.1 LTS pin

Owned `linux-sdk/kernel` tracks the Linux **6.1.y** long-term stable line.
Product policy (see `openspec/changes/kernel-61-lts-rebase`): catch up via **full
stable merge**, not a primary CVE cherry-pick stack under `overlay/kernel/patches/`.

| Field | Value |
|-------|--------|
| Pin (`uname -r` / `Makefile` `SUBLEVEL`) | **6.1.180** |
| Floor | ≥ 6.1.180 |
| Locked | 2026-08-03 from [kernel.org releases.json](https://www.kernel.org/releases.json) (`longterm` 6.1.180) |
| Git-readable pin file | [`overlay/kernel/KERNEL_6_1_SUBLEVEL`](../overlay/kernel/KERNEL_6_1_SUBLEVEL) (one integer = `SUBLEVEL`) |

Until `linux-sdk/` is committed, colleagues without a populated SDK still learn the
expected release from that overlay pin file and this section. After a tip bump,
update **both** this table and `KERNEL_6_1_SUBLEVEL`, then re-apply overlay and
rebuild the dual FIT.

## Buildroot 2025.02.x LTS pin

Owned `linux-sdk/buildroot` tracks the Buildroot **2025.02.x** long-term support
line (not the three-month stable). Product policy (see
`openspec/changes/upgrade-buildroot-lts`): catch up via **full LTS tip merge**
into the Rockchip/Innohi tree, not a primary package cherry-pick stack on frozen
2024.02. Git-tracked product fragments and package pins stay under
`overlay/buildroot/` and are re-injected by `make apply-overlay`.

| Field | Value |
|-------|--------|
| Pin (`BR2_VERSION`) | **2025.02.16** |
| Floor | ≥ 2025.02.16 |
| Locked | 2026-08-07 from [buildroot.org/downloads](https://buildroot.org/downloads/) (newest `2025.02.*`) |
| Git-readable pin file | [`overlay/buildroot/BUILDROOT_VERSION`](../overlay/buildroot/BUILDROOT_VERSION) (one line `2025.02.<n>`) |
| Merge approach | **A** — 3-way merge (vanilla 2024.02 / owned Rockchip tree / vanilla 2025.02.16) under `linux-sdk/.lws-buildroot-lts-merge/` |
| Vendor drop ≥ floor? | No Innohi SDK on 2025.02.x at lock time |

Until `linux-sdk/` is committed, colleagues without a populated SDK still learn the
expected Buildroot tip from that overlay pin file and this section. After a tip
bump, update **both** this table and `BUILDROOT_VERSION`, then
`make clean-buildroot-output`, `make apply-overlay`, `make lunch`, and
`make build-rootfs` (do **not** reuse 2024.02 `buildroot/output` stamps).

### Colleague sync (gitignored Buildroot)

Each machine must obtain a rebased `linux-sdk/buildroot` matching the pin. Either:

1. **Replay the merge runbook** (preferred while no shared artifact exists): download
   vanilla `2024.02` + locked tip tag archives, 3-way merge into a workdir with the
   current owned tree as “vendor”, rsync result into `linux-sdk/buildroot` (preserve
   `dl/` / wipe `output/`), then `make apply-overlay`. Details:
   `openspec/changes/upgrade-buildroot-lts/notes.md`.
2. **Replace from a shared internal artifact** once one is published (tarball or
   volume snapshot of the rebased tree). Overlay + pin file still ship via normal PR.

macOS: after replacing Buildroot, refresh the Docker volume
(`make docker-volume-init` or `make docker-volume-sync`).

### Kernel directory layout (canonical `kernel/`)

The owned SDK uses a single **`linux-sdk/kernel/`** source tree (no `kernel-6.1`
sibling and no `kernel` → `kernel-6.1` symlink). Rockchip `build.sh` already
uses `$SDK/kernel`; the old versioned sibling was vendor convention only.

**One-time migration** (host `linux-sdk/` or inside the Docker volume):

```bash
cd linux-sdk   # or /work/sdk in the builder container
rm -f kernel   # drop symlink if present
mv kernel-6.1 kernel
```

macOS with Docker volume: migrate the host tree first, then sync into the volume:

```bash
# host (repo-root linux-sdk/)
rm -f linux-sdk/kernel && mv linux-sdk/kernel-6.1 linux-sdk/kernel
make docker-volume-sync
```

Or migrate directly in the volume (no full rsync):

```bash
docker run --rm --platform linux/amd64 -v lws-hmi-sdk:/work/sdk \
  lws-hmi-builder:22.04 bash -c 'cd /work/sdk && rm -f kernel && mv kernel-6.1 kernel'
```

After migration, run `make apply-overlay` (or `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`
once) so the owned `patch-mk-kernel.sh` lands in the SDK’s `mk-kernel.sh`.

## Device tree / kernel fragments (until S4)

`linux-sdk/` is **not** in git. Colleagues cannot sync edits that live only under
`linux-sdk/kernel/...`. Until S4 (SDK tracked), keep this policy:

| Layer | Role |
|-------|------|
| **`overlay/kernel/rockchip/`** | **Git source of truth** for product board trees: `ynh960.dts`, `customer_board_ynh960.dtsi`, `ynh960-*.dtsi`, **`ek3562.dts`** + RK3562 EVB2 board `.dtsi` (see `ek3562.md`), plus `*.config` fragments and kernel patches under `overlay/kernel/` |
| **`board/rk356x-fit-boards.txt`** | SoC-family **FIT board inventory** — one `board_id` per line; drives multi-conf ITS generation (`scripts/generate-boot-fit-its.sh`) |
| **`linux-sdk/.../dts/rockchip/`** | **Build mirror only** — `make apply-overlay` copies `overlay/kernel/rockchip/*.dts*` here; do not edit product DTS only in the SDK |
| **`oem/`** | **Not** for boot DTBs. U-Boot loads FIT (kernel+DT) before `/oem` is mounted. OEM may carry runtime LCD params (`screens/.../lcd/`), profile identity, helpers — never the startup device tree |

**Vendor baseline:** the owned `linux-sdk/` tree is already customized (not a live
vendor tracking branch). Product DTS, drivers, and helpers move into **`overlay/`**
as git SoT. Do **not** plan on merging future Innohi SDK drops into `linux-sdk/` —
when something new is needed, copy the specific component into `overlay/` (same model
as ek3562 and selective Wi‑Fi/driver imports).

| Git path | Synced to SDK by `apply-overlay` | Used for |
|----------|----------------------------------|----------|
| `overlay/kernel/rockchip/*.dts*` | `kernel/arch/arm64/boot/dts/rockchip/` | FIT DTBs |
| `overlay/kernel/drivers/net/wireless/aic8800/` | `kernel/drivers/net/wireless/aic8800/` | AIC8800 combo driver |
| *(removed)* `overlay/kernel/innohi/` | removed; hooks stripped from `kernel/Kconfig` + `Makefile` | `gpio_innohi` retired |
| `overlay/kernel/drivers/gpu/drm/panel/panel-simple.c` | `kernel/drivers/gpu/drm/panel/panel-simple.c` | Rockchip `develop-6.1` pre-`65f19639` (DT `panel-init-sequence`; matches SDK `panel-simple.h`) |
| `overlay/board/rockchip/common/rootfs-overlay/usr/lib/udev/rules.d/61-partition-init.rules` | rootfs overlay | `/dev/block/by-name`, `/dev/disk/by-partlabel` |

`innohi/net/wireless/*` (250MB+ Realtek/QCA trees) is **not** in git; `CONFIG_INNOHI_NET=n`.
ek3562 Wi‑Fi uses mainline `rtw88` + `linux-firmware`, not vendor RTL8821CU.

### Multi-configuration boot FIT (platform W5)

`make build-kernel` packs **one** shared `Image` plus **N** flattened DTs into dual A/B FITs (`boot.img` / `boot_b.img`) using `board/boot-multi.its` (generated from the inventory; active via `RK_BOOT_FIT_ITS_NAME="boot-multi.its"`).

**Design intent (ARM standard):** one **universal `Image`** per product-line kernel build (all in-line SoC drivers enabled via `overlay/kernel/**/*.config`); **per-board / per-hardware `board_id` DTB** in the FIT. Adding a motherboard does **not** fork Image — add DTS + inventory line + OEM. Adding a new SoC (e.g. RK3562 alongside RK3566) merges drivers into the **same** Image Kconfig, rebuilds Image once (`FORCE_KERNEL_IMAGE=1`), then adds that SoC’s board DTBs to the inventory. **No second `linux-sdk`.** Board-vendor deliverables (DTS, LCD tables, U-Boot/MiniLoader) land in `overlay/kernel/`, `board/`, `prebuilt/bootloader/`, `oem/` — see [`docs/make-commands.md`](make-commands.md) → **构建模型**.

| Rule | Detail |
|------|--------|
| Conf name | Equals product `board_id` / OEM `manifest.json` `board_id` (default / first ship: `ynh960`) |
| FDT node | `fdt-<board_id>` in the ITS; DTB file is `rockchip/<board_id>.dtb` |
| **Image blob** | **Same file** embedded in every conf — only DTB (and slot `resource.img`) differs |
| Selection | U-Boot **before** Linux: Innohi `boot_fit` boots the FIT **default** conf; non-default boards use `bootm <addr>#<board_id>` (or factory env — see `openspec/changes/multi-board-fit-dt/design.md`) |
| Emulator | P3.2 still uses bare `Image` + QEMU `virt` DT — **no** `sim` / `conf-sim` in the product FIT |
| OEM | Declares which conf that SKU expects; does **not** supply startup DTB |
| U-Boot / MiniLoader | Per `FACTORY_SKU` → `prebuilt/bootloader/<uboot_id>/` (`board/factory-skus.tsv`); **not** inside FIT |

Inspect / gate: `scripts/verify-boot-fit.sh <firmware-dir>` lists conf names, fails on missing inventory DTBs or oversized FIT.

**Workflow for DT / kernel fragment changes (shareable):**

```text
1. Edit overlay/kernel/rockchip/*.dtsi|*.config (and patches under overlay/kernel/patches/)
2. If adding a product board to the shared Image FIT: append board_id to board/rk356x-fit-boards.txt
   and land that board’s DTS under overlay/kernel/ (then regenerate ITS via apply-overlay / generate script)
3. Commit those overlay (+ inventory) paths in this repo
4. On each machine with an owned SDK:
     make apply-overlay
   # patches / mk-* scripts only:
   # FORCE_PLATFORM_OVERLAY=1 make apply-overlay
   # or: make squash-linux-sdk-platform
5. make build-kernel
   make upgrade   # (and build-rootfs when rootfs also changed)
```

Owned-tree skip (`apply-overlay` without `FORCE_PLATFORM_OVERLAY`) only avoids
**re-applying** an already-squashed baseline; it does **not** mean “edit SDK only
and skip overlay.” New DT work must land in `overlay/kernel/` first (or land in
both: edit SDK for local spike, then **copy back** into overlay before push).

Do not invent a parallel DT store under `oem/` to work around gitignore.

## U-Boot layout

- **Delivery binaries:** `prebuilt/bootloader/<uboot_id>/` (see `board/factory-skus.tsv`) —
  **self-built or vendor-validated** `uboot.img` + MiniLoader. How to build from
  Rockchip `u-boot` + `rkbin`/`boot_merger`: [`docs/uboot-rkbin.md`](uboot-rkbin.md).
- **`linux-sdk/u-boot/`:** populated by `make fetch-uboot` (clones
  `rockchip-linux/u-boot`). `make build-img` also stages loader/uboot from
  prebuilt for Rockchip pack scripts.
- **Policy:** compiling U-Boot is expected for new boards once DTS matches;
  do not flash an **unvalidated** pair onto a shipping SKU.

## Git strategy (deferred)

- Keep repo `.gitignore` entry `linux-sdk/`.
- When ready to track source: LFS or `prebuilt/` for Mali/firmware; add nested
  ignore for `linux-sdk/buildroot/dl/`, `linux-sdk/buildroot/output/`,
  `linux-sdk/output/` (trim already installs a local `linux-sdk/.gitignore`
  with those rules for the day the tree is tracked).
- Do not `git add linux-sdk` until that policy is executed deliberately.
