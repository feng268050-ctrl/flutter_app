## ADDED Requirements

### Requirement: Remote lock state persists until server unlock

The app SHALL maintain a boolean remote lock flag that is set to true when a valid inbound `command.lock` is processed and set to false only when a valid inbound `command.unlock` is processed. The flag MUST be persisted in durable app-local storage so it survives application process death and device reboot. No on-device settings UI, local override, or timeout SHALL clear the flag.

#### Scenario: Lock survives cold start

- **WHEN** the device has processed `command.lock` and the application process is later killed and restarted
- **THEN** the remote lock flag MUST still be true before any new WebSocket message is received

#### Scenario: Unlock clears persisted lock

- **WHEN** the device processes `command.unlock` while the remote lock flag is true
- **THEN** the persisted remote lock flag MUST become false

#### Scenario: Local actions cannot unlock

- **WHEN** the remote lock flag is true and the user interacts with device settings or restarts the app without receiving `command.unlock`
- **THEN** the remote lock flag MUST remain true

### Requirement: Lock blocks Fast Mode and Engineer Mode entry

While the remote lock flag is true, the app MUST NOT allow the user to enter Fast Mode or Engineer Mode. Any attempt to navigate to those modes (including from the home WebView bridge) MUST fail with a user-visible error indication and MUST NOT start the corresponding activity.

#### Scenario: Home navigation to Fast Mode while locked

- **WHEN** the remote lock flag is true and the home UI requests Fast Mode entry
- **THEN** the app MUST show an error indication to the user and MUST NOT open Fast Mode

#### Scenario: Home navigation to Engineer Mode while locked

- **WHEN** the remote lock flag is true and the home UI requests Engineer Mode entry
- **THEN** the app MUST show an error indication to the user and MUST NOT open Engineer Mode

### Requirement: Lock ejects active Fast or Engineer sessions

When the remote lock flag transitions to true while Fast Mode or Engineer Mode is the active foreground operating session, the app MUST immediately stop in-progress operating actions for that mode using the same safe-stop behavior used when the user exits the mode normally, and MUST navigate the user back to the home screen.

#### Scenario: Lock received during Fast Mode

- **WHEN** the device processes `command.lock` while Fast Mode is active
- **THEN** in-progress Fast Mode operations MUST be stopped and the user MUST be returned to the home screen

#### Scenario: Lock received during Engineer Mode

- **WHEN** the device processes `command.lock` while Engineer Mode is active
- **THEN** in-progress Engineer Mode operations MUST be stopped and the user MUST be returned to the home screen

### Requirement: Remote lock user notification

When the remote lock flag becomes true, the app SHALL present a modal dialog informing the user that the device has been remotely locked. The dialog MUST remain consistent with the locked state until the remote lock flag becomes false.

#### Scenario: Dialog on newly applied lock

- **WHEN** the device processes `command.lock` and the app has a suitable foreground activity
- **THEN** the user MUST be shown a dialog stating the device is remotely locked

#### Scenario: Dialog cleared on unlock

- **WHEN** the device processes `command.unlock`
- **THEN** any remote-lock dialog MUST be dismissed and MUST NOT reappear until a subsequent lock

### Requirement: Lock indicator before WiFi in top chrome

While the remote lock flag is true, the app SHALL display a lock icon immediately to the left of (before) the WiFi status icon in the top application chrome on the main home shell and on screens that use the shared equipment status bar.

#### Scenario: Home shell shows lock icon

- **WHEN** the remote lock flag is true and the main home layout is visible
- **THEN** a lock icon MUST be visible immediately before the WiFi icon in the top bar

#### Scenario: Equipment status bar shows lock icon

- **WHEN** the remote lock flag is true and a screen displays `EquipmentStatusBar`
- **THEN** a lock icon MUST be visible immediately before the WiFi icon in that status bar

#### Scenario: Icons hidden when unlocked

- **WHEN** the remote lock flag is false
- **THEN** the remote lock icon MUST NOT be shown in those locations
