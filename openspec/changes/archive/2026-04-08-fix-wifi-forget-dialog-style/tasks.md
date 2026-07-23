## 1. Dialog style alignment

- [x] 1.1 Locate the WiFi forget/disconnect confirmation dialog layout/style resources and the Date & Time timezone dialog style references.
- [x] 1.2 Update WiFi confirmation dialog container, typography, and spacing to match the app-standard dialog style pattern used by the timezone dialog.
- [x] 1.3 Align `Confirm` and `Cancel` button visual treatment (shape, text sizing, state colors, spacing) with the same dialog style family.

## 2. Integration and validation

- [x] 2.1 Ensure dialog creation/binding code references the updated layout/style resources without changing forget-network business behavior.
- [x] 2.2 Validate in dark theme emulator/device that the updated dialog is visually consistent with timezone dialog and has no text clipping or button overlap.
- [x] 2.3 Run a quick regression for forget flow (open dialog, cancel, confirm success/failure paths) to verify no behavioral regressions.
