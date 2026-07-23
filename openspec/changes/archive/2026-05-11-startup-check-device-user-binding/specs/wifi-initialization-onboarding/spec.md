## ADDED Requirements

### Requirement: Startup post-onboarding hook for binding check
The WiFi initialization onboarding flow SHALL expose a deterministic post-onboarding hook that runs after the WiFi reminder dialog path completes (if shown) or immediately after confirming network-ready state (if reminder is skipped), so downstream startup steps can execute network-dependent checks.

#### Scenario: Hook runs after dialog-based onboarding
- **WHEN** WiFi onboarding presents a reminder dialog path during startup
- **THEN** the post-onboarding hook SHALL run only after that dialog path completes

#### Scenario: Hook runs for already-connected startup
- **WHEN** WiFi onboarding determines startup is already network-ready without showing the reminder dialog
- **THEN** the post-onboarding hook SHALL run in the same startup session
