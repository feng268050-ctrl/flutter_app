## Context

After Vendor Storage identity, `/var/lib/hal/product.ini` holds only tunables. OEM still ships `oem/boards/*/product.ini` and `oem-compose` merges blanks into userdata—wrong once cameras differ per upgrade/batch. App also soft-defaults empty `camera_ip` to `192.168.1.100` and board profiles duplicate `helpers.camera_ip`. Host `set-prop` / `del-prop` already own runtime mutation; the on-disk name should match.

## Goals / Non-Goals

**Goals:**

- Runtime file `/var/lib/hal/properties.ini` (flat `key=value`); HAL + host tooling use only this path.
- No OEM seed; compose does not create or merge properties/product ini.
- HAL returns empty for missing keys; **product App** applies defaults (`camera_ip=192.168.1.100`, `camera_type=1`, `focus_scale_ref=0`, `control_card_comm_alarm_mode=slide_window`).
- One-shot userdata migrate `product.ini` → `properties.ini`.
- Spec capability `properties-ini` supersedes `product-ini`.

**Non-Goals:**

- Moving identity keys back into the ini file.
- New Settings UI to edit all properties (existing IP Camera / Device Information behavior stays; factory remains `set-prop`).
- Renaming Make targets `set-prop` / `del-prop`.
- Changing Vendor Storage ID map or `write-identity`.
- Auto-detecting camera IP on the wire.

## Decisions

### D1 — Rename file only; keep Make verb names

**Decision:** On-disk `properties.ini`; commands stay `make set-prop` / `del-prop`. Shared script may rename `product-ini-common.sh` → `properties-ini-common.sh` (or keep filename with updated internals).

**Alternatives:** Rename Make targets to `set-property` — rejected (operator muscle memory, Makefile churn). Keep `product.ini` name — rejected (user ask + mismatch with set-prop).

### D2 — No OEM / rootfs / App pack seed

**Decision:** Delete OEM seeds; remove `merge_product_ini` from compose. Do not add App-bundled `properties.ini` or overlay default file.

**Alternatives:** App-shipped defaults under `/opt/hmi` — rejected (still couples camera defaults to a ship artifact that lags hardware SKUs).

### D3 — Product App owns tunable keys and defaults

**Decision:** HAL `ProductInfo` built-ins are only `brand` / `model` / `sn` / `chipId`. All other properties.ini entries are opaque via `get(key)`. LWS HMI names keys and applies defaults in `app/lws_hmi/lib/device/product_property_defaults.dart`: `camera_ip` → `192.168.1.100`, `camera_type` → `1`, `focus_scale_ref` → `0`, `control_card_comm_alarm_mode` → `slide_window`. No OEM/file seed; no `helpers.camera_ip` in board profiles.

**Alternatives:** Named HAL accessors for camera/alarm keys — rejected (product/HMI-specific). Defaults in HAL — rejected. Empty = unconfigured — rejected for this product’s default SKU.

### D4 — Migrate old basename on bind-prefs

**Decision:** In `bind-prefs` (HAL userdata bind path), if `properties.ini` absent and `product.ini` present under `/userdata/hal/` (or folded from legacy HMI tree), rename to `properties.ini`. Host `set-prop` MAY apply the same rename before mutate. Do not merge two files if both exist—prefer `properties.ini`, leave stale `product.ini` for manual cleanup or delete after successful rename-only case.

**Alternatives:** HAL-only rename on first read — weaker for host tools that never start HMI; bind-prefs is early and shared.

### D5 — HAL API naming

**Decision:** Path constant → `kPropertiesIniPath`. `ProductInfo` remains the identity + opaque bag type; only `get(key)` for non-identity properties. Stale `brand`/`model`/`sn` lines in the file remain ignored for identity.

### D6 — Spec capability rename

**Decision:** New capability `properties-ini` with full requirements; `product-ini` requirements REMOVED (superseded). Cross-specs updated to say `properties.ini` and Vendor Storage for identity where still stale.

## Risks / Trade-offs

- **[Risk] Lab boards / default SKU need camera without set-prop** → Mitigation: LWS HMI App product defaults (D3); operators override with `set-prop` when cameras differ.
- **[Risk] Dual files if operator copies both** → Mitigation: prefer `properties.ini`; document; bind-prefs does not merge.
- **[Risk] Stale docs/scripts still say product.ini** → Mitigation: tasks grep gate; verify-rootfs / host script self-check optional.
- **[Trade-off] Defaults live in product App code, not HAL or a seed file** → Accepted; other Apps can choose different defaults.
## Migration Plan

1. Ship overlay + HAL + host that understand `properties.ini` and migrate basename.
2. Delete OEM seeds; remove compose merge (OEM-only upgrade enough for compose; App/HAL need push-app / rootfs as touched).
3. Existing devices: next boot bind-prefs renames; camera IP preserved.
4. New flash: empty properties until `set-prop`; identity via `write-identity`.
5. Rollback: restore old overlay/HAL that read `product.ini` only would miss renamed file—avoid partial rollback; if needed, rename file back on device.

## Open Questions

None blocking—soft-default removal confirmed with stakeholders in explore. If Factory Test later needs a camera without set-prop, that App can document its own inject path without restoring OEM seed.
