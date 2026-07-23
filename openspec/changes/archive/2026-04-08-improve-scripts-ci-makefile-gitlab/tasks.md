## 1. Signing and Gradle

- [x] 1.1 Add documented environment variable names for keystore path, alias, store password, and key password; default to `platform.jks` and `android` where specified when variables are unset.
- [x] 1.2 Wire `app` release `signingConfigs` in `app/build.gradle.kts` (or `gradle.properties`) so release builds use those values without committing secrets.
- [x] 1.3 Add `.env.example` listing the variable names only (no real secrets) and ensure `.env` is gitignored if not already.

## 2. Device preflight script

- [x] 2.1 Implement `scripts/ci/` helper(s) that verify at least one adb device with state `device`, that `/system` is writable via adb, and that `/system/etc/permissions/privapp-permissions-com.lasercyber.lws.ui.xml` exists and grants `android.permission.NETWORK_SETTINGS` to `com.lasercyber.lws.ui`.
- [x] 2.2 Ensure all checks fail fast with non-zero exit and stderr messages suitable for CI logs.

## 3. Install and Makefile

- [x] 3.1 Implement install step that pushes the built release APK to `/system/priv-app/LwsUI/LwsUI.apk` (remount/chmod/chown as needed for the target image) and document prerequisites (root/adb root).
- [x] 3.2 Add root `Makefile` with targets for: `build` (release signed), `check-device` (preflight only), `install` (preflight + install), `test` (preflight + install + `:app` connected AndroidTest + `scripts/ci` scripts such as `wifi-smoke.sh`).
- [x] 3.3 Document `make` targets in `Makefile` help or README snippet (minimal—only what operators need).

## 4. GitLab CI

- [x] 4.1 Add `.gitlab-ci.yml` with build stage producing the APK artifact and test stage running preflight, install, Gradle UI tests, and `scripts/ci/*.sh` participation.
- [x] 4.2 Document required GitLab CI/CD variables for signing and optional runner `tags` for device-attached runners.

## 5. Validation

- [x] 5.1 Run the full local path on a lab device with writable `/system` and valid priv-app XML; fix gaps.
- [x] 5.2 Run pipeline on a hardware-backed runner (or document manual job) to confirm parity with local flow.
