## Why

Kernel FIT try-boot still **backs up** the running FIT `boot`→`boot_b` and writes the new FIT into the **same** GPT partition named `boot`, then **swaps** partition contents on rollback. That works around vendor `boot_fit` only loading `PARTNAME=boot`. The product now ships a **self-built Linux-first U-Boot**, so we can select `boot` vs `boot_b` by slot letter and stop treating `boot_b` as a content mirror.

## What Changes

- Teach self-built U-Boot to load the FIT from the **letter-matched** boot partition (`A`→`boot`, `B`→`boot_b`) using the existing misc `LWSAB` marker (try-boot / active), instead of always loading `boot`.
- Change full-system OTA apply so the inactive letter’s FIT is written **only** to that letter’s boot partition (`boot` or `boot_b`); **remove** `boot`→`boot_b` backup and **remove** `ab_swap_boot_partitions` on rollback.
- Keep GPT PARTNAMEs **`boot` / `boot_b`** (no rename to `boot_a`); rootfs A/B, dual FIT artifacts, RSCE PARTLABEL rules, and flash-only uboot/SPL policy stay as today.
- Update board helpers (`ab-slot-lib` / confirm), `cyber_ota` apply/progress, and docs (`ab-slot-misc`, storage/upgrade) to the partition-select model.
- **Non-goals:** dual `uboot_a`/`uboot_b` or bootloader OTA; Android BCB / vendor bootctrl @ `0x0800`; GPT repartition / factory flash-only adoption beyond shipping a new `uboot.img`.

## Capabilities

### New Capabilities

<!-- none — this tightens existing A/B + U-Boot behavior -->

### Modified Capabilities

- `ab-firmware-slots`: Kernel try-boot / rollback become true inactive-partition write + U-Boot partition select; drop backup/swap contract.
- `linux-first-uboot`: Self-built U-Boot SHALL resolve FIT load partition from misc slot letter (`boot` / `boot_b`).
- `cyber-ota`: Full-system write order writes the inactive FIT to the inactive boot partition (no `boot`→`boot_b` backup step).
- `buildroot-lws-hmi-image`: Boot-chain wording no longer describes try-boot as content swap into `PARTNAME=boot`.
- `host-remote-upgrade`: SSH staged apply description matches inactive-boot write (RockUSB `di` both letters unchanged).

## Impact

- **U-Boot:** `overlay/device/.../patch-uboot-bootcmd.sh` (and/or source patch under uboot build) — slot-aware `boot_fit`; new `prebuilt/bootloader/<uboot_id>/uboot.img` with existing backup policy.
- **Board A/B:** `ab-slot-lib.sh`, `ab-boot-confirm.sh`; Dart `packages/cyber_ota` (`ab_slot.dart`, `ota_apply.dart`) + progress mapping.
- **Docs / specs:** `docs/ab-slot-misc.md`, `docs/storage-layout.md`, AGENTS/README upgrade notes as needed.
- **Adoption:** Field boards need the new U-Boot flashed once (`make flash` / loader path); subsequent OTAs use partition select. GPT layout unchanged — no repartition.
