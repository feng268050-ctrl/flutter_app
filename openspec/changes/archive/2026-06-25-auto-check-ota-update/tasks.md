## 1. Settings UI and preference

- [x] 1.1 Add string resources: `auto_check_ota_update` (自动检查更新 / Auto check for updates), `go_to_update` (前往更新 / Go to update), and optional empty-content fallback for auto-update dialog body
- [x] 1.2 Add `AutoCheckOtaUpdateSettings` SharedPreferences helper (`isEnabled` / `setEnabled`, default `false`)
- [x] 1.3 Update `fragment_device_information.xml`: place centered `FrostCheckboxView` below `btn_check_update` with `app:labelText` `auto_check_ota_update` (engineer reminder checkbox pattern)
- [x] 1.4 Wire checkbox in `DeviceInformationFragment`: load persisted value on bind, persist on checked change

## 2. Shared OTA navigation

- [x] 2.1 Add `OtaUpgradeNavigation` (or equivalent) to build `UpgradeActivity` Intent from `OtaUpdateManifestService.ManifestData` + optional `DeviceInfo` (mirror existing extras in `checkUpgrade`)
- [x] 2.2 Refactor `DeviceInformationFragment#checkUpgrade` success path to call the shared navigation helper (manual behavior unchanged)

## 3. Home prompt: automatic OTA check

- [x] 3.1 Add `AutoOtaUpdateHomePrompt` in `HomePrompts.java` with `order()` **60** (after `BindDeviceHomePrompt` at 50)
- [x] 3.2 Implement `isEligible`: auto-check enabled, first home resume this process, WiFi usable, bind probe cleared (no pending bind dialog), not yet consumed this session
- [x] 3.3 Implement `prepare()`: background `OtaUpdateManifestService.checkAgainst`; cache `NEED_PROMPT` + manifest or `SKIP` on no-update / failure / unpinned base (no user dialogs)
- [x] 3.4 Implement `show()`: `FrostDialog.prompt` with manifest title/content, confirm **Go to update**, cancel dismiss; confirm calls `OtaUpgradeNavigation` without re-fetch
- [x] 3.5 Register prompt in `HomePromptQueue.PROMPTS` and ensure `markConsumedForSession` prevents repeat per process
- [x] 3.6 Avoid duplicate `fetchDeviceUsers` with bind prompt (reuse bind prepare outcome or shared probe)

## 4. Verification

- [x] 4.1 Unit tests: `AutoCheckOtaUpdateSettings` default off and round-trip persist
- [x] 4.2 Unit tests: `AutoOtaUpdateHomePrompt` eligibility matrix (disabled, no WiFi, bind pending, second home resume, has update vs skip)
- [x] 4.3 Unit test or robolectric: confirm navigation passes manifest extras without second `checkAgainst` call
- [x] 4.4 Manual emulator: checkbox checked → cold start → home after bind skip → update dialog → **Go to update** opens `UpgradeActivity` with correct version/url; unchecked → no auto dialog
