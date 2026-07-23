## 1. Spec and code alignment

- [x] 1.1 Confirm there are no other hardcoded `view/lws-app` or `api-prod.lasercyber.workers.dev` manifest fetch call sites besides `DeviceInformationFragment` (search the repo).

## 2. Manifest URL construction

- [x] 2.1 Replace `LWS_APP_MANIFEST_BASE` string concatenation with URL built from `DeviceApiOriginConfig.getPinnedBase()` and `DeviceApiOriginConfig.joinUnderBase(pinned, "/view/lws-app/" + BuildConfig.LWS_MANIFEST_JSON_FILE)` (or extract a small named helper if it improves readability).

## 3. Absent pin behavior

- [x] 3.1 When `getPinnedBase()` is null, skip the hardcoded prod fallback; end the OTA check with the same user-visible outcome pattern as other manifest failures (existing dialog path), without opening a connection to a guessed host.

## 4. Verification

- [x] 4.1 Run unit tests; add or extend a test if a new URL helper is introduced (mirror `DeviceApiOriginProberTest`-style expectations for join + path prefix).
