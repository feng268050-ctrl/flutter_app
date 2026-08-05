## ADDED Requirements

### Requirement: make publish shares ota-package artifact with make upgrade

After the unified OTA packaging path is available, **`make publish`** SHALL use the **same** OTA `tar.gz` (and detached `.sig`) produced by **`make ota-package`** (for the selected `APP` and packaging mode) as its upload artifact. **`make publish`** MUST invoke `ota-package` (or equivalent prerequisite) before upload when using the full `publish` target. Host documentation SHALL state that cloud publish and SSH `make upgrade` share that archive shape; publish MUST NOT invent a second unsigned or differently laid-out cloud-only archive.

#### Scenario: publish prerequisite is ota-package tar.gz

- **WHEN** a developer reads Make/docs for `make publish` or runs `make publish` with packaging available
- **THEN** the uploaded archive bytes are the `ota-package` `tar.gz` (or a content-identical rename for basename rules), not a separate ad-hoc firmware layout

#### Scenario: Docs link upgrade and publish packaging

- **WHEN** a developer reads host upgrade/publish documentation
- **THEN** the text states that both `make upgrade` and `make publish` depend on `make ota-package` for the whole-device `tar.gz`
