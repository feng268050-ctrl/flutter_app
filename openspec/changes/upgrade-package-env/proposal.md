## Why

Operators sometimes already have a whole-device OTA tarball (from `make ota-package`, CI, or a colleague) and want `make upgrade` to consume it directly instead of rebuilding from loose `*.img`. Today `make upgrade` only knows how to stream/di from `output/firmware/` paths. Adding **`UPGRADE_PACKAGE=`** lets one artifact drive both SSH staged apply and RockUSB Loader `di`, matching how packages will be shared once P4.8 packaging exists.

## What Changes

- Add host env **`UPGRADE_PACKAGE=<path>`** for `make upgrade` / `upgrade-remote.sh`: accept an existing **`.tar` or `.tar.gz`/`.tgz`** whose members match the OTA package layout (partition `*.img` + optional orchestration manifest).
- **USB-SSH / SSH**: upload the archive to `/userdata/ota/`, then run the **device-side staged OTA apply** path (safe upgrade page / extract / write inactive letter)—same ingress shape as product package upload, without requiring the host to re-run `make ota-package`.
- **RockUSB Loader/Maskrom**: extract the archive on the **host**, then run the existing **`upgrade-ota` / `di`** flow against the extracted images (not `uf` / not `factory.img`).
- Fail fast on missing/unreadable package, unsupported archive type, or missing required members for the selected mode (`OEM_ONLY`, etc.).
- Docs: Makefile `help`, README / make-commands, AGENTS as needed.

## Capabilities

### New Capabilities

- `upgrade-package-input`: `UPGRADE_PACKAGE=` contract—archive formats, member expectations, SSH upload+device apply vs Loader extract+`di`, interaction with `OEM_ONLY` / `OEM_IMG` / default `ota-package` path.

### Modified Capabilities

- `host-remote-upgrade`: `make upgrade` MAY take `UPGRADE_PACKAGE=` as an alternate input to building/packaging from tree outputs; transport-specific behavior for SSH vs RockUSB when the variable is set.

## Impact

- **Host**: `scripts/upgrade-remote.sh`, optional thin extract helper, Makefile `upgrade` / help, docs.
- **Device (SSH path)**: reuses staged apply / HMI upgrade session from `unified-ota-cyber-ota` (package upload ingress); this change does not redefine cloud signing policy.
- **RockUSB**: `flash-usb.sh upgrade-ota` image path resolution when inputs come from an extracted tarball directory.
- **Depends on / aligns with**: `unified-ota-cyber-ota` package member layout (`tar`/`tar.gz` of `*.img`); does not replace `make ota-package` as the way to *produce* packages.
