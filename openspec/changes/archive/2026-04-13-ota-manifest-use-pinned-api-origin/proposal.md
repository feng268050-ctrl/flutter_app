## Why

App OTA currently fetches `staging.json` / `release.json` from a **hardcoded** Workers host (`api-prod.lasercyber.workers.dev`), while HTTP API and WebSocket traffic already use the **in-memory pinned** base chosen by `DeviceApiOriginProber`. That split can send OTA checks to a different reachable origin than the rest of the app (e.g. test vs prod channel, or LAN gateway with a path prefix). Cloud storage is the same R2 bucket behind both paths, so aligning the manifest host with the pin does not change which logical data is served; **staging vs release remains** the existing `BuildConfig.LWS_MANIFEST_JSON_FILE` selection.

## What Changes

- Replace the OTA manifest fetch base URL with the **same pinned API origin** used for Worker HTTPS and `/ws/device` (`DeviceApiOriginConfig`), joining `/view/lws-app/<json_file>` with the project’s existing base+path join rules (correct for path-prefixed gateways).
- Remove the hardcoded `https://api-prod.lasercyber.workers.dev/view/lws-app/` constant from the OTA check path.
- When **no pin exists yet** (probe has not succeeded), do **not** silently default to the old prod host; surface failure consistent with “Worker not reachable” rather than inventing a second origin.
- **No change** to semver comparison, zip handling, or `staging.json` vs `release.json` build configuration.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `lws-app-ota-semver`: Update the manifest fetch requirement so the descriptor URL is derived from the pinned Worker API base + `/view/lws-app/<json_file>`; add scenarios for path-prefixed pins and absent pin (no hardcoded prod fallback).

## Impact

- **Code:** `DeviceInformationFragment.checkUpgrade()` (and any other caller of the manifest URL, if present); possibly small helpers on `DeviceApiOriginConfig` for clarity.
- **Specs:** Delta under `openspec/changes/.../specs/lws-app-ota-semver/spec.md` for archive/apply.
- **Runtime:** OTA check tracks the same origin as presigned upload, other Worker HTTP, and WebSocket after a successful probe.
