## 1. Startup trigger integration

- [x] 1.1 Identify the startup WiFi onboarding completion path and add a single post-onboarding callback/hook that runs for both dialog and already-connected branches.
- [x] 1.2 Add per-startup idempotency guards to ensure the device-user binding check is triggered at most once per startup session.

## 2. Device users API and model handling

- [x] 2.1 Implement or extend the API client call for `GET /v1/devices/:sn/users` and parse it as `ApiResult`.
- [x] 2.2 Introduce a simplified user summary model containing only `id`, `nickname`, `avatar`, and masked `email`, and map response `data` into this model.
- [x] 2.3 Implement binding-state decision logic: non-empty list means bound; empty list means unbound; API failure logs and exits without false unbound prompt.

## 3. Unbound reminder dialog UX

- [x] 3.1 Create or adapt a scan-to-bind reminder dialog that reuses the WiFi reminder dialog visual style and interaction pattern, binding title and subtitle to `@string/bind_device_dialog_title` and `@string/bind_device_dialog_subtitle`, with the device QR code as the main body content.
- [x] 3.2 Wire dialog content to the same QR source used by `Settings -> Device Information -> Machine Model`.
- [x] 3.3 Show the dialog only when startup binding check concludes unbound, and prevent repeated popups within the same startup session.

## 4. Validation and regression checks

- [x] 4.1 Add/adjust tests for trigger timing across both startup paths: with WiFi reminder and without WiFi reminder.
- [x] 4.2 Add/adjust tests for API response handling (empty vs non-empty data) and dialog display conditions.
- [x] 4.3 Perform manual QA on startup flows to verify no regression in WiFi onboarding behavior and correct scan-to-bind reminder behavior.
