## Context

The app is a privileged system-style Android UI with an existing Settings information architecture. Users requested a new Date & Time management surface that matches common OEM/Android customization patterns and the app's current visual style. The page must support both automatic network-based synchronization and manual configuration, while correctly gating controls based on Android global settings state and network availability.

This change crosses UI, domain/state, and privileged platform integration layers:
- Settings menu ordering update (Date & Time appears after Screen Settings),
- new Date & Time management screen and interaction states,
- system clock/timezone write operations requiring privileged permissions,
- automatic synchronization behavior tied to Android auto-time / auto-timezone configuration and network state.

## Goals / Non-Goals

**Goals:**
- Provide a Date & Time page consistent with existing Settings screen patterns (row items, toggles, dialogs/pickers, and typography).
- Support auto date/time and auto timezone toggles that use Android system configuration and network-backed time source behavior.
- Support manual date, time, and timezone updates when auto modes are disabled.
- Ensure robust validation and user feedback for invalid/manual inputs, offline cases, and service unavailability.
- Ensure required system/privileged permissions are declared and provisioned for this app.

**Non-Goals:**
- Building a custom NTP stack or proprietary time synchronization backend.
- Replacing Android system time detector/timezone detector algorithms.
- Adding locale/calendar system redesign beyond what is required for date/time setting controls.

## Decisions

1. Use Android system settings as source of truth for auto/manual mode
- Decision: Read/write `Settings.Global.AUTO_TIME` and `Settings.Global.AUTO_TIME_ZONE` (or equivalent platform APIs where available) to back the two toggles.
- Rationale: This aligns behavior with system expectations and makes the UI reflect actual device policy state.
- Alternative considered: Persisting app-local auto flags. Rejected because it would drift from system behavior and confuse users.

2. Use platform-provided time validation/synchronization service for auto mode
- Decision: In auto mode, rely on platform network time/timezone detection stack (public Android framework behavior) instead of custom validation logic.
- Rationale: Matches "common Android customization interaction" and ensures compatibility with device policy and telephony/network providers.
- Alternative considered: app-driven periodic SNTP fetch. Rejected for higher complexity and security/power risks.

3. Manual edit controls are conditionally enabled
- Decision: Disable manual date/time when auto time is enabled; disable manual timezone when auto timezone is enabled.
- Rationale: Prevents contradictory actions and follows Android stock Settings behavior patterns.
- Alternative considered: Allow edits but override later. Rejected because the UX is surprising and nondeterministic.

4. UI interaction model follows existing app style tokens/components
- Decision: Reuse current Settings list item components, switch styles, spacing, dialog style, and page navigation conventions already used by nearby settings pages.
- Rationale: User requested style consistency; this lowers visual risk and implementation complexity.
- Alternative considered: New standalone design language for Date & Time. Rejected as inconsistent with product.

5. Privileged permission model is explicit and auditable
- Decision: Declare required permissions in manifest and grant via privapp permission XML for system image deployment.
- Rationale: Setting system clock and timezone requires elevated privileges; explicit declaration avoids runtime failures.
- Alternative considered: fallback to opening external system settings. Rejected as primary flow because requirement asks in-app management.

## Risks / Trade-offs

- [Risk] Device build variant may restrict direct time/timezone writes even with permissions.  
  → Mitigation: Detect write failures and show deterministic error feedback; keep UI state synced to actual system values.

- [Risk] Network-connected but validation/time source unavailable causes confusing auto mode behavior.  
  → Mitigation: Keep auto toggle state visible, show "unable to sync now" informational status, and preserve last known valid values.

- [Risk] Different Android API levels expose slightly different APIs for time/timezone updates.  
  → Mitigation: Encapsulate platform calls behind one gateway component with API-level guards.

- [Risk] Navigation insertion can regress Settings ordering assumptions/tests.  
  → Mitigation: Update menu ordering tests/snapshots and keep insertion localized to one source list.

## Migration Plan

1. Add Date & Time route, screen, and menu entry in Settings list after Screen Settings.
2. Add system-time gateway abstraction and wire toggles/manual actions.
3. Add/verify manifest + privapp permissions in system image config.
4. Validate on connected and offline device states.
5. Rollback strategy: hide/remove Date & Time entry and disable route via feature gate if privileged integration fails in release validation.

## Open Questions

- Should auto timezone toggle be hidden or disabled on device variants without telephony/location timezone detection support?
- Should manual timezone picker use region/city searchable list or a compact GMT-offset-first list for initial release?
