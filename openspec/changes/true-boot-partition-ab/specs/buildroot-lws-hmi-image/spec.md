## MODIFIED Requirements

### Requirement: Kernel/boot selection matches A/B letter pairs

The boot chain configuration used by the product image SHALL load the active (or armed try-boot) letter’s FIT from the **letter-matched** GPT boot partition (`A`→`boot`, `B`→`boot_b`) and mount the matching `rootfs_*`. Hardcoded sole reliance on a pre-A/B single `root=/dev/mmcblk0p6` for product boots MUST NOT remain as the only mechanism after this change. Product docs and image notes MUST NOT describe try-boot as requiring a content swap into a fixed `PARTNAME=boot`.

#### Scenario: Bootargs or DTS documents paired slot root

- **WHEN** a developer inspects the ynh960 Linux root DTS/bootargs overlay after this change
- **THEN** root selection is expressed in terms of A/B letters (PARTLABEL or slot-resolved device) paired with the selected boot slot

#### Scenario: Boot selection docs match partition select

- **WHEN** a developer reads factory/build notes that describe how the product boots A vs B
- **THEN** those notes state that U-Boot selects `boot` or `boot_b` by slot letter rather than swapping FIT contents into `boot`
