## ADDED Requirements

### Repository alignment (informative)

Current codebase: lens-guard Java types live in `com.lasercyber.lws.ai` (`NativeBridge`, `LensGuardManager`, `AssetDeployer`). Authoritative docs (`APP_INTEGRATION_GUIDE.md`, `LENS_GUARD_APP_CHANGES.md`, `PROJECT_ARCHITECTURE.md`, OpenSpec integrate change) describe the same. The legacy package `com.lasercyber.lws.ui.lensinspector` SHALL NOT be presented as a valid active package path.

### Requirement: Lens Guard Native Bridge Package Migration

The system SHALL use `com.lasercyber.lws.ai` for all active lens-guard native bridge and manager types in application integration code and authoritative integration documents. (Management classes that lived under `com.lasercyber.lws.ui.lensinspector` SHALL resolve to `com.lasercyber.lws.ai`.)

#### Scenario: Application import path migration

- **WHEN** the lens-guard integration code imports the native bridge or managers
- **THEN** the import path SHALL use `com.lasercyber.lws.ai`
- **AND** no active import in app source SHALL reference `com.lasercyber.lws.ui.lensinspector`

#### Scenario: Documentation contract migration

- **WHEN** integration and architecture documents describe engine package paths
- **THEN** they SHALL document `com.lasercyber.lws.ai` as the required package path
- **AND** they SHALL not present `com.lasercyber.lws.ui.lensinspector` as a valid active package contract

### Requirement: Behavior Preservation During Package Migration

The system SHALL preserve lens-guard runtime behavior after package namespace migration.

#### Scenario: Lifecycle continuity

- **WHEN** the application starts and initializes lens-guard manager
- **THEN** manager startup, callback registration, and frame/laser state push flow SHALL remain functionally equivalent to pre-migration behavior

#### Scenario: Callback continuity

- **WHEN** native callbacks `onStateChanged`, `onCheckResult`, and `onAlert` are triggered
- **THEN** the app SHALL continue publishing and handling the same event payload semantics as before migration

### Requirement: Migration Completion Verification

The migration process SHALL include explicit verification that deprecated package references are removed from active integration surfaces.

#### Scenario: Legacy reference scan

- **WHEN** migration changes are prepared for implementation completion
- **THEN** a repository scan SHALL be performed for deprecated package string `com.lasercyber.lws.ui.lensinspector` in app source and for any recommended integration path that is not `com.lasercyber.lws.ai`
- **AND** any remaining match in app source or as a recommended integration path in current guides SHALL be resolved before marking migration complete

#### Scenario: Branch delivery readiness

- **WHEN** migration implementation is completed
- **THEN** changes SHALL be ready for publication to a GitLab branch under `http://git.lasercyber.com/software/lws-ui`
