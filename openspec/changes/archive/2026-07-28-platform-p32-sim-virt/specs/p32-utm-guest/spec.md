## ADDED Requirements

### Requirement: Same OS artifacts in emulator

The P3.2 emulator SHALL boot the **same** kernel `Image` produced by `make build-kernel` and the **same** rootfs **content** produced by `make build-rootfs`, plus OEM pack `sim_virt`. It MUST NOT require a separately built virt userspace rootfs as the formal guest OS. The emulator working `rootfs.img` MAY be a grown copy of the device artifact (default size documented as `EMULATOR_ROOTFS_SIZE`, e.g. 1536M) so host debug/push tooling has free space; the device OTA `rootfs.img` size MUST remain unchanged.

#### Scenario: Emulator uses device rootfs content

- **WHEN** an operator runs the documented emulator assemble/start after `make build-rootfs` and `make build-kernel`
- **THEN** the guest root filesystem SHALL be derived from that `rootfs.img` (not a Debian hand-install or alternate BR rootfs as the primary path)

#### Scenario: Emulator uses same kernel Image

- **WHEN** `make build-kernel` completes
- **THEN** a bare `Image` SHALL be published for emulator use from that build (alongside FIT `boot.img` / `boot_b.img`)

#### Scenario: Emulator rootfs may be grown

- **WHEN** `make build-emulator` assembles the guest bundle
- **THEN** it SHALL copy (not hardlink-mutate) the device `rootfs.img` into the emulator output and MAY expand that copy for debug headroom without changing the device OTA artifact

### Requirement: Auto-start Flutter like device

After OEM compose succeeds in the guest, `hmi.service` SHALL start the HMI via `hmi-launch.sh` without a separate emulator-only App launcher.

#### Scenario: Cold boot reaches hmi.service

- **WHEN** the emulator guest reaches multi-user target with valid `sim_virt` OEM
- **THEN** `oem-compose` SHALL export `/run/hmi/board_profile.json` and `hmi.service` SHALL attempt to start Weston + Flutter as on device

### Requirement: QEMU host launcher with VirGL

`make emulator` SHALL launch `qemu-system-aarch64` with the published Image, emulator rootfs.img, and sim_virt oem.img, using host VirGL (`virtio-gpu-gl`) on the documented host QEMU build (macOS: qemu-virgl via `make setup-emulator-qemu`). It MUST NOT treat “start an empty UTM VM” as success. Guest Mesa for VirGL MAY be provided via a host 9p share (not baked into the device rootfs).

#### Scenario: make emulator invokes QEMU

- **WHEN** `make emulator` runs on macOS with qemu-virgl installed and emulator bundle present
- **THEN** it SHALL start QEMU using those three artifacts with host GL enabled

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
