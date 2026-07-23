## MODIFIED Requirements

### Requirement: Monitor Videos upload progress uses HMI-styled dialog shell

When the application shows the in-app dialog for **process video file upload progress** from flows that use `VideoUploadProgressDialog` (including Monitor → Videos list upload), the dialog SHALL be hosted by `FrostedGlassDialog` with upload progress content in the custom body slot. The window chrome MUST NOT use framework `AlertDialog` title/button rows as the primary visual container.

#### Scenario: Upload progress on FrostedGlass shell

- **WHEN** the upload progress dialog is shown for a video upload
- **THEN** the overlay MUST use `FrostedGlassDialog.prompt(...).customBodyView(...)` (or an equivalent wrapper)
- **AND** the visual title and progress controls MUST render inside the custom body view

## ADDED Requirements

### Requirement: Upload progress body preserves OTA-style SeekBar and cancel

The frosted-glass upload progress body SHALL retain determinate SeekBar styling aligned with OTA upgrade progress, in-layout cancel, and UI-thread progress updates equivalent to the pre-migration `VideoUploadProgressDialog` API.

#### Scenario: Cancel upload from frosted-glass dialog

- **WHEN** the user taps cancel on the upload progress dialog
- **THEN** the existing cancel-upload callback semantics MUST be preserved
