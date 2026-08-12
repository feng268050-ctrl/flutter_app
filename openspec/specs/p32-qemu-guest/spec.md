# p32-qemu-guest Specification

## Purpose

P3.2 same-OS **QEMU** guest: shared device `Image` + rootfs content + `sim_virt` OEM, host VirGL, product-shaped NICs/USB, no OTG. Formal launcher is `make emulator` (`qemu-system-aarch64`).

## Requirements
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

### Requirement: Auto-start Flutter like device

After OEM compose succeeds in the guest, `hmi.service` SHALL start the HMI via `hmi-launch.sh` without a separate emulator-only App launcher.

#### Scenario: Cold boot reaches hmi.service

- **WHEN** the emulator guest reaches multi-user target with valid `sim_virt` OEM
- **THEN** `oem-compose` SHALL export `/run/hmi/board_profile.json` and `hmi.service` SHALL attempt to start Weston + Flutter as on device

### Requirement: QEMU host launcher with VirGL

`make emulator` SHALL launch `qemu-system-aarch64` with the published Image, emulator rootfs.img, sim_virt oem.img, and **`provision.img`**, using host VirGL (`virtio-gpu-gl`) on the documented host QEMU build (macOS: qemu-virgl via `make setup-emulator-qemu`). It MUST NOT treat starting an empty/non-appliance VM as success. Guest Mesa for VirGL MAY be provided via a host 9p share (not baked into the device rootfs). The guest SHALL mount `PARTLABEL=provision` from the virtio disk. Per-developer identity when Vendor Storage is absent SHALL come from `provision/identity.env` on that disk, not from shared OEM seeds.

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

### Requirement: Product-shaped NICs, SSH hostfwd, and no OTG

Unchanged product contract: eth0/wlan0 roles, no usbOtg on sim. `make emulator` SHALL wire virtio-net NICs with fixed MACs that rootfs systemd `.link` files rename, including:

- **eth0** — IP camera dedicated link (prefer host Ethernet/USB-LAN bridge when available)
- **wlan0** — product Wi‑Fi role (virtio L3 via host; real 802.11 via USB Wi‑Fi is deferred)
- **ethssh** (or equivalent) — SSH hostfwd for `make devices` **MODE=EMU** / `shell` / `push-app` / `debug-app`

It SHALL enable USB xHCI with auto passthrough of known USB-serial (and optional BT) devices when present (override via `EMULATOR_USB`). Sim OEM MAY remap Modbus RTU to `/dev/ttyUSB0` via a board helper key.

#### Scenario: Profile omits usbOtg

- **WHEN** inspecting composed sim board profile
- **THEN** `usbOtg` SHALL be absent

#### Scenario: Launcher prepares NIC and USB map

- **WHEN** `make emulator` starts QEMU without operator-supplied net/USB flags
- **THEN** the guest SHALL receive the documented emulator MACs / iface names and an xHCI controller (plus host USB-serial devices when auto-detected or listed in `EMULATOR_USB`)

#### Scenario: SSH tooling uses hostfwd

- **WHEN** the guest is running and SSH hostfwd answers
- **THEN** `make devices` SHALL list **MODE=EMU** and `SN=SIM-EMU` (alias) or `IP=127.0.0.1:<port>` SHALL select that guest for shell/push/debug

### Requirement: Absolute pointer and playback audio

The emulator SHALL present an absolute pointer device (virtio tablet or equivalent) so the host mouse is not exclusively grabbed, and SHALL present virtio sound suitable for host playback (capture MAY be omitted when the host backend is unreliable).

#### Scenario: Tablet pointer

- **WHEN** the operator moves the host cursor over the QEMU window
- **THEN** the guest SHALL receive absolute coordinates without requiring a mouse-grab release chord

### Requirement: Emulator does not use product FIT multi-conf

The P3.2 emulator SHALL continue to boot the bare kernel `Image` with QEMU `-machine virt` providing the guest device tree. It MUST NOT require a `conf-sim` (or similar) entry inside the product `boot.img` FIT for guest boot.

#### Scenario: Emulator ignores product FIT DT list

- **WHEN** an operator runs `make build-emulator` / `make emulator` after multi-configuration product FITs exist
- **THEN** the guest SHALL still start from the published bare `Image` + QEMU virt DT
- **AND** MUST NOT depend on extracting a board FDT from `boot.img` for the virt machine
