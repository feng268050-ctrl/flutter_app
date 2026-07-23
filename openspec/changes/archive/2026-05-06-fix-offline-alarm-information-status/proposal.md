## Why

When the app is not connected to the lower controller, Alarm Information currently shows green "normal" check states based on default values. This is misleading because no real device status has been received yet.

## What Changes

- Add connection/readiness gating for Alarm Information status tiles so "normal" check states are shown only after valid device status and data are available.
- Define offline behavior for the Alarm Information panel: when device status is unavailable, status checks must remain unselected instead of defaulting to "normal."
- Keep existing alarm evaluation logic unchanged once real device status/data has been received.

## Capabilities

### New Capabilities
- `offline-alarm-status-readiness`: Defines readiness-aware rendering for Alarm Information status indicators when device connection/data is unavailable.

### Modified Capabilities
- `alarm-information-left-panel-layout`: Update requirements so status indicators do not present normal/healthy checks before controller connection and valid status/data readiness.

## Impact

- Affected UI: `app/src/main/res/layout/fragment_warn_info.xml`
- Affected logic: `app/src/main/java/com/lasercyber/lws/ui/activitys/device/monitor/fragment/WarnInfoFragment.java`
- No external API changes.
- No dependency changes.
