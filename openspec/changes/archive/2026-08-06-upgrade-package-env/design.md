## Context

`make upgrade` resolves targets via `UPGRADE_TRANSPORT=auto|ssh|rockusb`. `unified-ota-cyber-ota` moves the SSH path to **host HTTP serve + device download** staged apply. Operators also need to feed an **already-built** archive without re-invoking the full build/package graph.

Package layout aligns with `make ota-package`: `tar` or `tar.gz` containing partition `*.img` (+ optional orchestration `manifest.json`). Signing policy lives in `unified-ota-cyber-ota`: **USB-SSH/SSH host upgrade requires Ed25519** (host serves archive + `.sig`; device downloads and verifies); cloud download does too; RockUSB `di` does not. This change wires **input selection**, **sibling `.sig` discovery for SSH**, and **transport branching**.

## Goals / Non-Goals

**Goals:**

- **`UPGRADE_PACKAGE=<path>`** on `make upgrade`: use that archive instead of default tree/`ota-package` outputs.
- Accept **`.tar`**, **`.tar.gz`**, **`.tgz`** (detect by name and/or magic; fail clearly otherwise).
- **SSH / USB-SSH**: serve archive **+ sibling `<path>.sig`** over ephemeral HTTP → device download + staged OTA **verify**-apply (progress/UX per unified OTA HostHttpIngress). Missing `.sig` fails fast.
- **RockUSB Loader/Maskrom**: host-side extract → existing `upgrade-ota` `di` of extracted images (`.sig` not required; both letters).
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

When unset: existing default behavior (after unified OTA: build/use default `ota-package` artifact).

**Alternative:** positional Make argument. Rejected: inconsistent with `OEM_IMG=`, `SN=`, etc.

### 2. SSH path: host HTTP serve archive + sibling `.sig`

**Choice:** Serve the given file as-is (documented basename) **and** the default sibling signature at **`<UPGRADE_PACKAGE>.sig`** via ephemeral host HTTP; trigger HMI `download <url>`; device **verify** + extract + apply. Do **not** host-extract before the SSH path (keeps one transfer unit and matches cloud package shape).

Missing sibling `.sig` → fail fast on SSH (aligned with `unified-ota-cyber-ota`).

### 3. RockUSB path: extract then `di`

**Choice:** Extract into a host temp dir (or documented cache under `output/`), map members to the same image roles `flash-usb.sh upgrade-ota` expects (`boot.img` / `boot_b.img` / `rootfs.img` / optional `oem.img`), then invoke existing `di` logic. Prefer extracting only what `upgrade-ota` needs; clean temp on success (best-effort on failure).

**Why not stage on board in Loader:** no Linux SSH / no `/userdata/ota/` apply stack in Loader/Maskrom.

**Why not `uf` the tarball:** product policy remains OTA-equivalent `di`, not factory `uf`.

### 4. Archive member rules

**Choice:** Require members consistent with packaging mode:

- Full-system SSH: package contains both FITs + `rootfs.img` as produced by `ota-package`; apply uses inactive letter only.
- RockUSB full-system: need both FITs + rootfs as today’s `upgrade-ota`.

**Practical rule for v1:** Document that RockUSB+`UPGRADE_PACKAGE` expects an archive whose members satisfy `upgrade-ota` inputs (both `boot.img` and `boot_b.img` + `rootfs.img`). If the archive lacks members for the selected transport, fail fast.

### 5. Format detection

**Choice:** Treat `.tar.gz` / `.tgz` as gzip tar; `.tar` as uncompressed tar. Reject `.zip` and unknown suffixes unless content sniff confirms tar/gzip-tar (optional enhancement; suffix-first is enough for v1).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Archive missing dual FIT used on RockUSB | Fail fast listing missing `boot_b.img` (etc.) |
| Huge extract fills host disk | Temp under `output/` or `/tmp` with size check; document |
| Stale `UPGRADE_PACKAGE` in `.env` surprises operators | Help text + echo resolved path at start of upgrade |
| Extract path differs from package naming | Single member→role map shared with docs / ota-package |

## Migration Plan

1. Land with `unified-ota-cyber-ota` HostHttpIngress (SSH branch of this feature needs that ingress; RockUSB extract+`di` can land against today’s `upgrade-ota`).
2. Document `UPGRADE_PACKAGE=` examples for SSH and Loader.
3. No board flash required for host-only RockUSB extract path beyond existing Loader workflow.

## Resolved Questions

1. **Member filenames:** Same as `make ota-package` / `lws-ota-tar-v1`: flat `boot.img`, `boot_b.img`, `rootfs.img`, optional `oem.img` (+ `manifest.json`). SSH and RockUSB both use the dual-FIT archive; SSH apply uses the inactive letter only, RockUSB `di`s both FITs + both rootfs letters.
2. **OEM-only archives:** Do **not** auto-set `OEM_ONLY` from member list. Operators MUST pass **`OEM_ONLY=1`** for oem-only packages; otherwise full-system member checks apply and fail fast if FITs/rootfs are missing.
