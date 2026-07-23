## ADDED Requirements

### Requirement: Monitor Videos upload progress uses HMI-styled dialog shell

When the application shows the in-app dialog for **process video file upload progress** from flows that use `VideoUploadProgressDialog` (including Monitor → Videos list upload), the window chrome SHALL NOT use the framework default dialog title bar and primary/secondary button strip as the main visual container. The dialog SHALL present a single custom content surface whose panel background, margins, and title typography are consistent with the encrypted WiFi password dialog content layout (`dialog_wifi_password` family: dark panel, centered title text, HMI-appropriate padding).

#### Scenario: No framework title on upload progress dialog

- **WHEN** the upload progress dialog is shown for a video upload
- **THEN** the visual title for the operation is rendered inside the custom content view
- **AND** the `AlertDialog` is not configured with a framework `setTitle` that produces the default Material/AppCompat dialog title region

### Requirement: Upload progress bar matches OTA upgrade SeekBar styling

The determinate progress control inside the upload progress dialog SHALL use the same progress drawable and height/tint configuration as the OTA upgrade in-progress `SeekBar` in `activity_upgrade` (`@drawable/advanced_seekbar_progress`, disabled user interaction, min/max 0–100, background tint and thumb/progress tint semantics aligned with that layout). Progress updates from the existing API SHALL drive that control on the UI thread without changing the meaning of the 0–100 scale.

#### Scenario: Progress advances with same visual language as OTA

- **WHEN** the upload progress percent increases from 0 toward 100 during the video phase
- **THEN** the progress control reflects the clamped percentage
- **AND** its track/thumb appearance is consistent with the OTA upgrade `SeekBar` styling

### Requirement: Status line remains readable during upload phases

The dialog SHALL display a status line (subtitle or detail) that can be updated while uploading (for example metadata phase vs video phase), using text color and size consistent with the OTA upgrade status text pattern (white body text suitable for the dark panel).

#### Scenario: Phase message visible with upload title

- **WHEN** the caller invokes progress update with a non-null message describing the current phase
- **THEN** the user can read that message on the dialog without leaving Monitor → Videos

### Requirement: Cancel remains available with HMI-consistent control

The user SHALL be able to cancel an in-progress upload from the same dialog without relying on the framework `setNegativeButton` strip. Cancel SHALL invoke the same listener behavior as today (abort upload and dismiss). The cancel control SHALL be part of the custom content and styled to fit the HMI dialog card (not the stock alert button row).

#### Scenario: User cancels from custom action

- **WHEN** the user activates the in-layout cancel control while an upload is in progress
- **THEN** the application runs the registered cancel callback and dismisses the dialog
- **AND** no stock alert dialog negative button row is required for that action
