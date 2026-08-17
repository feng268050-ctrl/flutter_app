## ADDED Requirements

### Requirement: Slot-aware FIT partition select from misc LWSAB

Self-built product `uboot.img` (ynh960 and other self-built product `uboot_id`s that boot this GPT) SHALL resolve the Linux FIT load partition from the misc **LWSAB** block at offset `0x100000`: when `try_boot` is ASCII `A` or `B`, load that letter; otherwise load `active`. Letter **A** SHALL map to GPT PARTNAME **`boot`**; letter **B** SHALL map to PARTNAME **`boot_b`**. The boot command path SHALL remain Linux-first (`boot_fit` without a preceding `boot_android`). A missing or CRC-invalid LWSAB marker SHALL fall back to loading **`boot`** (letter A). U-Boot MUST NOT require copying or swapping FIT bytes between `boot` and `boot_b` for slot selection. Vendor boot-control data at misc `0x0800` and Android BCB at `0x0000` MUST remain unused for this selection.

#### Scenario: Armed try-boot letter B loads boot_b

- **WHEN** misc LWSAB has a valid CRC and `try_boot=B`, and both `boot` and `boot_b` contain valid FITs
- **THEN** U-Boot loads the FIT from PARTNAME `boot_b` on the next cold or warm boot into Linux

#### Scenario: Active letter A loads boot

- **WHEN** misc LWSAB has a valid CRC, `try_boot=0` (not armed), and `active=A`
- **THEN** U-Boot loads the FIT from PARTNAME `boot`

#### Scenario: Corrupt marker falls back to boot

- **WHEN** the LWSAB magic or CRC at misc `0x100000` is invalid
- **THEN** U-Boot loads the FIT from PARTNAME `boot` (letter A fallback)
