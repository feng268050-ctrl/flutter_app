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

Platform kernel DTS/config/patches and stable device script patches
(`mk-rootfs`, `post-wifibt`, …) are squashed into the owned tree by
`make squash-linux-sdk-platform` (also run at end of trim). After that,
`make apply-overlay` **skips** those platform steps when `.lws-owned-tree`
exists (`FORCE_PLATFORM_OVERLAY=1` to force re-apply).

**Third-party / custom Buildroot packages stay on overlay** — do not move
`overlay/buildroot/package/**` or `overlay/third-party/**` into `linux-sdk`.

## Device tree / kernel fragments (until S4)

`linux-sdk/` is **not** in git. Colleagues cannot sync edits that live only under
`linux-sdk/kernel-6.1/...`. Until S4 (SDK tracked), keep this policy:

| Layer | Role |
|-------|------|
| **`overlay/kernel/`** | **Git source of truth** for product board DTS/DTSI fragments (ynh960 today; later ynh961/ynh962), kconfig fragments, and kernel patches |
| **`board/rk356x-fit-boards.txt`** | SoC-family **FIT board inventory** — one `board_id` per line; drives multi-conf ITS generation (`scripts/generate-boot-fit-its.sh`) |
| **`linux-sdk/.../dts/rockchip/`** | Local build tree after squash / `FORCE_PLATFORM_OVERLAY=1`; not a sync channel |
| **`oem/`** | **Not** for boot DTBs. U-Boot loads FIT (kernel+DT) before `/oem` is mounted. OEM may carry runtime LCD params (`screens/.../lcd/`), profile identity, helpers — never the startup device tree |

### Multi-configuration boot FIT (platform W5)

`make build-kernel` packs **one** shared `Image` plus **N** flattened DTs into dual A/B FITs (`boot.img` / `boot_b.img`) using `board/boot-multi.its` (generated from the inventory; active via `RK_BOOT_FIT_ITS_NAME="boot-multi.its"`).

| Rule | Detail |
|------|--------|
| Conf name | Equals product `board_id` / OEM `manifest.json` `board_id` (default / first ship: `ynh960`) |
| FDT node | `fdt-<board_id>` in the ITS; DTB file is `rockchip/<board_id>.dtb` |
| Selection | U-Boot **before** Linux: Innohi `boot_fit` boots the FIT **default** conf; non-default boards use `bootm <addr>#<board_id>` (or factory env — see `openspec/changes/multi-board-fit-dt/design.md`) |
| Emulator | P3.2 still uses bare `Image` + QEMU `virt` DT — **no** `sim` / `conf-sim` in the product FIT |
| OEM | Declares which conf that SKU expects; does **not** supply startup DTB |

Inspect / gate: `scripts/verify-boot-fit.sh <firmware-dir>` lists conf names, fails on missing inventory DTBs or oversized FIT.

**Workflow for DT / kernel fragment changes (shareable):**

```text
1. Edit overlay/kernel/rockchip/*.dtsi|*.config (and patches under overlay/kernel/patches/)
2. If adding a product board to the shared Image FIT: append board_id to board/rk356x-fit-boards.txt
   and land that board’s DTS under overlay/kernel/ (then regenerate ITS via apply-overlay / generate script)
3. Commit those overlay (+ inventory) paths in this repo
4. On each machine with an owned SDK:
     FORCE_PLATFORM_OVERLAY=1 make apply-overlay
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

- **Authoritative binaries:** `prebuilt/bootloader/<uboot_id>/` (see `board/factory-skus.tsv`).
- **`linux-sdk/u-boot/`:** absent after trim (unless you ran `make fetch-uboot` for optional
  source). `make build-img` creates the directory temporarily and copies loader/uboot from
  prebuilt for Rockchip pack scripts — not a persistent store.

## Git strategy (deferred)

- Keep repo `.gitignore` entry `linux-sdk/`.
- When ready to track source: LFS or `prebuilt/` for Mali/firmware; add nested
  ignore for `linux-sdk/buildroot/dl/`, `linux-sdk/buildroot/output/`,
  `linux-sdk/output/` (trim already installs a local `linux-sdk/.gitignore`
  with those rules for the day the tree is tracked).
- Do not `git add linux-sdk` until that policy is executed deliberately.
