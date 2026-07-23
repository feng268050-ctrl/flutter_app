## Why

Device WebSocket is currently triggered from both `LaserApplication` startup and `NetworkCallback.onAvailable`, with `DeviceWebSocketConnectionManager.connectOrReconnect` deduplicating overlapping calls. That duplicates responsibility, obscures the real trigger (network availability), and invites “defensive” complexity in the connection manager for a problem that can be solved by a single entry point.

## What Changes

- Remove the Application bootstrap path that calls `DeviceWebSocketConnectionManager.connectOrReconnect("app_startup")` (or equivalent) so **only** `NetworkCallback` drives the initial and recovery connect attempts when a suitable network is present.
- Simplify `DeviceWebSocketConnectionManager` by **removing or narrowing** the “skip duplicate connect” short-circuit that exists mainly to paper over dual callers—**after** verifying that internal paths (scheduled backoff retry vs. external `onAvailable`) still behave safely with `synchronized` + `connectionGeneration` alone, or retain the **minimal** guard needed only for true double-invocation races.
- Align normative specs under `device-websocket-connectivity` with the single network-driven lifecycle (**BREAKING** at spec level: “connect on app startup” is no longer a required behavior; first connect is network-callback-driven).

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `device-websocket-connectivity`: Replace the “startup and network-recovery” lifecycle requirement with a **network-callback-driven** lifecycle; remove the mandatory “connect on app bootstrap” scenario.

## Impact

- `LaserApplication` (or whichever bootstrap currently invokes WS connect).
- `NetworkCallback` (already calls `connectOrReconnect`; remains the sole external trigger).
- `DeviceWebSocketConnectionManager` (possible removal/narrowing of duplicate-connect skip logic; verify backoff/reconnect paths).
- Unit tests or docs that assert startup-only WS connect ordering.
- Operators/engineers should expect **no WS connect attempt** until the registered network callback fires (typically when a matching network exists or becomes available).
