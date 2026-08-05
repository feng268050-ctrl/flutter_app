## Why

Operators sometimes already have a whole-device OTA tarball (from `make ota-package`, CI, or a colleague) and want `make upgrade` to consume it directly instead of rebuilding from loose `*.img`. Adding **`UPGRADE_PACKAGE=`** lets one artifact drive both SSH staged apply and RockUSB Loader `di`. For **USB-SSH/SSH**, the host **also** serves the sibling **`.sig`** (same directory, archive basename + `.sig`) so device Ed25519 verify matches cloud OTA.

## What Changes

- Add host env **`UPGRADE_PACKAGE=<path>`** for `make upgrade` / `upgrade-remote.sh`: accept an existing **`.tar` or `.tar.gz`/`.tgz`** whose members match the OTA package layout.
- **USB-SSH / SSH**: ephemeral HTTP serve of the archive **and** the default sibling **`<path>.sig`**, device download into `/userdata/ota/`, then staged **verify**-extract-apply. Missing sibling `.sig` fails fast on SSH.
- **RockUSB Loader/Maskrom**: extract the archive on the **host**, then **`upgrade-ota` / `di`** (`.sig` not required).
- Fail fast on missing/unreadable package, missing SSH `.sig`, unsupported archive type, or missing required members.
- Docs: Makefile `help`, README / make-commands, AGENTS as needed.

## Capabilities

### New Capabilities

- `upgrade-package-input`: `UPGRADE_PACKAGE=` contract—archive formats, **default sibling `.sig` for SSH**, member expectations, SSH host-HTTP + device-pull vs Loader extract+`di`.

### Modified Capabilities

- `host-remote-upgrade`: `make upgrade` MAY take `UPGRADE_PACKAGE=` as an alternate input; SSH path serves archive + sibling `.sig` for device download and requires device verify.

## Impact

- **Host**: `scripts/upgrade-remote.sh`, Makefile `upgrade` / help, docs.
- **Device (SSH path)**: staged verify-apply from `unified-ota-cyber-ota`.
- **RockUSB**: extract + `di` without requiring `.sig`.
- **Aligns with**: `unified-ota-cyber-ota` (SSH always verifies via host HTTP pull).
