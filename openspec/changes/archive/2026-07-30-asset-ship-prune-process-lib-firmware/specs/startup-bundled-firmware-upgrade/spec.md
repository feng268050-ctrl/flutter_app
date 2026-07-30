## MODIFIED Requirements

### Requirement: Bundled firmware asset packaging

The repository SHALL keep control-board `.bin` files checked in under the Flutter App source path `assets/firmware/control-board/` (`LSW01H####S####.bin`). Git MAY retain multiple software versions and multiple hardware versions.

`make build-app` (via the shared prepare / ship-prune step) SHALL stage into the Flutter ship-asset tree **only the newest software version per hardware version** from that source directory. Historical bins that are not selected MUST NOT be copied into the shipped App bundle.

At runtime the App SHALL discover bundled bins from the ship asset prefix for control-board firmware and auto-select the newest matching-HW bin among those shipped (typically one per HW after prune).

The host helper `make upgrade-control-board` SHALL continue to select bins from the **git source** tree `assets/firmware/control-board/` (newest or `FIRMWARE_BIN` override), not from the generated ship tree.

#### Scenario: Built App contains bundled firmware asset

- **WHEN** `make build-app` (or equivalent App bundle) completes with one or more configured firmware source bins
- **THEN** the shipped App assets SHALL include a discoverable `LSW01H####S####.bin` for each hardware version that had at least one valid source bin
- **AND** for each such hardware version the shipped software version SHALL be the maximum among sources for that hardware

#### Scenario: Older firmware versions are not shipped

- **WHEN** the source tree contains `LSW01H1000S1013.bin` and `LSW01H1000S1017.bin`
- **THEN** after prepare / `build-app` the App bundle SHALL include `LSW01H1000S1017.bin` for HW 1000
- **AND** SHALL NOT include `LSW01H1000S1013.bin`

#### Scenario: Host helper still sees full source tree

- **WHEN** the operator runs `make upgrade-control-board` without `FIRMWARE_BIN`
- **THEN** the helper SHALL consider all valid bins under the git source `assets/firmware/control-board/` when picking the newest software version
