## Context

Today ynh960 stores **identity** in Rockchip Vendor Storage (`vendor0–vendor3`, IDs 1/20/21/22/23) with a proven **flash non-overwrite** contract (`package-file` omits vendor payloads). **Tunables** live in `/var/lib/hal/properties.ini` bound to **userdata** — incompatible with planned **full userdata wipe** on factory-reset and 返厂 flash hygiene.

A temporary `oem/boards/sim/identity.env` stub causes **shared SN** across QEMU guests and is not a production authority.

Rockchip Vendor Storage has **vendor-specific meaning**: U-Boot / Loader / Maskrom expose product SN (`upgrade_tool SN` / `RSN`) from `VENDOR_SN_ID`. That must remain on all **Rockchip** boards even when we add GPT `provision`.

## Goals / Non-Goals

**Goals:**

- **返厂 `make flash`** preserves device identity (VS on Rockchip) + `properties.ini` + cloud activation material.
- **Factory-reset** wipes **all userdata**; VS + provision untouched.
- **Rockchip boards:** **Vendor Storage + provision** (dual); identity/cloud secrets in VS; tunables in provision.
- **Non-Rockchip:** single **provision** partition for identity + tunables + sealed blobs.
- **Emulator:** per-instance virtio `provision.img`; no OEM per-unit SN.
- Same **omit-from-package-file** contract as vendor for provision.

**Non-Goals:**

- Moving Rockchip identity off Vendor Storage to provision-only.
- Putting per-unit data in userdata or OEM packs.
- RPMB / eFuse new backends in this change.
- `make factory-reset` host target.

## Decisions

### D1 — GPT `provision` partition (frozen ABI)

- **Choice:** Fixed partition `provision`, `PARTLABEL=provision`, **4 MiB** (`0x2000` × 512 B sectors), ext4, inserted **before** userdata grow.
- **ynh960 line (current parameter tail):** after `vendor3@0x4BE180`, `provision@0x4BE200`, userdata grow `@0x4C0200`.
- **Why:** Dedicated flash-surviving store outside userdata/rootfs/oem; size enough for ini + small sealed files on non-Rockchip.
- **Alternatives:** userdata selective preserve (rejected — user requires full userdata wipe); `private` partition (rejected — mixed with LCD params role).

### D2 — Rockchip: Vendor Storage + provision (not either/or)

| Data | Rockchip boards | Non-Rockchip |
|------|-----------------|--------------|
| brand / model / SN | **Vendor Storage** (IDs 1/20/21) | `provision/identity.env` |
| cloud Ed25519 sealed | **VS ID 22** | `provision/cloud-ed25519.sealed` |
| seal KEK wrap | **VS ID 23** | `provision/seal-kek.wrap` |
| `properties.ini` | **provision** | **provision** |

- **Rationale:** VS keeps Loader/Maskrom SN and existing ynh960 factory SOP; provision holds tunables without userdata.

### D3 — Flash non-overwrite (same mechanism as vendor)

1. `parameter` **defines** `provision` (every compliant `factory.img`).
2. `package-file` **MUST NOT** list `provision` or embed `provision.img`.
3. `upgrade_tool uf` writes only packaged partitions → **provision LBA bytes untouched** on repeat flash when geometry unchanged.
4. `build-img` / verify **fail closed** if `provision` appears in package-file or staging.

**Not** “second flash uses a different factory.img without provision in parameter” — both flashes use the same layout; survival is **omit payload**, not omit partition definition.

### D4 — Runtime mount and bind

- Early boot (`display-init` or dedicated `provision-mount.service` before `bind-prefs`):
  - `mount PARTLABEL=provision` → `/mnt/provision` (mkfs ext4 **only** when partition empty/unformatted).
- `/var/lib/hal/properties.ini` → bind/symlink to `/mnt/provision/properties.ini` (never `/userdata/hal/properties.ini`).
- `bind-prefs` userdata trees: wpa, network, bluetooth, hmi — **no** `properties.ini` under userdata/hal.
- One-time migration: copy existing `/userdata/hal/properties.ini` → provision if provision file absent.

### D5 — Identity read path

- `read-product-identity.sh`:
  - Rockchip + `/dev/vendor_storage`: read VS (existing).
  - Else: read `provision/identity.env` (emulator / non-Rockchip).
  - **Remove** OEM `identity.env` / `IDENTITY_STUB` search paths.
- Empty SN → chip-ID fallback (existing `read-device-serial` chain).

### D6 — Emulator (`sim_virt`)

- Host: `output/firmware/emulator/provision.img` (virtio disk, not in shared rootfs).
- Guest: same mount/bind as hardware provision.
- First boot, empty identity: **dev-only** autogen SN (e.g. `SIM` + stable hash) into `provision/identity.env` — per `provision.img`, not OEM.
- `write-identity` over SSH: write `provision/identity.env` when no VS (not fail hard).

### D7 — Factory-reset and flash userdata

- **Factory-reset:** `mkfs` or recursive wipe **entire userdata** partition; **MUST NOT** format `provision` or write VS IDs.
- **Flash hygiene:** userdata cleared on factory flash path (aligned with reset); VS + provision preserved via D3.

### D8 — Board profile hints

`board_profile.json` MAY declare:

```json
"provision": { "backend": "gpt" | "virtio" },
"identity_backend": "rockchip-vs" | "provision-file"
```

Rockchip packs: `identity_backend=rockchip-vs`, `provision.backend=gpt`. `sim`: `identity_backend=provision-file`, `provision.backend=virtio`.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| First GPT adoption moves userdata start → userdata loss | Document one-time `make flash`; VS unchanged |
| Someone adds `provision.img` to package-file | verify script + CI |
| Stale `properties.ini` on userdata after migration | one-time copy + bind-prefs stops writing userdata copy |
| Emulator without per-instance provision.img | document `provision.img` per developer; autogen SN |
| Non-Rockchip boards need new GPT row | board-specific parameter fragments |

## Migration Plan

1. Land GPT + verify gates + mount/bind (rootfs can ship before field flash).
2. One-time **`make flash`** per board to adopt `provision` partition.
3. Boot migrates `properties.ini` userdata → provision.
4. Remove `oem/boards/sim/identity.env`; rebuild `sim_virt` OEM.
5. Update factory-reset change to full userdata wipe + preserve provision.
6. SOP: flash → verify `read-identity` + `properties.ini` on provision.

## Open Questions

- Exact `provision` size on non-ynh960 GPT templates (default 4 MiB unless sealed blobs need more).
- Whether flash-time userdata wipe is implemented in host tooling in this change or paired with `factory-reset` change.
