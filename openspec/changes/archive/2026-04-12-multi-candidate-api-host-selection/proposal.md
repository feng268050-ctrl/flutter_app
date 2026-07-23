## Why

The app currently picks a single fixed Worker API host per `BuildConfig.RELEASE_CHANNEL`, which fails when that endpoint is unreachable while an alternate gateway (for example the LAN IP backend) is available. Operators need resilient routing without separate builds, and WebSocket plus HTTPS traffic must stay on the same chosen entry point for the rest of the process lifetime.

## What Changes

- Define **per-channel candidate API base URLs** (scheme + authority + optional path prefix, no trailing slash):
  - When **not** in the production release channel (`RELEASE_CHANNEL != 1` / `BuildConfig.RELEASE_CHANNEL == false`): `https://api-test.lasercyber.workers.dev`, `http://47.86.53.176:8080/test`
  - In the **production** release channel (`RELEASE_CHANNEL == 1` / `BuildConfig.RELEASE_CHANNEL == true`): `https://api-prod.lasercyber.workers.dev`, `http://47.86.53.176:8080/prod`
- On **network available** (`ConnectivityManager.NetworkCallback.onAvailable`), **concurrently** probe each candidate by requesting its **`/`** route (same scheme and host/path as the candidate; join so the probe targets the root path of that origin’s URL space).
- Use the **first candidate to succeed** the probe; **cancel or ignore** remaining in-flight probes immediately so no extra work continues after a winner is chosen.
- **Pin** the chosen base URL **in memory** for the remainder of the process; all subsequent HTTPS calls that use the device API origin and all **`/ws/device`** WebSocket connections **MUST** use this selection (not a static per-build host).
- Re-run selection when appropriate on new network availability if product policy requires (default in design: re-probe on each `onAvailable` so a recovered network can switch entry points; still “one winner at a time” with in-memory pin between probes—see design).

## Capabilities

### New Capabilities

- `device-api-origin-selection`: Release-channel candidate lists, concurrent `/` health probe, first-wins cancellation semantics, in-memory selected API base URL, and rules for deriving HTTPS and WSS URLs from that base (including origins with a non-empty path prefix).

### Modified Capabilities

- `device-websocket-connectivity`: Replace fixed-host endpoint scenarios with behavior tied to the **selected** API base URL from `device-api-origin-selection` (same host/path semantics for `wss` as for `https`/`http`).

## Impact

- **Primary**: `DeviceApiOriginConfig` (and any callers of `resolveApiHost` / `resolveHttpsApiOrigin`), `DeviceWebSocketConfig` / `DeviceWebSocketConnectionManager`, and `com.lasercyber.lws.ui.common.call.NetworkCallback` (where `onAvailable` currently triggers WebSocket connect without host selection).
- **HTTP clients** that build URLs from the device API origin (for example presigned upload and any future Worker REST calls) must read the **pinned** origin after selection.
- **Tests**: Update `DeviceWebSocketConnectionTest` and add unit coverage for URL lists, probe race, and path-aware WebSocket URL construction where applicable.
- **Operational**: HTTP fallback candidates use cleartext `http://` on a private IP; cleartext traffic policy / network security config must remain valid for those URLs.
