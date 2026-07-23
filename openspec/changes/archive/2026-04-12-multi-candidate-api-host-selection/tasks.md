## 1. Selection state and URL helpers

- [x] 1.1 Add a small holder (for example on `DeviceApiOriginConfig` or a dedicated class) for the **pinned API base** `HttpUrl`/string, thread-safe read/write, and helpers to join relative API paths and to build `ws`/`wss` `/ws/device` URLs including `sn` encoding.
- [x] 1.2 Encode **ordered** candidate lists for production vs non-production exactly as in `device-api-origin-selection` (match `BuildConfig.RELEASE_CHANNEL` semantics used today in Gradle).

## 2. Concurrent probe on `NetworkCallback`

- [x] 2.1 Implement parallel OkHttp probe calls to each candidate’s **root URL** (`{base}/` per spec) with short timeouts.
- [x] 2.2 Implement first-wins selection: on first successful completion (per spec), `cancel()` other calls and publish the pin; ignore late callbacks from non-winning calls.
- [x] 2.3 Wire `com.lasercyber.lws.ui.common.call.NetworkCallback.onAvailable` to run the probe round **before** triggering `DeviceWebSocketConnectionManager.connectOrReconnect` (or equivalent ordering so the manager sees the updated pin).
- [x] 2.4 Handle **all probes fail**: log clearly; if no prior pin, do not open WS with a guessed static host; if prior pin exists, keep using it until a later successful round (per design).

## 3. Refactor consumers to the pinned origin

- [x] 3.1 Update `DeviceApiOriginConfig.resolveHttpsApiOrigin()` / `resolveApiHost()` (or replace with explicit APIs) so HTTP clients use the **pinned** base; remove use of fixed constants for runtime traffic after a pin exists.
- [x] 3.2 Update `DeviceWebSocketConfig` / `DeviceWebSocketConnectionManager` URL construction to use the **pinned** base and `ws`/`wss` rules from the spec (including `/test` and `/prod` prefixes).
- [x] 3.3 Audit other call sites (for example `DeviceWorkerPresignedVideoClient`, any remaining `HTTPS_ORIGIN_*` uses) and route device Worker traffic through the pinned origin helpers.

## 4. Tests and verification

- [x] 4.1 Extend or replace `DeviceWebSocketConnectionTest` for path-prefixed `ws` URLs and scheme switching.
- [x] 4.2 Add unit tests for URL joining (`/upload/...` on pinned bases with and without path prefix) and probe race / cancel behavior using OkHttp’s `MockWebServer` (or deterministic fakes).
- [x] 4.3 Manual device check: non-production build verifies first reachable candidate is used for both HTTPS and WSS after Wi‑Fi `onAvailable`.
