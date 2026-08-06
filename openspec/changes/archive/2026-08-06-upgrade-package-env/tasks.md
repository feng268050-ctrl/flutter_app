## 1. Contract lock-in

- [x] 1.1 Confirm OTA archive member names with `unified-ota-cyber-ota` / `make ota-package` (SSH single-FIT vs RockUSB dual-FIT)
- [x] 1.2 Resolve open question: auto-`OEM_ONLY` when archive is oem-only vs require `OEM_ONLY=1`

## 2. Host parsing and validation

- [x] 2.1 Add `UPGRADE_PACKAGE` dotenv/env handling in `upgrade-remote.sh` (or shared helper)
- [x] 2.2 Validate path exists, is a file, and suffix/type is `.tar` / `.tar.gz` / `.tgz`; fail fast otherwise
- [x] 2.3 List/verify required archive members for the selected transport and `OEM_ONLY` mode before transfer/`di`

## 3. SSH / USB-SSH path

- [x] 3.1 When `UPGRADE_PACKAGE` set and SSH selected: resolve sibling `<path>.sig`; fail if missing; host HTTP serve archive + `.sig`
- [x] 3.2 Trigger device download + staged **verify**-apply / upgrade-page session (HostHttpIngress; **require** `.sig`)
- [x] 3.3 Skip default `ota-package` rebuild when `UPGRADE_PACKAGE` is set

## 4. RockUSB Loader / Maskrom path

- [x] 4.1 When `UPGRADE_PACKAGE` set and RockUSB selected: extract archive to a host temp/cache dir
- [x] 4.2 Point `flash-usb.sh upgrade-ota` (or equivalent) at extracted `boot.img` / `boot_b.img` / `rootfs.img` [/ `oem.img`]
- [x] 4.3 Clean up temp extract dir (best-effort); fail fast if members incomplete

## 5. Docs

- [x] 5.1 Document `UPGRADE_PACKAGE=` in Makefile `help`, README / `docs/make-commands.md`, AGENTS if needed
- [x] 5.2 Add examples for SSH tarball upgrade and Loader tarball upgrade

## 6. Verification

- [x] 6.1 Lab: `UPGRADE_PACKAGE=…tar.gz make upgrade` over USB-SSH serves archive + sibling `.sig` for device download and verify-applies
- [x] 6.2 Lab: same var with board in Loader extracts and `di`s without `uf`
- [x] 6.3 Lab: bad path / zip / incomplete RockUSB archive fails before device write
