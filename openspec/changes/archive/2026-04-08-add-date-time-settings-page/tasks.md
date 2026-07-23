## 1. Settings Navigation & Page Skeleton

- [x] 1.1 Add `Date & Time` menu item after `Screen Settings` in the existing Settings list source.
- [x] 1.2 Add route/navigation target and create Date & Time screen scaffold using current Settings page layout/style components.
- [x] 1.3 Ensure page title, back navigation, row spacing, and switch/list visual tokens match existing app Settings style.

## 2. Date & Time State and System Integration

- [x] 2.1 Implement a DateTimeSettings state layer that reads current date/time, timezone, and auto-time/auto-timezone system flags.
- [x] 2.2 Wire `Automatic date & time` toggle to platform/global setting and disable manual date/time controls when enabled.
- [x] 2.3 Wire `Automatic time zone` toggle to platform/global setting and disable manual timezone control when enabled.
- [x] 2.4 Integrate platform public network time/timezone validation/synchronization behavior for auto mode with online/offline status handling.

## 3. Manual Date/Time/Timezone Flows

- [x] 3.1 Implement manual date picker flow and apply selected date via privileged system API when auto-time is off.
- [x] 3.2 Implement manual time picker flow and apply selected time via privileged system API when auto-time is off.
- [x] 3.3 Implement manual timezone picker flow and apply selected timezone via privileged system API when auto-timezone is off.
- [x] 3.4 Add validation and failure messaging for invalid inputs or rejected system writes, preserving previous effective values.

## 4. Permissions and Privileged Configuration

- [x] 4.1 Add required permissions in app manifest for setting system time/timezone and reading/writing related global settings.
- [x] 4.2 Add/update privapp permissions XML to grant the required elevated permissions for this package on system image builds.
- [x] 4.3 Verify permission gating at runtime and provide user-visible failure feedback when platform restrictions still block writes.

## 5. Verification & Regression Checks

- [x] 5.1 Add/adjust tests for Settings menu ordering (Date & Time after Screen Settings) and route opening behavior.
- [x] 5.2 Add/adjust tests for toggle gating rules (manual controls enabled/disabled based on auto toggles).
- [x] 5.3 Validate connected/offline behavior and service-unavailable messaging for automatic synchronization.
- [x] 5.4 Run UI smoke/regression checks to confirm style consistency and no regressions in adjacent Settings pages.

## 6. Home Clock Synchronization

- [x] 6.1 Update home clock special time pipeline to use system time as source of truth instead of internal incremental cache.
- [x] 6.2 Ensure manual Date & Time and timezone changes are reflected on home clock without app restart, and add targeted regression verification.
