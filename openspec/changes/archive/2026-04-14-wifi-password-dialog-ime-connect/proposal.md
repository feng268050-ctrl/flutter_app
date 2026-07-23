## Why

The encrypted WiFi join dialog currently shows both a dedicated Connect control and a soft-keyboard action that does not read as “connect,” which duplicates affordances and feels inconsistent with a single primary action. Aligning submission with the IME action reduces clutter and matches common password-entry patterns on touch devices.

## What Changes

- Remove the in-dialog Connect button from the WiFi password entry dialog layout (or hide it and drop related click handling).
- Configure the password field’s IME so the keyboard’s primary action shows the same Connect label used today (`wifi_dialog_connect` / localized equivalent) and triggers the same validation and connect flow as the removed button.
- Keep existing behavior for empty password (toast / no connect) and dismissal/cancel semantics unchanged unless required by layout cleanup.

## Capabilities

### New Capabilities

- `wifi-password-connect-dialog`: UX and interaction requirements for joining an encrypted network from the WiFi list, specifically the password dialog: no separate Connect control; connect is initiated via the soft keyboard action matching the Connect string.

### Modified Capabilities

- _(none — existing specs cover details page and privileged APIs, not this dialog’s layout.)_

## Impact

- **UI**: `app/src/main/res/layout/dialog_wifi_password.xml` (remove or hide `btn_connect`; adjust `et_password` `imeOptions` / labels as needed).
- **Logic**: `app/src/main/java/com/lasercyber/lws/ui/activitys/other/WifiActivity.java` — remove Connect button listener; extend `OnEditorActionListener` to treat the configured IME action (e.g. `IME_ACTION_GO` or custom action id) like today’s Done/Enter path.
- **Strings**: Reuse existing `wifi_dialog_connect` for the IME label where programmatic labeling is used; no new user-facing copy unless a separate IME-only string is preferred later.
