## Context

Encrypted networks in `WifiActivity` open `dialog_wifi_password` (`R.layout.dialog_wifi_password`). The password `EditText` already submits on `EditorInfo.IME_ACTION_DONE` or hardware Enter via `OnEditorActionListener`. A separate `TextView` (`btn_connect`) duplicates that path. Layout uses `android:imeOptions="actionDone"`, so the keyboard action typically reads as “Done,” not “Connect.”

## Goals / Non-Goals

**Goals:**

- Remove the visible Connect control from the dialog; a single obvious submit path remains.
- Show the soft keyboard’s primary action label as the same localized string as today’s Connect button (`wifi_dialog_connect`).
- Preserve validation (non-empty password before connect), privileged connect call, dialog dismiss, and logging semantics equivalent to the current button path.

**Non-Goals:**

- Changing how `SystemWifiManagerUtils` connects, scan timing, or error toasts beyond what the existing listener already does.
- Redesigning other WiFi screens (details, forget, open networks).

## Decisions

1. **Remove the button from layout (preferred over `visibility="gone"`)**  
   **Rationale:** Avoids dead views and dead code; keeps the dialog hierarchy minimal. **Alternative:** hide in XML — rejected to reduce maintenance of unused IDs.

2. **IME action: use an action that supports a custom label (e.g. `actionGo`) and set the label to `getString(R.string.wifi_dialog_connect)`**  
   **Rationale:** OEM keyboards vary; `setImeActionLabel` is the reliable way to show “Connect” / localized equivalent. **Alternative:** rely on `actionDone` only — rejected because it does not meet the product ask for the Enter key to read “Connect.”

3. **Single submission helper**  
   **Rationale:** Extract the shared “read password → validate → `connectAndSaveWifi` → dismiss” sequence into one method (or keep one listener block) so IME and any future triggers cannot drift. **Alternative:** duplicate logic — rejected.

4. **Editor action handling**  
   **Rationale:** Treat the configured IME action id (after layout/code setup) and hardware Enter (`KEYCODE_ENTER` + `ACTION_DOWN`) the same as today. Stop handling `IME_ACTION_DONE` if the field no longer uses `actionDone`, unless both are set during transition — prefer one clear action id to avoid double-fire edge cases.

## Risks / Trade-offs

- **[Risk]** Some keyboards ignore custom IME labels or show an icon only.  
  **Mitigation:** Still acceptable: primary key remains the submit action; copy matches where the OS supports it.

- **[Risk]** Users who relied on tapping Connect instead of the keyboard must use the IME action.  
  **Mitigation:** Aligns with requested UX; document in release notes if needed.

## Migration Plan

- Ship with the layout + activity change together; no data migration.
- **Rollback:** Revert the layout and `WifiActivity` dialog block; restores button and previous `imeOptions`.

## Open Questions

- None blocking implementation; confirm on-device with the target HMI keyboard if a specific OEM build is in use.
