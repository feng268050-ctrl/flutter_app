## Context

`make upgrade` today resolves targets via `UPGRADE_TRANSPORT=auto|ssh|rockusb` and either streams loose images over SSH or `di`s them in RockUSB. `unified-ota-cyber-ota` will move the SSH path to staged package upload + device apply. Operators also need to feed an **already-built** archive without re-invoking the full build/package graph.

Package layout aligns with `make ota-package`: `tar` or `tar.gz` containing partition `*.img` (+ optional `manifest.json`). Signing policy for host vs cloud lives in `unified-ota-cyber-ota` (host upgrade does not require Ed25519; cloud download does)—this change only wires **input selection** and **transport branching**.

## Goals / Non-Goals

**Goals:**

- **`UPGRADE_PACKAGE=<path>`** on `make upgrade`: use that archive instead of default tree/`ota-package` outputs.
- Accept **`.tar`**, **`.tar.gz`**, **`.tgz`** (detect by name and/or magic; fail clearly otherwise).
- **SSH / USB-SSH**: upload archive → device staged OTA apply (progress/UX per unified OTA host-upload ingress).
- **RockUSB Loader/Maskrom**: host-side extract → existing `upgrade-ota` `di` of extracted images.
- Preserve `OEM_ONLY` / `OEM_IMG` semantics where they still apply to member selection or RockUSB oem `di`.
- Document the variable in Make help / docs.

**Non-Goals:**

- Producing packages (`make ota-package` remains elsewhere).
- Changing GPT / U-Boot / `make flash` / `uf factory.img`.
- Redefining cloud Ed25519 policy (owned by `unified-ota-cyber-ota`).
- Supporting zip or other archive formats in this change.
- Auto-downloading packages from the network via `UPGRADE_PACKAGE=` (local path only).

## Decisions

### 1. Env var name and precedence

**Choice:** `UPGRADE_PACKAGE=` absolute or relative path to a readable archive. Loadable from `.env` via existing dotenv; command-line overrides `.env`.

When set and non-empty:

- Skip generating/refreshing a package from current `output/firmware/` for this invocation (do not require fresh `make ota-package` unless the path points at that artifact by coincidence).
- Still run transport auto-detect / preflight appropriate to SSH vs RockUSB.

When unset: existing default behavior (after unified OTA: build/use default `ota-package` artifact; today: stream/di from loose imgs).

**Alternative:** positional Make argument. Rejected: inconsistent with `OEM_IMG=`, `SN=`, etc.

### 2. SSH path: upload whole archive

**Choice:** Upload the given file as-is to `/userdata/ota/` (documented basename or preserve basename), trigger HMI upgrade session, device extract + apply. Do **not** host-extract before SSH upload (keeps one transfer unit and matches cloud package shape).

Host does not upload a `.sig` for this developer path (per unified-ota host policy).

### 3. RockUSB path: extract then `di`

**Choice:** Extract into a host temp dir (or documented cache under `output/`), map members to the same image roles `flash-usb.sh upgrade-ota` expects (`boot.img` / `boot_b.img` / `rootfs.img` / optional `oem.img`), then invoke existing `di` logic. Prefer extracting only what `upgrade-ota` needs; clean temp on success (best-effort on failure).

**Why not upload to board in Loader:** no Linux SSH / no `/userdata/ota/` apply stack in Loader/Maskrom.

**Why not `uf` the tarball:** product policy remains OTA-equivalent `di`, not factory `uf`.

### 4. Archive member rules

**Choice:** Require members consistent with packaging mode:

- Full-system SSH: at least inactive-letter FIT naming as packaged (documented: typically `boot.img` or letter-specific name per `ota-package` contract) + `rootfs.img`; oem optional.
- RockUSB full-system: need both FITs + rootfs as today’s `upgrade-ota` (if archive only has one FIT, fail with guidance—or document that RockUSB+`UPGRADE_PACKAGE` requires a dual-FIT package / publish-style archive).

**Practical rule for v1:** Document that RockUSB+`UPGRADE_PACKAGE` expects an archive whose members satisfy `upgrade-ota` inputs (both `boot.img` and `boot_b.img` + `rootfs.img`). SSH path may use a single-FIT (inactive) package per unified OTA `make upgrade` packaging. If the archive lacks members for the selected transport, fail fast.

### 5. Format detection

**Choice:** Treat `.tar.gz` / `.tgz` as gzip tar; `.tar` as uncompressed tar. Reject `.zip` and unknown suffixes unless content sniff confirms tar/gzip-tar (optional enhancement; suffix-first is enough for v1).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Archive built for SSH (one FIT) used on RockUSB | Fail fast listing missing `boot_b.img` (etc.) |
| Huge extract fills host disk | Temp under `output/` or `/tmp` with size check; document |
| Stale `UPGRADE_PACKAGE` in `.env` surprises operators | Help text + echo resolved path at start of upgrade |
| Extract path differs from stream path naming | Single member→role map shared with docs / ota-package |

## Migration Plan

1. Land after or alongside staged SSH upload from `unified-ota-cyber-ota` (SSH branch of this feature needs that ingress; RockUSB extract+`di` can land against today’s `upgrade-ota`).
2. Document `UPGRADE_PACKAGE=` examples for SSH and Loader.
3. No board flash required for host-only RockUSB extract path beyond existing Loader workflow.

## Open Questions

1. Exact member filenames when `ota-package` only embeds inactive FIT—confirm RockUSB package variant (dual FIT) naming in `ota-package` docs.
2. Whether `UPGRADE_PACKAGE=` implies `OEM_ONLY` when archive contains only oem (auto-detect vs require `OEM_ONLY=1`).
