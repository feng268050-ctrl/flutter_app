## Why

Platform docs already say one SoC-family firmware should carry **per-board device trees** in the boot FIT, with OEM only declaring identity — but **implementation still ships a single-FDT FIT** (`board/boot-slim.its` → one `fdt` + one `conf`). ynh960/961/962 share the near-term “one firmware” goal while P1–P4 still validate on ynh960 alone. Without a multi-DT packaging + selection contract **before** large kernel work (`kernel-61-lts-rebase` and further overlay patches), every LTS merge and DT delta stays wired to a single-board ITS and is harder to generalize later.

## What Changes

- Introduce a **multi-configuration FIT** build: one shared `Image`, **N** flattened DTs, **N** FIT `configurations` (named per board id), still dual-letter `boot.img` / `boot_b.img` for A/B root choice.
- Keep **`overlay/kernel/`** as git SoT for per-board DTS/DTSI/fragments; stop treating `RK_KERNEL_DTS_NAME="ynh960"` as the only long-term packaging shape.
- Define **boot-time DT selection** (U-Boot conf name / env) for product boards; OEM continues to declare `board_id` and MUST align with the selected FIT conf — DT itself stays out of `/oem`.
- Leave **P3.2 emulator** on bare `-kernel Image` + QEMU `-machine virt` DT (not a second FIT conf).
- Sequence this change **before** `kernel-61-lts-rebase` (and treat subsequent kernel patch/LTS work as consumers of the multi-DT layout).
- Update `docs/platform-os-oem-sdk-plan.md` with an explicit platform wave (**W5**) so the earlier “一族多板” line is no longer an orphan principle.
- First shippable milestone MAY still boot **only ynh960** hardware, but the FIT/ITS/build path MUST already be multi-board-shaped (second board conf can land when that DTS exists).

## Capabilities

### New Capabilities

- `boot-fit-multi-dt`: Multi-FDT FIT packaging, configuration naming, boot selection contract, size/verify gates, and ordering vs kernel LTS/patch work.

### Modified Capabilities

- `buildroot-lws-hmi-image`: Dual FIT artifacts MUST be built from a multi-configuration ITS (or successor), not a single anonymous `fdt`/`conf` only.
- `linux-sdk-own-tree`: Overlay/kernel SoT MUST support multiple board DTS targets applied into the owned tree; lunch/packaging MUST list boards for the SoC family Image.
- `oem-pack`: OEM `board_id` / manifest MUST document which FIT configuration name that pack expects; mismatch is a compose/verify failure, not a silent wrong DT.
- `p32-utm-guest`: Clarify emulator remains bare `Image` + QEMU virt DT (explicit non-goal for FIT multi-conf).

## Impact

- Build: `board/boot-slim.its` (or replacement), lunch/`RK_*` FIT hooks, `scripts/apply-overlay.sh` / kernel DTS inject, `make build-kernel`, partition size verify (`boot` ~64 MiB).
- Boot: Innohi/prebuilt U-Boot must select FIT conf (env, boot script, or fixed default); may need documented uboot env or factory SKU wiring — not a full self-built U-Boot rewrite in v1 if prebuilt already supports `#conf-<name>`.
- Docs: `docs/platform-os-oem-sdk-plan.md` (W5 + sequencing), `docs/linux-sdk-vendor-import.md`, AGENTS rebuild notes if Make targets change.
- Depends-on / blocks: **blocks** starting implementation of `openspec/changes/kernel-61-lts-rebase` until multi-DT FIT scaffolding is landed (or explicitly waived); LTS rebase then rebases **all** board DTS fragments onto the new baseline.
- Non-goals here: cross-SoC-family single FIT; putting startup DTB in OEM; per-SKU kernel defconfig forks; Flutter P5.1 engine upgrade.
