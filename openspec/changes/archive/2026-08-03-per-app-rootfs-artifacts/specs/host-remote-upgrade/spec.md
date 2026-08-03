## MODIFIED Requirements

### Requirement: Host Make upgrade streams inactive letter over SSH

For the stream path, the host SHALL: preflight the active/inactive letter and refuse unsafe slot state; stream **`rootfs.img`** from `output/firmware/<APP>/rootfs.img` (default `APP=lws_hmi`) into the inactive `rootfs_*` partition while transferring; stream **only the inactive letter’s FIT** (`boot.img` for letter A, `boot_b.img` for letter B) from shared `output/firmware/` into the try-boot FIT path on `boot` after the running FIT is backed up to `boot_b`; optionally stream **oem** when packaged; then arm try-boot and reboot. Default full-system mode MUST update the inactive **boot and rootfs** letter pair (kernel + rootfs).

#### Scenario: Successful stream upgrade over USB-SSH

- **WHEN** exactly one USB-SSH device is available and the host runs `make upgrade` after successful kernel/rootfs builds that produced the dual FITs and `output/firmware/<APP>/rootfs.img`
- **THEN** the inactive letter receives the new FIT and rootfs via stream, try-boot is armed, and the board reboots without requiring a full `/userdata/ota/` stage of those images first

### Requirement: Host verifies images before stream write

Before streaming, the host upgrade command SHALL verify that required artifacts exist for the inactive letter: **`output/firmware/<APP>/rootfs.img`**, the inactive letter’s FIT (`boot.img` and/or `boot_b.img` under `output/firmware/` as needed after preflight), and that image sizes fit GPT slot capacities. It SHALL fail fast with a clear error if they are missing (e.g. instruct to run `make build-kernel` / `APP=<APP> make build-rootfs`).

#### Scenario: Missing rootfs.img

- **WHEN** the host runs full-system `make upgrade` and `output/firmware/<APP>/rootfs.img` is absent
- **THEN** the command MUST exit non-zero before writing partitions and MUST mention `build-rootfs`
