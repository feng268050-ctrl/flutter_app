## Why

`make upgrade` currently uploads the full firmware bundle to `/userdata/ota/` first, then runs a separate board `dd` apply. Transfer progress finishes quickly, but operators still wait ~30s of silent partition writes before reboot — a poor UX compared to `make flash`. Developer SSH upgrades should stream bytes straight into the inactive partitions so there is one wait that matches write progress. Future online OTA must stay download-then-write (staging under userdata for resume and digest verification).

## What Changes

- **`make upgrade` (dev SSH path)** switches to **stream-to-partition**: after slot preflight, host pipes `rootfs.img` (and the inactive letter’s FIT, optional oem) over SSH directly into the inactive block devices, then arms try-boot and reboots — no full-image staging under `/userdata/ota/` for the daily path.
- Host transfers **only the inactive letter’s FIT** (`boot.img` for A or `boot_b.img` for B), not both FITs.
- Progress UX is a **single wait** tied to streamed bytes (closer to flash).
- Integrity for the SSH stream path relies on the **trusted SSH channel + expected byte counts** (optional stream digest later); no post-upload full-file sha256-on-userdata before write.
- **Staged apply remains** (`ab-upgrade-apply.sh` + `/userdata/ota/`): download/verify then `dd` — the contract for **future online OTA (P4.8 / P5.8)**. Docs draw a hard line between the two modes.
- Docs (`README`, `storage-layout`, acceptance notes) stop implying that `make upgrade` stages full images under userdata before writing.

## Capabilities

### New Capabilities

- *(none)* — behavior changes land in existing host and board A/B specs.

### Modified Capabilities

- `host-remote-upgrade`: `make upgrade` becomes stream-to-partition over SSH; single-progress UX; only inactive FIT + rootfs (+ optional oem); still no RockUSB; still returns on reboot request / SSH drop.
- `ab-firmware-slots`: distinguish **stream apply** (dev SSH) from **staged apply** (OTA); keep staged `/userdata/ota/` + digest-then-dd for OTA; stream path must preserve the same safety invariants (inactive only, no userdata wipe, no uboot rewrite, reject pending try-boot / mounted-root mismatch).

## Impact

- Host: `scripts/upgrade-remote.sh`, `scripts/stream-file-progress.py` (or equivalent progress wiring).
- Board: `overlay/.../usr/libexec/hmi/ab-upgrade-apply.sh`, `ab-slot-lib.sh` (stream helpers / preflight query; staged apply kept).
- Docs: `README.md`, `docs/storage-layout.md`, `docs/ab-upgrade-acceptance.md`, Makefile `help` if wording claims “stage then apply”.
- Future OTA UI/cloud remains on staged apply; no product OTA implementation in this change.
