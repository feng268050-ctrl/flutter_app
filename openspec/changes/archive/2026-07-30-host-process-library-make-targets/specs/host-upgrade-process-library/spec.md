## ADDED Requirements

### Requirement: Host make upgrade-process-library auto-selects by device model

The repository SHALL provide a host helper named `make upgrade-process-library` that connects to the selected board (same USB-SSH / device selection rules as `upgrade-control-board` / `push-app`), reads the product `model` value from `/var/lib/hal/product.ini` on the device, and selects a matching process-library package from the repository without requiring the operator to pass a model name on the Make command line.

#### Scenario: Model read from product.ini

- **WHEN** the operator runs `make upgrade-process-library` and `/var/lib/hal/product.ini` on the selected device contains a non-empty `model=L1 Pro`
- **THEN** the helper SHALL use `L1 Pro` (case-insensitive match) as the device model for library selection
- **AND** SHALL NOT require a Make `MODEL=` (or equivalent) argument for that selection

#### Scenario: Missing or blank device model fails

- **WHEN** the operator runs `make upgrade-process-library` and `model` is absent or blank in `/var/lib/hal/product.ini`
- **THEN** the helper SHALL exit non-zero with an error that states the model could not be read
- **AND** SHALL NOT upload a process-library package

### Requirement: Unmatched process library fails before upload

When selecting a library for `make upgrade-process-library`, the helper SHALL match the device model to a source directory under `app/lws_hmi/assets/process-library/<model>/` where `<model>` is the product model with spaces replaced by underscores (e.g. `L1 Pro` → `L1_Pro`), using the newest valid `<version>.xlsx` in that directory (same newest-semver rules as prepare). If no matching directory or Excel exists, the helper SHALL fail before upload.

#### Scenario: Matching model directory succeeds

- **WHEN** device `model` is `L1 Pro` and `app/lws_hmi/assets/process-library/L1_Pro/` contains at least one valid `<version>.xlsx`
- **THEN** the helper SHALL build an import package from the newest Excel in that directory and proceed to upload

#### Scenario: No matching library errors

- **WHEN** device `model` is `L2` and no `process-library/L2/` (or equivalent underscore form) directory with a valid Excel exists in the repo
- **THEN** the helper SHALL exit non-zero with an error naming the unresolved model
- **AND** SHALL NOT write an upgrade command on the device

### Requirement: Host upgrade uploads package and forces App import

`make upgrade-process-library` SHALL upload the selected package directory to a tmpfs path under `/run/hmi/` and write `/run/hmi/upgrade-process-library.cmd` so a running HMI command watcher imports that package. The forced import SHALL bypass same-version and older-version skip gates used by normal bundled/package import, while still validating package integrity and device-model compatibility.

#### Scenario: Forced re-import of same version

- **WHEN** the device already has the same `library_version` and content hash installed for that source
- **AND** the operator runs a successful `make upgrade-process-library` with HMI running
- **THEN** the App SHALL re-import the uploaded package builtins (not skip as already installed)

#### Scenario: Incompatible package still rejected

- **WHEN** an uploaded package’s manifest has no library entry matching the device model (and no `*` wildcard)
- **THEN** the App SHALL NOT replace builtins
- **AND** the import outcome SHALL report no compatible library

### Requirement: Upgrade helper prerequisites are documented

Makefile `help`, README Make commands, and AGENTS rebuild guidance SHALL document `make upgrade-process-library` as a host-only helper (no firmware image rebuild), note that HMI must be running to consume the command file, and note that boards need an App build that includes the upgrade watcher (one-time `make build-app` + `make push-app` when the App is stale).

#### Scenario: Help lists the target

- **WHEN** an operator runs `make help`
- **THEN** the output SHALL include `upgrade-process-library` with a short description of device-model auto-selection and forced import
