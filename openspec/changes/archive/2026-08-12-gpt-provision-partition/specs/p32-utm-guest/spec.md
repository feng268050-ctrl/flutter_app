## MODIFIED Requirements

### Requirement: Same OS artifacts in emulator

The P3.2 emulator SHALL boot the **same** kernel `Image` produced by `make build-kernel` and the **same** rootfs **content** produced by `make build-rootfs`, plus OEM pack `sim_virt`, and a host **`provision.img`** virtio disk per `gpt-provision-partition`. It MUST NOT require a separately built virt userspace rootfs as the formal guest OS. The emulator working `rootfs.img` MAY be a grown copy of the device artifact (fixed size **1536M**) so host debug/push tooling has free space; the device OTA `rootfs.img` size MUST remain unchanged. Operators MUST NOT treat emulator rootfs size as a tunable build parameter. It MUST NOT rely on OEM `boards/sim/identity.env` for per-unit SN.

#### Scenario: Emulator uses device rootfs content

- **WHEN** an operator runs the documented emulator assemble/start after `make build-rootfs` and `make build-kernel`
- **THEN** the guest root filesystem SHALL be derived from that `rootfs.img` (not a Debian hand-install or alternate BR rootfs as the primary path)

#### Scenario: Emulator uses same kernel Image

- **WHEN** `make build-kernel` completes
- **THEN** a bare `Image` SHALL be published for emulator use from that build (alongside FIT `boot.img` / `boot_b.img`)

#### Scenario: Emulator rootfs may be grown

- **WHEN** `make build-emulator` assembles the guest bundle
- **THEN** it SHALL copy (not hardlink-mutate) the device `rootfs.img` into the emulator output and MAY expand that copy for debug headroom without changing the device OTA artifact

#### Scenario: Emulator bundle includes provision disk

- **WHEN** `make build-emulator` succeeds
- **THEN** `output/firmware/emulator/provision.img` exists (or documented create-on-first-run path)
- **AND** `oem/boards/sim/identity.env` is not in the OEM source tree

### Requirement: QEMU host launcher with VirGL

`make emulator` SHALL launch `qemu-system-aarch64` with the published Image, emulator rootfs.img, sim_virt oem.img, and **`provision.img`**, using host VirGL (`virtio-gpu-gl`) on the documented host QEMU build (macOS: qemu-virgl via `make setup-emulator-qemu`). It MUST NOT treat “start an empty UTM VM” as success. Guest Mesa for VirGL MAY be provided via a host 9p share (not baked into the device rootfs). The guest SHALL mount `PARTLABEL=provision` from the virtio disk. Per-developer identity when Vendor Storage is absent SHALL come from `provision/identity.env` on that disk, not from shared OEM seeds.

#### Scenario: make emulator invokes QEMU

- **WHEN** `make emulator` runs on macOS with qemu-virgl installed and emulator bundle present
- **THEN** it SHALL start QEMU using those artifacts with host GL enabled

#### Scenario: Guest identity from provision not OEM

- **WHEN** two hosts use different `provision.img` files with the same emulator rootfs
- **THEN** probed guest SN MAY differ
- **AND** SN SHALL not be read from `oem/boards/sim/identity.env`

#### Scenario: Emulator cloud Ed25519 on provision disk

- **WHEN** the QEMU guest has no Vendor Storage, virtio `provision.img` mounted, and HMI 云服务 enabled with pinned HTTPS origin
- **THEN** first ensure-activated SHALL write `/mnt/provision/cloud-ed25519.sealed` via board helpers (software KEK backend)
- **AND** device WebSocket and gated HTTP probes SHALL succeed with minted Bearer (not `TOKEN_REQUIRED` / 401 from missing key)
- **AND** the sealed blob SHALL survive guest reboot when the same `provision.img` is reattached
