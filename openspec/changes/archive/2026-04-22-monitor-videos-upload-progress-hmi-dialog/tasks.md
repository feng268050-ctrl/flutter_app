## 1. Layout and resources

- [x] 1.1 Redesign `dialog_video_upload_progress.xml`: dark panel aligned with `dialog_wifi_password.xml` (background, padding/margins, centered title `TextView` using uploading title string), status message `TextView` styled like OTA `tv_upgrade_status` (white, ~24sp).
- [x] 1.2 Replace horizontal `ProgressBar` with a non-interactive `SeekBar` mirroring `activity_upgrade.xml` (`advanced_seekbar_progress`, min/max height, tints, `enabled=false`, max 100).
- [x] 1.3 Add an in-layout cancel control (button or text) using existing `cancel_text` (or project HMI button style); remove dependence on framework negative button for primary cancel UX.

## 2. Dialog controller

- [x] 2.1 Update `VideoUploadProgressDialog.java`: build `AlertDialog` with `setView` only (no `setTitle`, no `setNegativeButton`); apply window sizing/dim behavior consistent with `WifiActivity.showPasswordDialog` / `dialogOpen` where applicable.
- [x] 2.2 Wire `SeekBar.setProgress` in `updateProgress`; keep `OnCancelUploadListener` for back key / `setOnCancelListener` and the new in-layout cancel action.
- [x] 2.3 Verify lifecycle: `show`/`dismiss`/`isDestroyed` guards unchanged; no leaks from window callbacks.

## 3. Verification

- [x] 3.1 Manual test: Monitor → Videos upload — metadata and video phases, percent updates, cancel, success toast, error toast.
- [x] 3.2 Smoke test other callers (`CameraController`, `DevActivity`) still show and update the dialog correctly.
