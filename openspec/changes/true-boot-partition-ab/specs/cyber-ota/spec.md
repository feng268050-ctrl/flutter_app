## MODIFIED Requirements

### Requirement: Progress callbacks cover transfer, verify, extract, and write

`cyber_ota` SHALL emit progress events that distinguish at least: checking/manifest, transferring, **verifying**, extracting, writing, arming try-boot, and terminal success/failure. Cloud and host HTTP sessions MUST include a successful verifying phase before extract/write. Transfer-phase progress SHALL map to upgrade-page **download** UX for both ingresses.

Extract progress SHALL advance with **compressed archive bytes** consumed while feeding `tar -xz` on stdin (same chunked model as host `stream-file-progress.py`).

Write progress SHALL be **per image** (each of rootfs / kernel FIT / oem reports its own 0–100% from that image’s bytes). Full-system write order SHALL be: inactive rootfs → inactive letter’s FIT to that letter’s boot partition only (`writing kernel` with byte progress; MUST NOT perform a `boot`→`boot_b` backup copy) → optional oem (`writing oem`) → arm. Progress MUST NOT use elapsed-time estimates. Block-device writes SHALL chunk-read the image file and pipe to a single `dd of=<device>` (MUST NOT open `/dev` via Dart `RandomAccessFile`).

#### Scenario: Write progress updates during apply

- **WHEN** images are being written to inactive partitions via Dart chunked file→`dd` stdin copy (byte progress like host `stream-file-progress.py`)
- **THEN** subscribers receive per-image write progress (percent may restart at 0 when the next image begins) until arming or failure
- **AND** there is no `progress.json` dependency for UI or cloud WS

#### Scenario: Extract progress updates while unpacking

- **WHEN** the OTA `tar.gz` is extracted under `/userdata/ota/`
- **THEN** subscribers receive `extracting` progress that advances with archive bytes fed to `tar`

#### Scenario: Host HTTP pull reports transferring like download

- **WHEN** the device is downloading the OTA `tar.gz` from the host HTTP server and the session is subscribed
- **THEN** subscribers receive transferring progress that advances with received bytes

#### Scenario: Failed verify emits failure without write success

- **WHEN** package signature verification fails (cloud or host HTTP)
- **THEN** the session ends failed and MUST NOT emit successful write/arm completion
