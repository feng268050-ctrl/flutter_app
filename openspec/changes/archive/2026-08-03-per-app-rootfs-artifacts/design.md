## Context

`APP=` already selects which Flutter HMI is baked into overlay `/opt/hmi`. Host still publishes a single `output/firmware/rootfs.img`, so product A and product B overwrite each other. Boot FITs remain product-shared; rootfs and factory packages that embed rootfs must not.

## Goals / Non-Goals

**Goals:**

- Per-`APP` host path for `rootfs.img`: `output/firmware/<APP>/rootfs.img`.
- `build-rootfs` publishes there; `upgrade` loads from there; `build-img`/`flash` use APP-scoped factory output that embeds that rootfs.
- Shared boot stays at `output/firmware/boot.img` (+ `boot_b.img`).
- Default `APP=lws_hmi` remains the daily path.

**Non-Goals:**

- Per-APP boot FITs or kernel rebuilds.
- Changing on-device stream basename (`rootfs.img` on the wire / OTA dir).
- Multi-APP in one rootfs image.

## Decisions

### 1. Layout

```
output/firmware/
  boot.img / boot_b.img / Image     # shared
  <APP>/                            # e.g. lws_hmi, cnc_hmi
    rootfs.img                      # (+ ext2/ext4 if exported)
    <FACTORY_SKU>/
      factory.img
      manifest.txt
      …
  update.img → <APP>/<sku>/factory.img   # default APP + default/selected sku
```

Optional migration: after default-APP rootfs export, `output/firmware/rootfs.img` MAY be a symlink to `<APP>/rootfs.img` (not a second copy). Prefer symlink so stale flat files are obvious.

### 2. Resolver

Extend `scripts/app-select.sh` (or thin `firmware-app.sh` sourced after it) to export:

- `APP_FIRMWARE_DIR=$ROOT/output/firmware/$APP`
- `APP_ROOTFS_IMG=$APP_FIRMWARE_DIR/rootfs.img`

`factory-sku.sh` sets `FACTORY_OUT_DIR=$APP_FIRMWARE_DIR/$FACTORY_SKU` (requires `APP` defaulted; source app-select or inline default).

### 3. build-rootfs / docker-export

After SDK pack, export rootfs basenames into `APP_FIRMWARE_DIR` (not only firmware root). Pass `APP` into `docker-export-artifacts.sh rootfs`.

### 4. upgrade

`upgrade-remote.sh`: resolve `ROOTFS_IMG` from `APP_ROOTFS_IMG`; boot/oem paths unchanged (boot shared; oem via FACTORY_SKU).

### 5. build-img / flash

- Stage `APP_ROOTFS_IMG` into SDK `output/firmware/rootfs.img` before `./build.sh updateimg` (SDK still uses flat basename internally).
- Publish `factory.img` under `output/firmware/<APP>/<sku>/`.
- `flash-usb.sh` default `FACTORY_IMG` uses APP-scoped path.

### 6. Emulator

`build-emulator` copies device rootfs from `APP_ROOTFS_IMG` (default APP).

## Risks / Trade-offs

- [Existing scripts/docs assume flat rootfs] → Update help/AGENTS; optional symlink for default APP.
- [Wrong APP on upgrade flashes wrong HMI] → Fail if missing with `APP=… make build-rootfs` hint.
- [SDK volume still one rootfs.img] → OK: one Buildroot pack at a time; host keeps per-APP copies.

## Migration Plan

1. `APP=lws_hmi make build-rootfs` → `output/firmware/lws_hmi/rootfs.img`
2. `make upgrade` / `make flash` with same APP (default)
3. Remove reliance on flat `output/firmware/rootfs.img` except optional symlink

## Open Questions

- None blocking.
