## ADDED Requirements

### Requirement: Factory image must not package provision payloads

The ynh960 Linux A/B `package-file` used by `make build-img` SHALL NOT list a `provision` partition payload row, in addition to the existing prohibition on `vendor0`–`vendor3`. `scripts/verify-no-vendor-payload.sh` (or successor verify script) SHALL reject `provision` rows and `provision.img` in factory staging. `make build-img` SHALL invoke that verify step before producing `factory.img`.

#### Scenario: build-img fails on provision.img in staging

- **WHEN** `provision.img` is present in the firmware staging directory used for `update.img`
- **THEN** `make build-img` SHALL exit non-zero

#### Scenario: package-file documents provision omission

- **WHEN** inspecting `board/package-file-ynh960-linux-ab`
- **THEN** a comment SHALL state that `provision` is intentionally omitted so `make flash` preserves provision data
- **AND** no `provision` payload row SHALL be present
