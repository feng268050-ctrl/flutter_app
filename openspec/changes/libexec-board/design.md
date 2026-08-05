## Context

`os-path-layout` already splits **state** into `/var/lib/hal` vs `/var/lib/hmi`, but **helpers** remain mostly under `/usr/libexec/hmi/`. The recent Vendor Storage identity work placed `read-product-identity` / `write-product-identity` / ID map next to `read-device-serial` under `hmi/`, even though host identity tooling and `cyber_hal` callers own those contracts. `os-path-layout` previously stated relocating into `/usr/libexec/hal/` was not required—this change introduces **`/usr/libexec/board/`** instead (not `hal/`), and moves the non-HMI set there.

Constraints: FHS libexec tiers; operator UX stays `/usr/bin/<verb-noun>`; minimize churn to Flutter App and USB/A/B helpers that are truly HMI/boot-adjacent.

## Goals / Non-Goals

**Goals:**

- Introduce `/usr/libexec/board/` as the home for board helpers that are not UI/App-owned.
- Move the identity + serial + secrets-seal cluster out of `hmi/` with updated `/usr/bin` links and HAL/OEM references.
- Document a durable ownership rule so future helpers land in the right tier.

**Non-Goals:**

- Renaming `/var/lib/hal` or `/var/lib/hmi` (already correct).
- Using `/usr/libexec/hal/` (rejected: false parallel with HAL state; scripts are not the Dart package).
- Moving UI launch (`hmi-launch.sh`), push-app/debug, A/B upgrade stream scripts, USB plug-ssh/MTP gadget stack, or `oem-compose` in this change (compose stays boot/HMI-ordered; revisit later if desired).
- Changing Vendor Storage ID map or product.ini semantics.
- Long-term dual install of the same script under both `hmi/` and `board/`.

## Decisions

### D1 — Initial move set (hard list)

| Artifact | New path | Why |
|----------|----------|-----|
| `read-product-identity.sh` | `/usr/libexec/board/` | ProductInfo / host identity |
| `write-product-identity.sh` | `/usr/libexec/board/` | `make write-identity` |
| `vendor-storage-ids.txt` | `/usr/libexec/board/` | ID map SoT on device |
| `read-device-serial.sh` | `/usr/libexec/board/` | SN rule shared with HAL / USB iSerial |
| `secrets-seal` (+ CA helper if co-located under hmi today) | `/usr/libexec/board/` | Secrets KEK board helper |

**Stay under `/usr/libexec/hmi/` for this change:** `hmi-launch.sh`, diagnose/push/debug, A/B helpers, USB gadget, `oem-compose.sh`, display/bind-prefs orchestration, HW change helpers still documented as hmi-tier in existing specs (backlight may already be HAL-owned via Dart—do not bulk-relocate prefs helpers unless already in the hard list).

**Alternative considered:** Move every script that HAL might ever call → rejected as too large; iterate by ownership.

### D2 — Tier name: `board` (not `hal` / `helpers` / `scripts` / `misc`)

| Candidate | Verdict |
|-----------|---------|
| `hal/` | Rejected — mirrors `/var/lib/hal` but content is board shell helpers, not Dart HAL |
| `scripts/` | Rejected — redundant with libexec itself |
| `misc/` | Rejected — invites a junk drawer with no ownership signal |
| `helpers/` | Rejected — too vague next to libexec’s role |
| **`board/`** | **Chosen** — board/platform contracts (identity, serial, seal); aligns with repo `board/` language |

**Rule of thumb:** dedicated stacks keep their own libexec dir (`wpa`, `network`, …); UI/boot-adjacent stay in `hmi/`; shared board helpers with no better home go in `board/`.

### D3 — Operator PATH unchanged

`/usr/bin/read-serial`, `read-identity`, `write-identity` keep names; only symlink targets change to `/usr/libexec/board/…`. Host scripts that already call `/usr/bin/*` need no logic change.

### D4 — Compatibility: hard cut preferred

Prefer **no** permanent `hmi/` → `board/` symlink farm. One-release optional transitional symlinks under old paths MAY be added if a half-upgraded board risk is real; default implement = hard cut + `make build-rootfs` / `upgrade`. Document that App/HAL must ship with matching rootfs.

**Alternative:** Indefinite compat symlinks → rejected (recreates the naming lie).

### D5 — Source-of-truth layout in git

Overlay tree mirrors device: `rootfs-overlay/usr/libexec/board/`. `board/vendor-storage-ids.txt` remains the repo SoT; install/copy into `/usr/libexec/board/vendor-storage-ids.txt` (same as today under hmi).

### D6 — Spec / docs

Update `os-path-layout` requirement text for libexec tiers. Delta `vendor-storage-identity` helper path wording when that capability is in tree (active change or archived). Update `AGENTS.md` path convention one-liner to include `board` alongside `wpa,network,bluetooth,hmi`.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Stale absolute paths in OEM helpers / profiles | Grep + update `oem/boards/*/board_profile.json`, sim board JSON, HAL defaults |
| Half-upgraded: new App + old rootfs | Operator `/usr/bin` names stable; only direct libexec callers break—keep HAL preferring `/usr/bin` for identity |
| Scope creep into moving USB/A/B | Hard list in D1; tasks refuse drive-by moves |
| Docs still say “hmi helpers” for identity | Patch AGENTS / storage-layout / vendor-storage change docs in apply |
| Confusion with repo `board/` tree | Device path is `/usr/libexec/board/`; git SoT for params/IDs stays `board/` at repo root—document in AGENTS one-liner |

## Migration Plan

1. Land overlay move + post-build + HAL/OEM path updates in one rootfs.
2. `make apply-overlay` → `make build-rootfs` → `make upgrade` (or flash).
3. Verify: `readlink -f /usr/bin/read-identity`, `read-serial`, `write-identity`; HAL ProductInfo still loads; `secrets-seal` path if used.
4. Rollback: revert commit / flash prior rootfs (no data migration).

## Open Questions

- Whether `enable-ssh-debug.sh` / `usb-otg-mode.sh` should move in a **follow-up** (board_profile helpers used by HAL but also operator/debug)—**out of scope** unless apply reveals they must move with secrets/identity for consistency.
- Whether to add a `verify-rootfs-overlay` check that forbids identity scripts under `hmi/`—nice-to-have in tasks if cheap.
