## 1. Permission and system prerequisites

- [x] 1.1 Add or verify `android.permission.NETWORK_SETTINGS` declaration in app manifest and keep related privileged permission comments/docs aligned.
- [x] 1.2 Confirm system-app deployment prerequisites (platform signing, privileged permission allowlist location, install path) are documented for this module.
- [x] 1.3 Implement a runtime capability check utility that determines whether privileged WiFi operations are actually available.

## 2. Replace suggestion-based WiFi action path

- [x] 2.1 Identify and remove/disable suggestion API usage in WiFi connect/forget code paths used by WiFi list/details screens.
- [x] 2.2 Implement `WifiManager`-based connect/disconnect/forget operations in a centralized helper/service used by UI layer.
- [x] 2.3 Ensure operation results return explicit success/failure states so UI does not report silent success on privilege/API failure.

## 3. UI behavior alignment for silent management

- [x] 3.1 Update WiFi details `Forget` flow to call new manager-based operation path and avoid routing users to suggestion/system approval UX.
- [x] 3.2 Update WiFi list action handling (connect/disconnect/update) to use manager-based execution consistently.
- [x] 3.3 Keep existing label/title-case expectations and verify dialogs/messages remain consistent after behavior change.

## 4. Validation and regression checks

- [x] 4.1 Validate privileged silent connect/disconnect/forget behavior on a system build signed with `platform.jks`.
- [x] 4.2 Validate non-privileged build behavior shows actionable failure without crash or misleading success.
- [x] 4.3 Add or update tests/checklists covering manager execution path, error handling, and removal of suggestion dependency.
