# asset-ship-prune Specification

## Purpose

Build-time pipeline that stages a filtered Flutter asset tree for versioned bundles (process library and control-board firmware): multi-version sources in git, ship only the newest entry per selection key.

## Requirements

### Requirement: Build prepares a pruned Flutter ship-asset tree

The repository SHALL provide a prepare step invoked by `make build-app` (and the debug App assemble path) that regenerates a gitignored ship-asset tree under the Flutter App before `flutter assemble`.

The prepare step SHALL select versioned source artifacts from git-checked-in source trees, convert when required, and stage only the newest artifact per selection key into the ship tree declared by `pubspec.yaml`.

The prepare step SHALL NOT require network access to produce ship assets.

#### Scenario: build-app stages ship assets before assemble

- **WHEN** the operator runs `make build-app` with valid source trees present
- **THEN** the prepare step SHALL run before `flutter assemble`
- **AND** the assembled App bundle SHALL contain only the pruned ship-tree contents for those versioned families (not the full multi-version source trees)

#### Scenario: prepare works offline

- **WHEN** prepare runs on a host without network access and sources are already in the working tree
- **THEN** prepare SHALL succeed without downloading process-library or control-board payloads

### Requirement: Ship tree is generated and not hand-edited source of truth

The ship-asset tree SHALL be treated as generated output: it MUST be gitignored (or otherwise not committed as the editorial source of truth). Operators SHALL add or replace versions only in the documented source trees.

#### Scenario: sources remain multi-version in git

- **WHEN** multiple historical versions exist under a versioned source tree
- **THEN** git MAY retain all of them
- **AND** the ship tree after prepare SHALL contain only the newest entry per selection key for that family

### Requirement: Selection keys for prune

For process-library Excel sources, the selection key SHALL be the model directory name, and “newest” SHALL be the highest semantic version among valid `<version>.xlsx` files in that directory (optional leading `v`/`V` stripped before compare).

For control-board firmware sources, the selection key SHALL be the hardware version integer from `LSW01H####S####.bin`, and “newest” SHALL be the highest software version integer for that hardware version.

#### Scenario: process library keeps newest per model

- **WHEN** `process-library/L1_Pro/` contains `1.0.4.xlsx` and `v1.4.0.xlsx`
- **THEN** prepare SHALL ship only the converted library for version `1.4.0` for that model

#### Scenario: firmware keeps newest per hardware

- **WHEN** `assets/firmware/control-board/` contains `LSW01H1000S1013.bin` and `LSW01H1000S1017.bin`
- **THEN** prepare SHALL stage only `LSW01H1000S1017.bin` for hardware 1000 into the ship tree
