## Context

The current WiFi management flow in the app uses suggestion-oriented behavior and fallback
prompts that depend on user confirmation in system UI. This is acceptable for regular apps
but does not meet the requirement for silent enterprise/system deployment behavior. The app
now has access to `platform.jks` and is being prepared for system-level packaging, enabling
privileged APIs guarded by `NETWORK_SETTINGS`.

This change touches UI actions (WiFi list/details), WiFi operation orchestration, and
packaging/permission prerequisites. It also needs explicit runtime handling for cases where
the app is not installed as a privileged system app.

## Goals / Non-Goals

**Goals:**
- Implement silent WiFi connect/disconnect/forget behavior through `WifiManager` APIs.
- Remove dependency on suggestion API flows for WiFi management actions in this module.
- Define required permission and deployment prerequisites for `NETWORK_SETTINGS`.
- Ensure failures surface clearly without crashing when privilege assumptions are not met.

**Non-Goals:**
- Introducing a new generic network stack abstraction for all connectivity features.
- Supporting silent WiFi management on non-system installations.
- Reworking unrelated WiFi UI styling or localization outside behavior-required changes.

## Decisions

1. Use privileged `WifiManager` control path as the default implementation for management
   actions in WiFi screens.
   - Rationale: Provides deterministic behavior without user confirmation dialogs.
   - Alternative considered: Keep suggestion API + partial manager calls. Rejected because
     it still depends on user-facing approval and does not satisfy silent-control goals.

2. Gate privileged execution by both manifest declaration and runtime capability checks.
   - Rationale: Prevents hidden failures when app is signed/installed incorrectly.
   - Alternative considered: Assume privileged environment only. Rejected because it causes
     hard-to-debug failures in development and validation builds.

3. Keep UI action affordances but change operation semantics to manager-driven execution.
   - Rationale: Preserves user flow while replacing backend behavior.
   - Alternative considered: Remove unsupported actions outside system mode. Rejected for now
     to minimize UX churn; explicit errors are shown when privileged control is unavailable.

4. Define deployment requirement for privileged permission allowlisting (`NETWORK_SETTINGS`)
   as part of system image integration.
   - Rationale: Manifest declaration alone is insufficient for signature|privileged permissions.
   - Alternative considered: Treat as environment-only detail outside spec. Rejected because
     missing this requirement causes functional regression at runtime.

## Risks / Trade-offs

- [Privilege mismatch in test devices] -> Mitigation: Add explicit capability checks and
  user-visible error paths so behavior is diagnosable.
- [API behavior differences across Android versions] -> Mitigation: Centralize manager
  operations behind compatibility helpers and validate on target system image versions.
- [Silent failure on restricted OEM builds] -> Mitigation: Log actionable error states and
  keep failure messaging in UI for connect/forget actions.
- [Higher coupling to system deployment process] -> Mitigation: Document signing/permission
  prerequisites in spec and implementation tasks.

## Migration Plan

1. Introduce privileged WiFi operation helpers and wire screens to call them.
2. Remove suggestion-based action path from WiFi management flows.
3. Add/verify `NETWORK_SETTINGS` declaration and privileged deployment prerequisites.
4. Validate behavior on system build signed with `platform.jks`.
5. Rollback path: restore previous suggestion-based path behind a temporary feature toggle
   if privileged deployment cannot be completed in target environment.

## Open Questions

- Which minimum Android API levels/devices are in scope for final validation sign-off?
- Should non-system builds hide privileged actions, or keep actions visible with failure
  messaging as currently planned?
