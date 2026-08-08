## Why

System cloud OTA still had a dual-channel model (`staging.json` + `-beta`, `RELEASE=1` for release) and tied Check for Updates to cloud services / Worker pinned API `/r2/…`. Peripheral firmware is release-only on the public CDN. Operators need one rule: publish and check only **release** packages via **`https://cdn.lasercyber.com/`**, independent of 云服务.

## What Changes

- **BREAKING:** Host `make publish` / `publish-only` always writes `{artifact}/release.json` and uploads `v{semver}.tar.gz` without `-beta` / `-alpha`. Remove `RELEASE=`; fail if `RELEASE` is set.
- **BREAKING:** App system and peripheral OTA checks fetch **`https://cdn.lasercyber.com/{artifact}/…/release.json`** (not Worker `/r2/` or pinned API). Checks MUST NOT require cloud services enabled.
- Drop staging/prerelease docs for system publish; align with peripheral release-only.
- Keep cloud environment tiers for WebSocket / registration API probing only — unrelated to OTA manifest URLs.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `host-ota-publish`: Release-only publish; remove `RELEASE` / `staging.json` / `-beta`; document CDN discovery.
- `cyber-ota`: Channel examples use release-shaped CDN URLs.
- `ota-upgrade-ui`: System Upgrade checks CDN `release.json`; independent of cloud services / pin.
- `peripheral-firmware-cloud-ota`: CDN `release.json` paths; independent of cloud services / pin.
- `settings-ui`: Device Information no longer treats cloud-services-off as Check unavailable.

## Impact

- Host publish scripts/docs; App `OtaManifestUrl` / `PeripheralFirmwareManifestUrl`; l10n check-failed copy; OpenSpec main specs listed above.
