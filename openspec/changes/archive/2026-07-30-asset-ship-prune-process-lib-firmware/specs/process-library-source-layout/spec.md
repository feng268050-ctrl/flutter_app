## ADDED Requirements

### Requirement: Process-library sources are Excel-only under process-library

The repository SHALL store default process-library editorial sources under `app/lws_hmi/assets/process-library/<model>/<version>.xlsx`.

Each `<model>` directory name SHALL be the device product `MODEL` string with ASCII spaces replaced by underscores (example: `"L1 Pro"` → `L1_Pro`).

Each `<version>` basename SHALL be a numeric semantic version (`MAJOR`, `MAJOR.MINOR`, or `MAJOR.MINOR.PATCH`), with or without a leading `v` or `V` prefix (examples: `1.0.4.xlsx`, `v1.4.0.xlsx`). The leading prefix SHALL be stripped when recording `library_version` and when comparing versions. Source basenames SHALL NOT include prerelease or build suffixes (e.g. `-beta`, `-alpha`, `+build`).

Each model directory MAY contain **multiple** `<version>.xlsx` files concurrently (one file per library version). Adding a newer version SHALL be done by adding a new file; older version files SHALL remain in the source tree unless an operator explicitly deletes them.

The `process-library/` source tree SHALL contain only those `.xlsx` files as library payloads (no checked-in `manifest.json`, no checked-in converted JSON, no `__source_filename.txt` or equivalent sidecars required for packaging).

#### Scenario: multiple Excel versions coexist per model

- **WHEN** `process-library/L1_Pro/` already contains `1.0.4.xlsx` and an operator adds `v1.5.0.xlsx`
- **THEN** both files SHALL remain valid sources in git
- **AND** prepare SHALL still require no hand-edited manifest in that directory

#### Scenario: operator drops a new Excel version

- **WHEN** an operator adds `app/lws_hmi/assets/process-library/L1_Pro/v1.5.0.xlsx`
- **THEN** the file SHALL be a valid source for prepare without requiring a hand-edited manifest in that directory

#### Scenario: version prefix normalization

- **WHEN** a source file is named `v1.4.0.xlsx`
- **THEN** prepare SHALL treat its library version as `1.4.0`

#### Scenario: prerelease suffix rejected

- **WHEN** a source file is named `1.0.4-beta.xlsx`
- **THEN** prepare SHALL fail and SHALL NOT ship that model

### Requirement: Default process library ships from prepare, not network download

Integrating and refreshing the App’s **default** (bundled) process library SHALL be performed by placing Excel sources in `process-library/` and running the App package pipeline (`make build-app` / push or image bake). The system SHALL NOT require an HTTP or cloud download solely to install or refresh that default bundled library.

Offline USB/OTA package import MAY remain available as a separate operator channel and is not a substitute for the source-tree integration path described here.

#### Scenario: bundled import uses ship assets only

- **WHEN** the App performs bundled process-library import after a successful `build-app`
- **THEN** it SHALL load the prepare-generated ship assets for the process library
- **AND** that import SHALL NOT download a process-library package from the network

#### Scenario: network not required for default library refresh

- **WHEN** a newer Excel is committed under `process-library/` and the App is rebuilt and deployed to the device
- **THEN** the device SHALL be able to import the newer bundled library without a process-library network download step

### Requirement: Prepare converts newest Excel per model into ship JSON and manifest

During prepare, for each model directory under `process-library/` that contains at least one valid `<version>.xlsx`, the system SHALL convert **only the newest** Excel (per semantic version rules) into a versioned JSON payload and SHALL emit a ship-only `manifest.json` listing those converted libraries (including `library_version`, content hash, supported models derived from the model directory, row count, and asset path).

The ship manifest and JSON SHALL NOT be the editorial source of truth; they MUST be produced by prepare into the generated ship tree declared for Flutter assets.

Supported models for a converted entry SHALL include the product model obtained by mapping the directory name with underscores replaced by spaces (example: `L1_Pro` → `L1 Pro`).

#### Scenario: only newest Excel per model is converted for ship

- **WHEN** `L1_Pro` contains both `1.0.4.xlsx` and `1.4.0.xlsx`
- **THEN** prepare SHALL convert `1.4.0.xlsx` for shipping
- **AND** SHALL NOT include a ship manifest entry for `1.0.4` for that model

#### Scenario: model maps to product.ini MODEL

- **WHEN** prepare converts `process-library/L1_Pro/<version>.xlsx`
- **THEN** the generated manifest entry’s `supported_models` SHALL include `L1 Pro`
