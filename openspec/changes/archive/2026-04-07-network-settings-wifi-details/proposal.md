## Why

The Network Settings Wireless Network flow currently lacks a dedicated details view for a connected WiFi network, making it hard for users to inspect connection information or manage saved networks. Adding a simplified details page improves troubleshooting and gives users direct control to forget a network without leaving the current flow.

## What Changes

- Add a connected-WiFi details entry point in Wireless Network details so users can tap and open a dedicated details page.
- Add a WiFi details screen that matches current app styling, includes a top back button, and presents key connection data (IP Address, Subnet Mask, Router, plus selected additional fields).
- Add a `Forget This Network` action on the details page that both disconnects the current connection and removes the saved network configuration.
- Ensure unavailable values are rendered in a consistent fallback format and keep the layout intentionally simplified versus full Android system settings.

## Capabilities

### New Capabilities
- `wifi-network-details`: Show connected WiFi connection information and provide a single action to forget the network from Network Settings.

### Modified Capabilities
- None.

## Impact

- Affected UI flow in `NetworkSettingFragment` and existing wireless network screens/activities.
- New layout/state handling for WiFi details presentation and action controls.
- WiFi management logic updates for disconnect + remove network in one user action.
- Potential updates to strings/resources for labels and action text.
