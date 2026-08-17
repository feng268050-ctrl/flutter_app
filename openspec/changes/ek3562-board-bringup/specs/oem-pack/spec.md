## ADDED Requirements

### Requirement: ek3562 OEM fit_dt cleared when FIT ships

When the OS FIT inventory includes configuration `ek3562`, the ek3562 OEM pack manifest SHALL set `compat.fit_dt` to **`ek3562`** (MUST NOT remain `pending`).

#### Scenario: Pending cleared with inventory

- **WHEN** `ek3562` is an active FIT configuration in the shipping OS
- **THEN** `oem/packs/ek3562-panel/manifest.json` (or successor pack) SHALL declare `compat.fit_dt` equal to `ek3562`
