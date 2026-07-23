## 1. English material resource correction

- [x] 1.1 Update weld material option arrays in `values-en` so Continuous Weld and Spot Weld material options are fully English.
- [x] 1.2 Ensure weld material label strings used for selected/current material display have English translations in `values-en`.
- [x] 1.3 Remove or replace hardcoded Chinese fallback text in weld-related list/layout resources used by process parameter displays.

## 2. Weld-mode display path verification

- [x] 2.1 Verify material selector options in Continuous Weld render English under English locale.
- [x] 2.2 Verify material selector options in Spot Weld render English under English locale.
- [x] 2.3 Verify current/selected material text in both weld modes renders English under English locale.

## 3. Regression and quality checks

- [x] 3.1 Confirm Chinese locale still renders original Chinese material labels.
- [x] 3.2 Run lint/build checks for modified resources/layouts and fix introduced issues.
- [x] 3.3 Smoke-test material selection flow to ensure localization changes did not alter material value persistence/encoding behavior.
