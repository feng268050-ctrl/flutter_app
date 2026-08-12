## Context

**恢复出厂设置 is a user product feature.** The operator uses product **HMI Settings** to wipe *their* data and settings. It is **not** a 产线 feature: production continues to provision via `make set-prop` / `write-identity` / factory flash; those workflows must not be conflated with this button.

Operator prefs and App state live on **`userdata`**. Upgrade/OTA must not wipe them. Users need a deliberate reset that:

- Clears networks, UI prefs, App DBs, media, OTA staging, models, etc.
- Leaves **non-user** device material alone: `properties.ini` (产线 tunables), VS brand/model/SN, **activated cloud ID 22**, seal KEK ID 23, firmware partitions.

## Goals / Non-Goals

**Goals:**

- User-facing HMI Settings action with strong confirmation → board helper → reboot to clean **user** defaults.
- One wipe contract for that action (and any optional OS Settings mirror / flash-time prefs hygiene).
- Preserve provisioning + cloud activation across user reset.
- Clear docs: this is Settings for users; 产线 tools are separate.

**Non-Goals:**

- Designing or replacing 产线 procedures (`set-prop`, identity write, `make flash`).
- Reflashing boot/rootfs/oem or rolling back firmware version.
- Clearing cloud Ed25519 / forcing re-activation.
- Clearing `properties.ini`.
- Cloud-remote wipe in v1.
- Host **`make factory-reset`** (or other host SSH wipe SOP).
- Per-subsystem “reset Wi‑Fi only” modes.

## Decisions

### D1 — Product framing: user Settings, not 产线

Ship and document **恢复出厂设置** under product HMI Settings. Copy and docs MUST speak to the end user (data/settings erased; device identity and cloud stay). Do **not** present host Make or flash as the product’s factory-reset feature.

### D2 — Single board helper is the SoT

`/usr/libexec/board/factory-reset.sh` + `/usr/bin/factory-reset`. HMI (required) and any optional callers invoke it; no Dart-only wipe.

### D3 — Selective wipe; preserve non-user provisioning

1. Stop Flutter seats and stacks holding prefs open.
2. Clear `/userdata/{wpa_supplicant,network,bluetooth,hmi,storage,ota,models,tee,cfg}`.
3. Under `/userdata/hal/`: delete operator prefs (`display.conf`, `sound.conf`, …); **keep `properties.ini`**.
4. Do not touch VS **1 / 20 / 21 / 22 / 23**.
5. Recreate bind layout for wiped trees; sync; reboot.

No default live `mkfs` of userdata (would destroy `properties.ini`).

### D4 — Preserve vs erase

| Preserve (not user data) | Erase (user / operator data) |
|--------------------------|------------------------------|
| VS 1/20/21 identity | wpa / network / bluetooth trees |
| VS 22 cloud Ed25519 (activated) | hmi App DBs & settings |
| VS 23 seal KEK | operator files under `hal/` except `properties.ini` |
| `properties.ini` | storage / ota / models / tee / cfg |
| GPT, boot*, rootfs_*, oem, misc, firmware | |

### D5 — UI: HMI required; OS Settings optional mirror

- **Required:** product HMI Settings → 恢复出厂设置 / Erase All Data, two-step confirm.
- **Optional:** same control in OS Settings if that seat is used (same helper) — convenience only, not the product definition.
- Confirm copy: user data/settings gone; provisioning and cloud activation kept; firmware not rolled back.

### D6 — No host Make target; flash is not the feature

- **Do not** add `make factory-reset` (or equivalent host SSH wipe target).
- Flash-time operator-prefs cleanup (if any): platform hygiene aligned with the wipe contract; **not** “how users factory-reset.”

### D7 — Logging

Journal progress; never delete `properties.ini` or mutate VS identity/cloud/KEK; then reboot.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| User accidental wipe | Two-step confirm; plain-language keep vs erase |
| Confusing with 产线 flash | Docs/UI: user Settings only; 产线 tools unchanged |
| Blind format kills `properties.ini` | Selective wipe; no default mkfs |
| tee cache delete vs cloud | Keep VS 22+23; restore KEK after reboot |

## Migration Plan

1. Helper in rootfs + **HMI Settings** UI (user feature).
2. Optional OS Settings mirror — secondary.
3. Rollback: remove Settings entry; helper unused.

## Open Questions

- Exact HMI Settings IA placement (Device Information vs System group) — follow existing Settings layout in implementation.
