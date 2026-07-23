## Why

`make install` today only installs a locally built APK. Developers and field engineers often need to flash a **specific published staging or release build** from R2 (including **downgrades** for regression) without checking out old code and running a full `make build`. The detailed design in [`docs/make-install-cloud-version-design.md`](../../../docs/make-install-cloud-version-design.md) is reviewed; this change implements that workflow as documented Makefile/CI automation.

## What Changes

- Extend **`make install`** with optional **`VERSION=x.y.z`**: download the matching `lws-app` zip from the public R2 base URL, extract the APK (dynamic zip entry detection), and install via the existing priv-app path.
- Channel selection via **explicit CLI `RELEASE=1`** (release zip) vs default staging (`-beta` suffix); **not** inferred from `.env`.
- Add CI scripts: fetch package, downgrade PM purge (before/after + `package_cache`), verify install (`versionCode`, `versionName`, `pm path`), and **`INSTALL_STRICT=1`** for cloud installs (no streamed `adb install` fallback).
- Preserve existing **`make install`** without `VERSION` (local `TARGET_APK`, streamed fallback allowed).
- Optional **`make install-version`** alias forwarding `VERSION` / `RELEASE`.
- Document usage in `make help`; reference design doc from OpenSpec artifacts.

## Capabilities

### New Capabilities

- `make-install-cloud-version`: Cloud zip download, APK extraction, staging/release channel resolution, downgrade purge, strict PM sync, post-install verification, and `make install VERSION=` integration.

### Modified Capabilities

- `build-ci-tooling`: Extend `make install` requirements to support optional cloud version install, strict vs local PM sync behavior, and help text for `VERSION` / `RELEASE`.

## Impact

- **Makefile**: `install` target branches on `VERSION`; exports `INSTALL_STRICT` / CLI `RELEASE` for cloud path.
- **scripts/ci/**: New `fetch-lws-app-package.sh`, `purge-pm-before-downgrade.sh`, `purge-pm-after-downgrade.sh`, `verify-priv-app-install.sh`; update `sync-pm-after-priv-app-install.sh` for strict mode.
- **Docs**: [`docs/make-install-cloud-version-design.md`](../../../docs/make-install-cloud-version-design.md) (source design; status updated on implementation).
- **Not in scope**: Device OTA app code, `make publish`, zip layout changes, firmware install from cloud zip.
