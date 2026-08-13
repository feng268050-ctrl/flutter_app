## ADDED Requirements

### Requirement: OS Settings seat honors host capture

When the OS Settings App is the active Flutter seat (owns the running `flutter-wayland-client` with the present-hook), it SHALL initialize `cyber_capture` and honor the same host command dialect as product HMI Apps (`/run/hmi/capture.cmd`: `screenshot`, `record-start`, `record-stop`, `cleanup`). Host `make screenshot` / `make record-screen` SHALL work without a separate cmd path or Make target for the Settings seat.

#### Scenario: Screenshot while on OS Settings seat

- **WHEN** `os-settings.service` is running the Settings App and the operator runs `make screenshot`
- **THEN** a still is produced via present-hook encode and pulled to `output/screenshot/` as for the HMI seat

#### Scenario: Record while on OS Settings seat

- **WHEN** `os-settings.service` is running the Settings App and the operator runs `make record-screen` then stops
- **THEN** recording finalizes and the artifact is pulled to `output/record-screen/` with host exit 0 on Ctrl+C after a successful save
