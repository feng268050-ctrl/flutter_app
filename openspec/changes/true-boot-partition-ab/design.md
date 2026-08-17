## Context

P2.4 already pairs GPT `boot`/`boot_b` with `rootfs_a`/`rootfs_b`, builds dual FITs (`boot.img` / `boot_b.img` with per-slot `resource.img` PARTLABEL + RSCE SHA-1), and stores active/try/previous on misc `LWSAB` @ 1 MiB. Because vendor (and today’s Linux-first) `boot_fit` only opens GPT **`PARTNAME=boot`**, try-boot **copies** the live FIT to `boot_b` and writes the try FIT into `boot`; rollback **swaps** the two partitions. Self-built U-Boot (`make build-uboot`, `linux-first-uboot`) removes the “cannot change boot_fit” constraint without requiring GPT rename.

## Goals / Non-Goals

**Goals:**

- U-Boot loads FIT from **`boot`** when letter is A and **`boot_b`** when letter is B (respecting try-boot arming).
- OTA writes the inactive letter’s FIT **only** to that letter’s boot partition; no 64 MiB backup copy; rollback updates misc only (no partition content swap).
- Keep existing PARTNAMEs, dual FIT build, rootfs inactive write, Ed25519 staged OTA, and flash-only uboot/SPL.

**Non-Goals:**

- Dual uboot/SPL partitions or bootloader OTA.
- Renaming GPT A to `boot_a` (optional later; not required for true partition select).
- Android BCB or vendor boot-control block at misc `0x0800`.
- Changing RockUSB `di` “write both letters” factory/upgrade semantics.

## Decisions

### 1. Keep PARTNAMEs `boot` / `boot_b` (no `boot_a` rename)

- **Choice:** Letter A continues to use partition name `boot`; B uses `boot_b`.
- **Why:** Avoids GPT repartition / one-shot `flash` for layout; existing factory images and RockUSB names stay valid.
- **Alternative considered:** Rename to `boot_a`/`boot_b` for symmetry — clearer naming, but **BREAKING** parameter + field flash; deferred.

### 2. U-Boot reads misc `LWSAB` for partition select

- **Choice:** Extend self-built U-Boot (source patch applied during `make build-uboot`) so `boot_fit` (or a thin wrapper command before it) resolves:
  - If `try_boot` ∈ {`A`,`B`} → load that letter’s boot partition.
  - Else → load `active` letter’s boot partition.
  - Mapping: `A`→`boot`, `B`→`boot_b`.
  - Corrupt/missing marker → fail safe to `boot` (letter A), matching today’s factory default.
- **Why:** Linux and U-Boot already share this marker; avoids inventing a second source of truth or touching vendor `0x0800`.
- **Alternative considered:** U-Boot env only — drifts from Linux confirm path; rejected.
- **Tries:** Prefer keep try-budget decrement in Linux `ab-boot-confirm` (unchanged). Optional U-Boot try decrement is out of scope unless lab shows Linux never runs after a bad FIT.

### 3. Apply writes inactive boot partition only

- **Choice:** Replace `ab_arm_try_boot_fit` backup+write-`boot` with: resolve inactive letter → `dd` correct FIT file (`boot.img` for A, `boot_b.img` for B) to that letter’s partition → arm misc → reboot.
- **Rollback:** Clear try / restore `active`=`previous` in misc; **do not** swap partition bytes. Previous FIT remains intact on the previous letter’s partition.
- **Confirm commit:** Set `active` to try letter, clear try; partitions already hold the correct images.

### 4. Migration gate: new U-Boot before new apply

- **Choice:** Ship/flash slot-aware `uboot.img` first (or in the same factory cut). Rootfs/`cyber_ota` that write inactive `boot_b` **must not** ship to boards still running always-`boot` U-Boot (would brick B try-boot: U-Boot keeps loading old `boot` while misc says B).
- **Mitigation:** Document flash order; optional apply-time check (e.g. `/proc/device-tree` or a small U-Boot version marker / env flag) can fail closed — implement if cheap; otherwise operator gate via docs + lab acceptance.

### 5. Factory / RockUSB unchanged in spirit

- **Choice:** Factory and RockUSB `di` still populate **both** boot letters with the matching FITs. After this change, that layout is **actually** what cold boot uses for A vs B (once misc says B), fixing the old “fake B” footgun where `boot_b` held a FIT that U-Boot never loaded until swap.

## Risks / Trade-offs

- **[Risk] Old U-Boot + new apply → silent wrong slot / unbootable try** → Mitigation: flash new U-Boot before/with rootfs that contains new apply; document in upgrade acceptance; prefer fail-closed probe if available.
- **[Risk] U-Boot misc parse bugs / CRC mistakes** → Mitigation: reuse exact `LWSAB` layout from `docs/ab-slot-misc.md`; serial lab A↔B cold boot + armed try + forced rollback.
- **[Risk] Stale docs / helpers still call swap** → Mitigation: delete or stub `ab_swap_boot_partitions`; grep CI / overlay verify for backup/swap strings.
- **[Trade-off]** PARTNAME `boot` for letter A remains asymmetric naming — accepted for migration cost.

## Migration Plan

1. Implement + lab-validate slot-aware U-Boot on ynh960; keep prior `uboot.img` under documented backup path.
2. Flash new U-Boot (loader/`make flash` path) onto lab units.
3. Land board helpers + `cyber_ota` apply/confirm without backup/swap; `make build-rootfs` + staged OTA lab: A→B commit, B→A commit, forced unhealthy rollback.
4. Update `docs/ab-slot-misc.md` and related upgrade docs; archive old “vendor always loads boot” wording.
5. Field: one-time U-Boot update via flash (or controlled factory), then normal `make upgrade` / cloud OTA.

**Rollback:** Restore previous `uboot.img` from backup and revert apply helpers (or flash prior factory). Do not mix old U-Boot with new inactive-`boot_b` writers.

## Open Questions

- Whether apply should refuse to write inactive `boot_b` unless a cheap “slot-aware U-Boot” marker is detectable on device (nice-to-have vs docs-only gate).
- Whether ek3562 `uboot_id` inherits the same patch in the same change or follows immediately after ynh960 acceptance (default: same patch path for all self-built product uboot_ids that use this GPT).
