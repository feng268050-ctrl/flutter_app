## Context

Platform plan [`docs/platform-os-oem-sdk-plan.md`](../../../docs/platform-os-oem-sdk-plan.md) freezes OEM = board×screen (+ v1 product.ini), App = gpio/modbus, boot/rootfs = common OS. GPT already has a ~128 MiB `oem` partition mounted at `/oem`, but content is empty and factory `package-file` does not include oem. Board profile still ships as an App Flutter asset.

W1 delivers one working SKU (`ynh960+panel-800x1280`) end-to-end without moving helpers, trimming linux-sdk, or building the UTM sim pack.

## Goals / Non-Goals

**Goals:**

- OEM source tree + ext4 `oem.img` via `make build-oem`
- Compose exports `/run/hmi/*` before HMI; seed product.ini safely
- App loads OEM profile + merges App gpio/modbus
- `FACTORY_SKU` thin resolver; `factory.img` with oem; upgrade streams oem by default when built
- Migration fallback when `/oem` absent (deprecation window)

**Non-Goals:**

- Moving modem/OTG helpers into OEM (W2)
- linux-sdk whitelist import (W3)
- `sim+virt` / UTM (W4)
- Factory Test App; retiring private1 LCD seed

## Decisions

### D1 — OEM pack layout matches platform plan §3.2

```text
oem/packs/<pack_id>/manifest.json
oem/boards/<board_id>/{board_profile.json,product.ini}
oem/screens/<screen_id>/screen.json
oem/out/<oem_id>/oem.img   # gitignored build output
```

Device layout after compose: `/oem/manifest.json`, `/oem/boards/…`, `/oem/screens/…` (flat copy of selected pack contents, not nested `packs/` on device).

### D2 — Profile merge in Dart, not in compose

Compose may copy OEM `board_profile.json` to `/run/hmi/board_profile.json` unchanged (no gpio/modbus). App calls `withProductConfigs` with `assets/hal/gpio.json` and `assets/hal/modbus.json`. Rationale: product catalogs stay App-owned; compose stays shell/simple.

### D3 — product.ini seed = merge-missing-keys

On compose: if `/var/lib/hal/product.ini` missing, copy OEM seed. If present, for each key in OEM seed, write only when destination key absent or blank. Never overwrite operator/`set-prop` values. Runtime path remains `/var/lib/hal/product.ini`.

### D4 — FACTORY_SKU shared resolver

`scripts/factory-sku.sh` sourced by `build-oem`, `build-img`, `flash`, `upgrade`:

- Table: `board/factory-skus.tsv` (`sku`, `uboot_id`, `oem_id`)
- Default sku `ynh960-p800`
- Overrides: `UBOOT_ID`, `OEM_ID`
- Missing bootloader/oem files → fail hard

Bootloader: `prebuilt/bootloader/rockchip-ynh960/{uboot.img,MiniLoaderAll.bin}` (relocate or symlink from today’s `prebuilt/sdk-uboot` / `sdk-loader`).

### D5 — factory.img + update.img symlink

`build-img` writes `output/firmware/<sku>/factory.img` and `manifest.txt`. Also refresh `output/firmware/update.img` as symlink to the default (or selected) sku’s `factory.img` so existing docs/CI keep working during transition.

### D6 — Migration fallback

If `/oem/manifest.json` missing or invalid: compose logs warning, writes fallback env from rootfs-bundled ynh960 defaults (copy of OEM board_profile into `/usr/share/hmi/oem-fallback/` or similar), and App may still `loadAsset`. When OEM present but corrupt → fail compose (do not load another board). Deprecation comment in scripts.

### D7 — package-file adds oem

Extend `board/package-file-ynh960-linux-ab` with `oem` line pointing at staged `oem.img`. Flash therefore writes the oem partition.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Boards without oem.img after upgrade keep empty `/oem` | Default `OEM_IMG` to built oem; docs require `build-oem` before full SKU switch; OEM iterate via `OEM_ONLY=1` |
| Wrong uboot/oem paired in factory image | SKU table + fail-if-missing; `manifest.txt` beside factory.img |
| App starts before compose | systemd ordering: `oem-compose.service` Before=`hmi.service` |
| Dual profile sources confuse tests | Unit tests use fixtures; host debug keeps asset fallback |

## Migration Plan

1. Land OpenSpec + code; ship rootfs with compose + fallback.
2. Operators run `build-oem` then `upgrade` (or `build-img`/`flash`) once to populate oem.
3. After all lab boards have oem, remove App asset fallback in a follow-up change.
4. W2+ moves helpers / screen lcd files; W4 adds sim pack.

## Open Questions

None for W1 — platform plan §11 decisions apply.
