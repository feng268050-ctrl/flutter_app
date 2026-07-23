## ADDED Requirements

### Requirement: OTA zip may include MediaMTX native artifact

The `lws-app` OTA zip payload MAY include a MediaMTX binary artifact with semver metadata. When present and newer than the installed relay binary, the client SHALL apply it per capability **`mediamtx-ota-upgrade`** without breaking unrelated OTA steps (APK, firmware, process-library, ai-library).

#### Scenario: OTA package contains mediamtx bump

- **WHEN** the OTA zip includes a MediaMTX artifact with version newer than installed
- **THEN** the OTA apply path MUST stage the binary for installation on the next safe relay boundary and MUST NOT skip APK or firmware artifacts solely due to MediaMTX handling
