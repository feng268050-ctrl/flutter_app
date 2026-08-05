## MODIFIED Requirements

### Requirement: Subsystem helpers under usr libexec tiers

Programs invoked by systemd units or daemons (not user PATH commands) MUST live under **`/usr/libexec/<subsystem>/`**, not `/usr/lib/`:

- **`/usr/libexec/wpa/`** — Wi‑Fi stack scripts
- **`/usr/libexec/network/`** — Ethernet scripts
- **`/usr/libexec/bluetooth/`** — Bluetooth stack scripts
- **`/usr/libexec/board/`** — Board/platform helpers: product identity + Vendor Storage ID map, `read-device-serial`, Secrets seal helpers, shared `paths.sh`, hostname / mDNS / serial-console stty, `reboot-loader`, `boot-verify` / `env-verify`, `set-performance-mode`, `bind-prefs` (userdata state binds)
- **`/usr/libexec/usb/`** — USB OTG / gadget / plug-ssh / MTP
- **`/usr/libexec/ab/`** — A/B slot upgrade helpers
- **`/usr/libexec/oem/`** — OEM compose (`oem-compose`)
- **`/usr/libexec/display/`** — Display / Weston / orientation / mouse apply
- **`/usr/libexec/power/`** — Poweroff / shutdown / power-key / systemctl poweroff wrapper
- **`/usr/libexec/ssh/`** — LAN OpenSSH debug helpers and sshd host-key ensure (not USB plug-ssh)
- **`/usr/libexec/hmi/`** — Flutter UI launch / stop, App push/debug, `diagnose-hmi`, `extract-video-frame` only

Legacy **`/usr/lib/lws-hmi/`** MUST NOT exist on shipped rootfs. Helpers listed under `/usr/libexec/{board,usb,ab,oem,display,power,ssh}/` MUST NOT remain installed only under `/usr/libexec/hmi/` as their canonical home (temporary one-release compatibility symlinks MAY exist; dual long-term homes MUST NOT). Relocating into `/usr/libexec/hal/` is NOT part of this layout (HAL **state** remains `/var/lib/hal/`).

#### Scenario: Wi-Fi helper location

- **WHEN** `wlan-wpa.service` runs
- **THEN** it invokes scripts under `/usr/libexec/wpa/` not `/usr/libexec/lws-hmi/`

#### Scenario: Product identity helpers live under board

- **WHEN** inspecting the shipped rootfs after Phase 1+
- **THEN** `read-product-identity.sh`, `write-product-identity.sh`, and `vendor-storage-ids.txt` SHALL exist under `/usr/libexec/board/`
- **AND** `/usr/bin/read-identity` and `/usr/bin/write-identity` SHALL resolve to those scripts (or wrappers that exec them)

#### Scenario: read-serial lives under board

- **WHEN** inspecting `/usr/bin/read-serial` on the shipped rootfs
- **THEN** it SHALL target `/usr/libexec/board/read-device-serial.sh`

#### Scenario: USB plug-ssh helpers live under usb

- **WHEN** inspecting the shipped rootfs after Phase 2
- **THEN** `usb-plug-ssh-start.sh` / `usb-plug-ssh-stop.sh` SHALL exist under `/usr/libexec/usb/`
- **AND** `ssh-debug-usb.service` SHALL ExecStart/Stop those paths

#### Scenario: A/B helpers live under ab

- **WHEN** inspecting `ab-boot-confirm.service` after Phase 2
- **THEN** its ExecStart SHALL target `/usr/libexec/ab/ab-boot-confirm.sh`

#### Scenario: oem-compose lives under oem

- **WHEN** inspecting `oem-compose.service` after Phase 2
- **THEN** its ExecStart SHALL target `/usr/libexec/oem/oem-compose.sh`

#### Scenario: bind-prefs lives under board

- **WHEN** inspecting the shipped rootfs after Phase 3
- **THEN** `bind-prefs.sh` SHALL exist under `/usr/libexec/board/`

#### Scenario: set-performance-mode lives under board

- **WHEN** inspecting `cpu-performance.service` after Phase 3
- **THEN** its ExecStart SHALL target `/usr/libexec/board/set-performance-mode.sh`

#### Scenario: poweroff wrapper lives under power

- **WHEN** inspecting `/usr/bin/systemctl` after Phase 3 on images that install the poweroff wrapper
- **THEN** it SHALL resolve to a helper under `/usr/libexec/power/` (not `/usr/libexec/hmi/`)

#### Scenario: LAN ssh-debug lives under ssh

- **WHEN** inspecting `ssh-debug-lan.service` after Phase 3
- **THEN** its ExecStart SHALL target `/usr/libexec/ssh/lan-ssh-run.sh`
- **AND** `/usr/bin/enable-ssh-debug` SHALL target `/usr/libexec/ssh/enable-ssh-debug.sh`

#### Scenario: hmi tier is App/UI only

- **WHEN** listing `/usr/libexec/hmi/` on the shipped rootfs after Phase 3
- **THEN** it SHALL NOT contain USB, A/B, OEM compose, display/Weston, poweroff, LAN ssh-debug, or board identity/verify helpers as canonical homes

## ADDED Requirements

### Requirement: Platform helper defaults prefer libexec/board or usr/bin

`cyber_hal` defaults for board helpers that implement platform identity or Secrets seal SHALL use either **`/usr/bin/<verb-noun>`** (preferred for identity) or **`/usr/libexec/board/…`**. They MUST NOT hard-require `/usr/libexec/hmi/…` as the only path for those helpers after this change.

#### Scenario: Secrets seal default under board

- **WHEN** HAL Secrets uses the default on-device seal helper path
- **THEN** that default SHALL be under `/usr/libexec/board/` (or an equivalent `/usr/bin` symlink to it)

#### Scenario: Identity still via PATH names

- **WHEN** HAL loads product brand/model/sn via helpers
- **THEN** it SHALL invoke `/usr/bin/read-identity` and/or `/usr/bin/read-serial` (symlink targets under `/usr/libexec/board/`)

### Requirement: LAN ssh-debug under ssh may call usb

LAN OpenSSH debug helpers live under `/usr/libexec/ssh/`. When they start or stop USB plug-ssh, they MUST invoke canonical helpers under `/usr/libexec/usb/` (or `/usr/bin` symlinks), not a second copy under `hmi/` or `ssh/`.

#### Scenario: enable-ssh-debug starts plug-ssh via usb tier

- **WHEN** `enable-ssh-debug.sh` starts USB plug-ssh
- **THEN** it SHALL exec `/usr/libexec/usb/usb-plug-ssh-start.sh` (or `/usr/bin/start-usb-ssh`)

### Requirement: HAL ssh_debug helper path

`board_profile` / HAL `ssh_debug` enable helper SHALL default to `/usr/libexec/ssh/enable-ssh-debug.sh` (or `/usr/bin/enable-ssh-debug`) after Phase 3. It MUST NOT require `/usr/libexec/ssh/enable-ssh-debug.sh` as the only path.

#### Scenario: sim/ynh960 profile ssh_debug

- **WHEN** inspecting shipped or sim `board_profile` ssh_debug after Phase 3
- **THEN** the enable helper path SHALL be under `/usr/libexec/ssh/` or `/usr/bin/enable-ssh-debug`
