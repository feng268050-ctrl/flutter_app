## Context

Today `board/boot-slim.its` embeds one `@KERNEL_DTB@` and one `configurations/conf`. Lunch pins `RK_KERNEL_DTS_NAME="ynh960"`. Product overlays under `overlay/kernel/rockchip/ynh960-*.dtsi` are include-patched into `customer_board_ynh960.dtsi`. A/B only duplicates the FIT with different `root=` letters (`boot.img` / `boot_b.img`), not different boards.

Platform plan §4 already states “SoC 族内核 + 该主板 DT（或 DTBO 列表）” and “一族多板”, but no wave implemented multi-conf packaging. P3.2 proved **same Image + different DT source** only for QEMU virt (bare `-kernel`), not for product FIT. `kernel-61-lts-rebase` will churn the entire `overlay/kernel/` surface — doing multi-DT packaging **after** that rebase forces a second packaging rewrite on a moving baseline.

Constraints:

- Startup DT MUST remain in FIT (U-Boot before `/oem`).
- Boot partition ~64 MiB; slim ITS already dropped `resource.img`.
- Product U-Boot is prebuilt Innohi/SKU (`FACTORY_SKU` / `UBOOT_ID`), not self-built in the daily path.
- Near-term boards: ynh960 / ynh962 / ynh961 (RK3566 / RK3568B2 / RK3568) — same Rockchip 356x family, one shared Image goal.

## Goals / Non-Goals

**Goals:**

- One SoC-family `Image` packaged with **multiple FDT images** and **named FIT configurations**.
- Stable conf naming tied to `board_id`; default remains ynh960.
- Documented U-Boot selection path (env / `bootm` conf) + OEM manifest alignment.
- Build/verify gates for FIT size and conf inventory.
- Explicit platform **W5** and **ordering before** `kernel-61-lts-rebase`.
- ynh960 continues to boot unchanged as the first conf.

**Non-Goals:**

- Runtime motherboard autodetection in Linux or OEM.
- Shipping startup DTB via `/oem`.
- Cross-SoC-family single FIT (e.g. RK356x + unrelated vendor in one Image) in this change.
- Replacing QEMU path with a FIT conf for `virt`.
- Implementing full ynh961/ynh962 hardware bring-up DTS (may be follow-on once packaging exists).
- Self-compiling product U-Boot unless prebuilt cannot select conf (then minimal documented env/script only).

## Decisions

### D1 — Shared kernel node + N `flat_dt` images in one ITS

- **Choice:** Extend / replace `boot-slim.its` so `images` contains one `kernel` and `fdt-<board_id>` (or equivalent) per board; `configurations` contains `conf-<board_id>` each referencing the shared kernel + that FDT. A/B still produces two FITs differing only in embedded cmdline / root letter as today.
- **Why:** Matches U-Boot FIT multi-conf model; avoids N full kernel copies.
- **Alternatives:** N separate `boot.img` per board (defeats one-firmware goal); DTBO-only stack on one base DTB (harder with current full-board customer DTS includes).

### D2 — Configuration name = `board_id`

- **Choice:** FIT conf id / node name derives from OEM/HAL `board_id` (`ynh960`, later `ynh961` / `ynh962`). Default configuration = `ynh960` until factory/U-Boot env overrides.
- **Why:** One string across OEM manifest, factory SKU, and FIT; avoids parallel naming tables.
- **Alternatives:** Numeric conf indices (opaque); DTB filename-only selection without FIT conf (weaker hash/rollback story).

### D3 — Selection at U-Boot, not in Linux

- **Choice:** Product boot picks FIT configuration **before** kernel entry (U-Boot env such as `lws_fit_conf` / `bootargs` helper / `bootm ${fit}#conf-<id>`). Linux assumes the loaded DT is already correct. OEM `board_id` MUST match that conf for compose/verify; OEM does not load DT.
- **Why:** DT must be correct for clocks/display before userspace; matches platform plan.
- **Alternatives:** Linux EFI stub / grub-style (not this boot chain); DT from userdata (too late / unsafe).

### D4 — v1 acceptance = packaging + ynh960 boot; second board optional

- **Choice:** Land multi-conf ITS + board list + verify even if only `ynh960` DTB is produced initially. Adding `ynh961`/`ynh962` is a follow-up DTS task that plugs into the same list. Optionally include a **build-only** second conf that reuses the ynh960 DTB under a dry-run name **only if** needed to prove multi-fdt linking — prefer real second DTS when available; do not ship fake conf names to devices.
- **Why:** Unblocks kernel LTS work on the right packaging shape without waiting for 961 hardware.
- **Alternatives:** Block until three boards exist (too late); ship duplicate fake confs in production FITs (confusing).

### D5 — Sequence before kernel LTS / patch upgrades

- **Choice:** Complete this change’s packaging scaffolding (and ynh960 regression) **before** starting `kernel-61-lts-rebase` implementation. Document in both changes: multi-DT is a prerequisite; LTS rebase rebases **all** listed board overlays.
- **Why:** Avoid rebasing single-board ITS then redesigning FIT under LTS conflict noise.
- **Alternatives:** Do LTS first (user explicitly rejected); parallel tracks (merge risk).

### D6 — Emulator unchanged

- **Choice:** Keep `make emulator` on bare `Image` + QEMU-generated virt DT; do not add `conf-sim` to product FIT.
- **Why:** Already works; virt is not a Rockchip board DT; keeps FIT size focused on product boards.

### D7 — Board inventory as build input

- **Choice:** Maintain an explicit SoC-family board list (e.g. under `board/` or `overlay/kernel/`) consumed by FIT generation / lunch, rather than discovering random `*.dtb` in the tree.
- **Why:** Deterministic FIT contents and verify scripts; matches factory “compile-time SKU” philosophy.

## Risks / Trade-offs

- **[Risk] Prebuilt U-Boot cannot select non-default FIT conf** → Mitigation: spike early (task 0); if blocked, document required uboot env patch or SKU-specific default conf baked at factory pack time (still multi-FDT Image for OTA uniformity).
- **[Risk] FIT exceeds 64 MiB with 3 DTBs** → Mitigation: keep slim ITS (no resource); measure; trim unused EVB DT; fall back to DTBO strategy only if needed.
- **[Risk] Wrong conf + matching OEM still “looks fine” until peripherals fail** → Mitigation: compose/verify checks `board_id` vs boot-selected conf when detectable (`/proc/device-tree` model / chosen); factory flashing sets both together.
- **[Risk] Scope creep into full 961/962 bring-up** → Mitigation: D4 — packaging first; per-board DTS are separate tasks.
- **[Trade-off] One Image must enable drivers for all family boards** → Accept larger kernel (already includes emulator-virtio); trim carefully per family, not per SKU fork.

## Migration Plan

1. Add board inventory + multi-conf ITS generator; default conf `ynh960`.
2. `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` → `make build-kernel`; confirm `boot.img` lists multiple configs when N>1 (or single named conf when N=1).
3. Flash/upgrade ynh960; smoke display/net/HMI.
4. Update platform plan W5 ✅; mark `kernel-61-lts-rebase` unblocked for implement.
5. Rollback: previous single-fdt FIT via A/B inactive letter if upgrade fails.

## Open Questions

1. Exact U-Boot API on Innohi prebuilt (`bootm#conf-…` vs scripted `iminfo` / env) — resolve in spike task.
2. Whether factory packs a **board-specific default conf** into U-Boot env at `build-img` time while still shipping the full multi-FDT FIT for field OTA.
3. When ynh961/ynh962 DTS work is scheduled relative to first multi-conf ship (packaging does not require them).
