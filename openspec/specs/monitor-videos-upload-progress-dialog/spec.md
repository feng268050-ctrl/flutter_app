## Purpose

Normative UI behavior for the in-app **process video upload progress** dialog (`VideoUploadProgressDialog`), including Monitor → Videos: HMI shell aligned with the WiFi password dialog family, determinate progress aligned with OTA upgrade styling, and in-layout cancel.

## ADDED Requirements

### Requirement: Monitor Videos upload progress uses HMI-styled dialog shell

When the application shows the in-app dialog for **process video file upload progress** from flows that use `VideoUploadProgressDialog` (including Monitor → Videos list upload), the dialog SHALL be hosted by `FrostedGlassDialog` with upload progress content in the custom body slot. The window chrome MUST NOT use framework `AlertDialog` title/button rows as the primary visual container.

#### Scenario: Upload progress on FrostedGlass shell

- **WHEN** the upload progress dialog is shown for a video upload
- **THEN** the overlay MUST use `FrostedGlassDialog.prompt(...).customBodyView(...)` (or an equivalent wrapper)
- **AND** the visual title and progress controls MUST render inside the custom body view

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

### Requirement: Upload progress body preserves OTA-style SeekBar and cancel

The frosted-glass upload progress body SHALL retain determinate SeekBar styling aligned with OTA upgrade progress, in-layout cancel, and UI-thread progress updates equivalent to the pre-migration `VideoUploadProgressDialog` API.

#### Scenario: Cancel upload from frosted-glass dialog

- **WHEN** the user taps cancel on the upload progress dialog
- **THEN** the existing cancel-upload callback semantics MUST be preserved
