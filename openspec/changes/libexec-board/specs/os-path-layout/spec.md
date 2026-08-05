## MODIFIED Requirements

### Requirement: Subsystem helpers under usr libexec tiers

Programs invoked by systemd units or daemons (not user PATH commands) MUST live under **`/usr/libexec/<subsystem>/`**, not `/usr/lib/`:

- **`/usr/libexec/wpa/`** — Wi‑Fi stack scripts
- **`/usr/libexec/network/`** — Ethernet scripts
- **`/usr/libexec/bluetooth/`** — Bluetooth stack scripts
- **`/usr/libexec/board/`** — Board/platform helpers that are not UI/App-owned and do not belong to a dedicated stack above: at least product identity (`read-product-identity` / `write-product-identity` / `vendor-storage-ids`), `read-device-serial`, and Secrets seal helpers (`secrets-seal` and co-located CA helper). Callers may include host tooling and `cyber_hal`.
- **`/usr/libexec/hmi/`** — UI launch, App push/debug, A/B upgrade helpers, USB plug-ssh/MTP gadget helpers, `oem-compose`, bind-prefs / settings-restore orchestration, and other boot/UI-adjacent scripts not in the `board/` tier above

Legacy **`/usr/lib/lws-hmi/`** MUST NOT exist on shipped rootfs. After this change, the helpers listed under `/usr/libexec/board/` MUST NOT remain installed only under `/usr/libexec/hmi/` as their canonical home (temporary one-release compatibility symlinks MAY exist; dual long-term homes MUST NOT). Relocating into `/usr/libexec/hal/` is NOT part of this layout (HAL **state** remains `/var/lib/hal/`).

#### Scenario: Wi-Fi helper location

- **WHEN** `wlan-wpa.service` runs
- **THEN** it invokes scripts under `/usr/libexec/wpa/` not `/usr/libexec/lws-hmi/`

#### Scenario: restore-settings orchestrates split paths

- **WHEN** `settings-restore.service` runs after boot
- **THEN** `restore-settings.sh` under `/usr/libexec/hmi/` reads Wi‑Fi markers from `/var/lib/wpa_supplicant/`, eth0 from `/var/lib/network/`, BT from `/var/lib/bluetooth/`, and HAL platform prefs from `/var/lib/hal/`

#### Scenario: Product identity helpers live under board

- **WHEN** inspecting the shipped rootfs after this change
- **THEN** `read-product-identity.sh`, `write-product-identity.sh`, and `vendor-storage-ids.txt` SHALL exist under `/usr/libexec/board/`
- **AND** `/usr/bin/read-identity` and `/usr/bin/write-identity` SHALL resolve to those scripts (or wrappers that exec them)

#### Scenario: read-serial lives under board

- **WHEN** inspecting `/usr/bin/read-serial` on the shipped rootfs
- **THEN** it SHALL target `/usr/libexec/board/read-device-serial.sh` (not `/usr/libexec/hmi/read-device-serial.sh` as the canonical implementation)

## ADDED Requirements

### Requirement: Platform helper defaults prefer libexec/board or usr/bin

`cyber_hal` defaults for board helpers that implement platform identity or Secrets seal SHALL use either **`/usr/bin/<verb-noun>`** (preferred for identity) or **`/usr/libexec/board/…`**. They MUST NOT hard-require `/usr/libexec/hmi/…` as the only path for those helpers after this change.

#### Scenario: Secrets seal default under board

- **WHEN** HAL Secrets uses the default on-device seal helper path
- **THEN** that default SHALL be under `/usr/libexec/board/` (or an equivalent `/usr/bin` symlink to it)

#### Scenario: Identity still via PATH names

- **WHEN** HAL loads product brand/model/sn via helpers
- **THEN** it SHALL invoke `/usr/bin/read-identity` and/or `/usr/bin/read-serial` (symlink targets under `/usr/libexec/board/`)
