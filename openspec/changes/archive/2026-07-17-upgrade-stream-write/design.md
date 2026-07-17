## Context

P2.5 delivered A/B boot+rootfs and `make upgrade` over USB-SSH / LAN SSH. The current host path copies `boot.img`, `boot_b.img`, and `rootfs.img` into `/userdata/ota/`, then runs `ab-upgrade-apply.sh`, which sha256-verifies the staged files and `dd`s them to the inactive partitions. Operators see transfer progress finish, then sit through a second silent wait (~30s for rootfs `dd`) before reboot.

Future product OTA (P4.8 / P5.8) needs download-to-userdata, digest verification, then write — so the staged apply path must remain. This change splits **dev SSH stream apply** from **OTA staged apply** without changing GPT, misc slot marker, or boot-confirm semantics.

## Goals / Non-Goals

**Goals:**

- `make upgrade` writes inactive rootfs (+ matching FIT, optional oem) **while streaming** over SSH — one operator wait aligned with write progress.
- Transfer only the **inactive letter’s FIT**, not both FITs.
- Keep `/userdata/ota/` + `ab-upgrade-apply.sh` as the **staged** contract for online OTA.
- Preserve safety: no userdata wipe, no mounted-root overwrite, no uboot rewrite, reject pending try-boot / misc↔mount mismatch; incomplete stream must not arm try-boot.

**Non-Goals:**

- Implementing product OTA UI / cloud download.
- Changing GPT, U-Boot, MiniLoader, or `make flash`.
- Reading back full partitions to re-hash after stream (would erase the UX win).
- Making LAN untrusted-CDN semantics apply to `make upgrade` (that is OTA’s job).

## Decisions

### 1. Two apply modes, one slot model

| Mode | Entry | Payload path | Integrity | Used by |
|------|--------|--------------|-----------|---------|
| **Stream** | `make upgrade` / `upgrade-remote.sh` | SSH stdin → `dd` of inactive devices | Trusted SSH + expected byte counts | Daily host iteration |
| **Staged** | `ab-upgrade-apply.sh` | Files under `/userdata/ota/` → verify → `dd` | Sibling `.sha256` / manifest digests | Future online OTA |

**Alternatives considered:** Unify everything on staged apply (keeps double wait); stream everything including OTA (breaks resume / CDN trust). Rejected.

### 2. Host-orchestrated stream sequence

1. Preflight over SSH (reuse `ab-slot-lib.sh`): mounted root letter, misc active, try-boot pending?, inactive letter, partition paths + capacities.
2. Fail fast if try-boot pending, misc≠mount, or host image sizes exceed capacities (same GPT check as today via `verify-firmware-partitions.sh` on host).
3. Stream `rootfs.img` → inactive `rootfs_*` (`dd of=… bs=4M conv=fsync` reading stdin / counted bytes).
4. On-board: backup running FIT `boot` → `boot_b` (local `dd`, small).
5. Stream inactive FIT only (`boot.img` if inactive=A, else `boot_b.img`) → `boot`.
6. Optional: stream `oem.img` → oem.
7. Arm misc try-boot + `apply.status=ok` + reboot.

Helpers for preflight / arm / backup may be a thin board script (or extended lib) invoked by the host; full images MUST NOT be staged for the stream path.

**Alternatives considered:** Board daemon that pulls from host (more moving parts); keep staging both FITs then stream only rootfs (still wastes time/space). Rejected.

### 3. Integrity policy for stream vs staged

- **Stream:** SSH provides transport integrity. Host asserts exact byte length written; board/`dd` must not arm if the stream is truncated or SSH fails mid-write. No mandatory full-image sha256 of userdata copies.
- **Staged:** Keep current file digests before any `dd`.

**Alternatives considered:** Stream through `sha256sum` with process substitution (BusyBox/`sh` fragile); read-back hash after write (slow). Deferred unless a concrete failure mode appears.

### 4. Progress UX

Single continuous progress over total streamed bytes (rootfs + FIT [+ oem]), or clearly sequenced labeled bars that still feel like one operation ending at reboot. No “Transfer complete” then long silent apply.

### 5. Docs contract

`docs/storage-layout.md` / README MUST state: **`make upgrade` = stream-to-partition**; **online OTA = stage under `/userdata/ota/` then apply**. Staging helpers for stream (tiny scripts/status) may still use `/userdata/ota/` for logs/status only — not full firmware images.

## Risks / Trade-offs

- **[Risk] Mid-stream abort leaves partial inactive rootfs/boot** → Mitigation: do not arm try-boot until all streams succeed; active letter remains bootable; next successful upgrade rewrites inactive.
- **[Risk] Stream path skips file digest; wrong host artifact could be written** → Mitigation: host still requires local `boot.img`/`boot_b.img`/`rootfs.img` present and size-checked against GPT; SSH target selection unchanged; OTA retains digests.
- **[Risk] Older boards only have staged apply** → Mitigation: ship stream helpers with upgrade (same pattern as today’s scp of apply scripts) or fall back to staged if stream helper missing (optional; prefer fail-clear with “rebuild rootfs / flash once”).
- **[Risk] OEM / dual-FIT docs drift** → Mitigation: update acceptance + storage-layout in the same change.

## Migration Plan

1. Implement stream path in `upgrade-remote.sh` + board helpers; keep `ab-upgrade-apply.sh` staged behavior intact.
2. Doc/help wording update; acceptance checklist covers stream happy path + abort-before-arm + staged still works if invoked manually.
3. No GPT flash required. Boards already on P2.4 GPT work after overlay/rootfs that includes any new helper, or after host ships helpers via the upgrade scp of libexec scripts (prefer: host can push the small stream/preflight scripts to `/userdata/ota/` like today’s apply helpers).
4. Rollback: revert host script to stage-then-apply; board staged apply unchanged.

## Open Questions

- None blocking: stream integrity = SSH + byte count is an accepted product decision for `make upgrade`.
- Optional later: whether a missing onboard stream helper should auto-fall back to staged apply (default proposal: **no silent fallback** — keep UX consistent; push helpers with the upgrade session).
