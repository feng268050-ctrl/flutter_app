## ADDED Requirements

### Requirement: App maps nativeInferImageToJson to LensGuardInferenceResult

The App SHALL treat `nativeInferImageToJson` wire JSON as unchanged at the JNI boundary. `LensGuardManager.inferFromJpg` MUST map `code`, `level`, `status`, `message`, `imageWidth`, `imageHeight`, `boxes`, and `source` into `LensGuardInferenceResult` without altering native field semantics documented in this capability.

#### Scenario: Code zero mapping

- **WHEN** native returns `"code":0` with `boxes` and stain `status`
- **THEN** `inferFromJpg` MUST set `success` true and preserve `status` vocabulary (`CLEAN`, `MILD`, `HEAVY`)

#### Scenario: Negative code mapping

- **WHEN** native returns `"code":-2`
- **THEN** `inferFromJpg` MUST set `success` false and `code` -2
- **AND** MUST NOT populate fake detection boxes
