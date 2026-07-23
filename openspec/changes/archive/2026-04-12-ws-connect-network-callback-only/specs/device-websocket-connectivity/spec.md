## ADDED Requirements

### Requirement: Network-driven WebSocket connection lifecycle

The device SHALL initiate or refresh the WebSocket `/ws/device` connect attempt from the application's registered `ConnectivityManager.NetworkCallback` when a suitable network becomes available (including when a suitable network is already available at the time the callback is registered). The device SHALL NOT invoke a separate Application bootstrap method whose sole purpose is initiating the first WebSocket connection to `/ws/device`.

#### Scenario: Initial connect uses network callback when network already exists

- **WHEN** a suitable network is already available and the `NetworkCallback` is registered (including at cold start)
- **THEN** the connection manager MUST receive a connect attempt for `/ws/device` without any separate Application startup-only connect invocation

#### Scenario: Reconnect after network recovery

- **WHEN** network connectivity transitions from unavailable to available
- **THEN** the connection manager MUST trigger a new WebSocket connect attempt

## REMOVED Requirements

### Requirement: Startup and network-recovery connection lifecycle

**Reason**: Superseded by network-driven lifecycle; Application bootstrap is no longer a normative connect trigger.

**Migration**: Rely on `NetworkCallback` (`onAvailable` / recovery) to call `connectOrReconnect`; remove `app_startup`-style invocations from Application bootstrap.
