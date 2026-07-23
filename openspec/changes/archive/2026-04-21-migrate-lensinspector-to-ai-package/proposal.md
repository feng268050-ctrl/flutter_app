## Why

Historical Java package `com.lasercyber.lws.ui.lensinspector` is deprecated. The supported contract is `com.lasercyber.lws.ai`, matching the engine delivery format and avoiding ZIP merge confusion.

**Implementation status:** App sources and integration/architecture Markdown are aligned to `com.lasercyber.lws.ai`; remaining checklist items (compile/smoke) are operational verification.

## What Changes

- Java imports use `com.lasercyber.lws.ai` for native bridge and lens-guard managers (`LensGuardManager`, `AssetDeployer`).
- Integration documentation and architecture notes document the same package path and list deprecated names only as migration context.
- Add compatibility and verification requirements to ensure engine callbacks and startup behavior remain unchanged after package migration.
- Define branch delivery expectation for publishing this migration to the GitLab repository branch.

## Capabilities

### New Capabilities
- `lens-guard-package-migration`: Define required behavior for consolidating lens-guard Java under `com.lasercyber.lws.ai` without runtime regression.

### Modified Capabilities
- None.

## Impact

- Affected code: lens-guard integration manager and any classes importing native bridge package.
- Affected docs: integration guide and architecture/change notes that mention old package path.
- Affected workflow: release process must verify branch push to `http://git.lasercyber.com/software/lws-ui` with migration changes.
- External dependency: YOLO engine ZIP package namespace contract (`com.lasercyber.lws.ai`).
