## MODIFIED Requirements

### Requirement: P3.2 emulator bundle uses device OS artifacts

`make build-emulator` SHALL assemble the guest from device `Image`, grown emulator `rootfs.img` copy, `sim_virt` `oem.img`, and a host **`provision.img`** virtio disk per `gpt-provision-partition`. It MUST NOT rely on OEM `boards/sim/identity.env` for per-unit SN.

#### Scenario: Emulator bundle includes provision disk

- **WHEN** `make build-emulator` succeeds
- **THEN** `output/firmware/emulator/provision.img` exists (or documented create-on-first-run path)
- **AND** `oem/boards/sim/identity.env` is not in the OEM source tree

### Requirement: make emulator launches QEMU with VirGL and product-shaped networking

`make emulator` SHALL attach `provision.img` as a virtio block device so the guest mounts `PARTLABEL=provision`. Per-developer identity when Vendor Storage is absent SHALL come from `provision/identity.env` on that disk, not from shared OEM seeds.

#### Scenario: Guest identity from provision not OEM

- **WHEN** two hosts use different `provision.img` files with the same emulator rootfs
- **THEN** probed guest SN MAY differ
- **AND** SN SHALL not be read from `oem/boards/sim/identity.env`
