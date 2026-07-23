## Why

Current WiFi management still depends on WiFi suggestion-based behavior, which requires
user-facing approval flows and cannot guarantee silent connect/update/forget operations.
Now that `platform.jks` is available and the app is moving toward a system-level deployment,
WiFi operations should use privileged `WifiManager` APIs for deterministic management.

## What Changes

- Replace suggestion-based WiFi add/connect/forget flow with direct `WifiManager` network
  configuration and control APIs suitable for a system app context.
- Require and validate system-level permission wiring for `NETWORK_SETTINGS`, including
  manifest and build/signing prerequisites needed for privileged runtime behavior.
- Update WiFi list/details interaction behavior so "connect", "disconnect", and "forget"
  actions execute silently through manager APIs instead of routing users into suggestion UX.
- Define failure handling for non-system deployments so behavior is explicit when privileged
  APIs are unavailable.

## Capabilities

### New Capabilities

- `system-wifi-privileged-control`: Defines privileged WiFi control prerequisites and
  silent management behavior for system app builds.

### Modified Capabilities

- `wifi-network-details`: Update requirements from suggestion-based management to
  `WifiManager`-driven silent connect/disconnect/forget operations.

## Impact

- Affected code: WiFi activities/adapters, WiFi operation helpers, and permission checks.
- Affected platform setup: Android manifest permissions, system app signing/deployment
  path, and privileged permission allowlisting.
- Behavioral impact: removes suggestion confirmation dependency and introduces strict
  requirement on privileged/system-app runtime conditions.
