## Why

Operators need a server-driven way to evict a device from the cloud session and make that state obvious on the HMI. Without handling `command.disconnect`, the client may keep reconnecting and obscure that the session was intentionally terminated.

## What Changes

- Handle inbound WebSocket frames with `type` `command.disconnect` using the unified envelope; read human-readable `reason` from `payload`.
- On receipt: show a blocking-style dialog titled **Disconnected from Server** with body **This device has been forced to disconnect from the server, reason: {reason}** (substitute the payload reason; define fallback when `reason` is missing or empty).
- Close the active WebSocket session from the client side after handling the message.
- Suppress automatic `/ws/device` reconnect for the **remainder of the current application process** using an in-memory flag; **after the app process restarts**, automatic reconnect may run again without waiting for a device reboot.

## Capabilities

### New Capabilities

- (none — behavior extends existing WebSocket and envelope contracts)

### Modified Capabilities

- `device-ws-unified-envelope`: Document the inbound `command.disconnect` frame shape (`payload` includes string `reason`, with normative empty/missing behavior).
- `device-websocket-connectivity`: Define server-forced disconnect handling (user-visible notice, transport teardown, and in-process reconnect suppression).

## Impact

- Device WebSocket client / connection manager (reconnect and backoff logic, connect triggers).
- Inbound JSON dispatch path for `command.disconnect` (alongside existing command types).
- UI thread: dialog presentation (Activity/Application context patterns used elsewhere for global alerts).
