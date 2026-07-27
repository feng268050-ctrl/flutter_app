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
| **`overlay/kernel/`** | **Git source of truth** for ynh960 DTS/DTSI fragments, kconfig fragments, and kernel patches that this product owns |
| **`linux-sdk/.../dts/rockchip/`** | Local build tree after squash / `FORCE_PLATFORM_OVERLAY=1`; not a sync channel |
| **`oem/`** | **Not** for boot DTBs. U-Boot loads FIT (kernel+DT) before `/oem` is mounted. OEM may carry runtime LCD params (`screens/.../lcd/`), profile identity, helpers — never the startup device tree |

**Workflow for DT / kernel fragment changes (shareable):**

```text
1. Edit overlay/kernel/rockchip/*.dtsi|*.config (and patches under overlay/kernel/patches/)
2. Commit those overlay paths in this repo
3. On each machine with an owned SDK:
     FORCE_PLATFORM_OVERLAY=1 make apply-overlay
   # or: make squash-linux-sdk-platform
4. make build-kernel
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
