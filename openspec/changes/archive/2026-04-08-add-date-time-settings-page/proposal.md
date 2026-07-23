## Why

Current Settings lacks a dedicated Date & Time management surface, making device-level time controls hard to discover and inconsistent with common Android system UX patterns. This change is needed now to support reliable date/time operations, timezone management, and network-synchronized system time in a privileged system app flow.

## What Changes

- Add a new `Date & Time` entry after `Screen Settings` in Settings navigation, following existing app visual style and interaction patterns.
- Create a dedicated Date & Time page that supports:
  - automatic date/time from network (toggle),
  - automatic timezone from network (toggle),
  - manual date selection,
  - manual time selection,
  - manual timezone selection.
- Implement enable/disable behavior: manual controls are disabled when the corresponding automatic switch is enabled.
- Integrate Android platform public validation/time source services for network-based synchronization when connectivity is available and auto mode is on.
- Handle offline and service-unavailable states with clear UI feedback while preserving predictable setting behavior.
- Declare and grant required privileged/system permissions to allow setting system date, time, and timezone.

## Capabilities

### New Capabilities
- `system-date-time-management`: Provide a system-style Date & Time settings experience with automatic and manual controls for date, time, and timezone.

### Modified Capabilities
- `wifi-network-details`: Extend settings navigation ordering to include a `Date & Time` item after `Screen Settings` while keeping existing menu behavior intact.

## Impact

- Affected UI modules under Settings (menu list + new Date & Time screen, related view model/state handling).
- Affected Android integration layer for setting system clock/timezone and observing auto-time configuration.
- Affected manifest/privileged permission configuration (`AndroidManifest.xml` and privapp permissions XML).
- Potential dependency on existing connectivity/state observers to gate network auto-sync status.
