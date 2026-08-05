## ADDED Requirements

### Requirement: make upgrade honors UPGRADE_PACKAGE when set

In addition to upgrading from tree-built firmware outputs (or the default `ota-package` artifact when that path is active), **`make upgrade` SHALL** honor **`UPGRADE_PACKAGE=`** as specified by the `upgrade-package-input` capability: when the variable is non-empty, use that local `.tar` / `.tar.gz` / `.tgz` as the package input, branching by transport (**SSH/USB-SSH** → host HTTP serve archive **+ sibling `.sig`** + device download + staged **verify**-apply; **RockUSB Loader/Maskrom** → host extract + `di` OTA images). When `UPGRADE_PACKAGE` is unset or empty, existing input resolution for `make upgrade` remains unchanged by this requirement.

#### Scenario: Unset keeps default inputs

- **WHEN** the operator runs `make upgrade` without `UPGRADE_PACKAGE`
- **THEN** the command uses the default firmware/package inputs for the selected transport (not an operator-supplied tarball)

#### Scenario: Set overrides default package source

- **WHEN** the operator runs `UPGRADE_PACKAGE=/path/to/pkg.tar.gz make upgrade` with a valid archive and a selected transport
- **THEN** the upgrade uses that archive per `upgrade-package-input` and does not require regenerating a package solely because tree outputs changed
