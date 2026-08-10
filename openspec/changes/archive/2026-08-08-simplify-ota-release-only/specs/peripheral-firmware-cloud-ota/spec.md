## MODIFIED Requirements

### Requirement: Control-board and camera support cloud check and signed download

The App SHALL allow operators to **Check for Updates** for control-board and camera program firmware against public CDN channel manifests at **`https://cdn.lasercyber.com/{artifact}/control-board/release.json`** and **`https://cdn.lasercyber.com/{artifact}/camera/release.json`** (default artifact `lws-hmi`), using the same CDN resolution family as system OTA.

Peripheral cloud checks SHALL always use **`release.json`** (not `staging.json`). Checks MUST NOT require cloud services enabled or a pinned Worker API origin.

When a compatible newer cloud package exists, the Settings upgrade page for that channel SHALL present an update-available state and an **Update Now** (confirm) gate. On confirm, the App SHALL HTTP-download the package URL and sibling `.sig`, Ed25519-verify against `/etc/ota/ed25519.pub`, then apply via the existing control-board Modbus or camera CGI pipeline.

Automatic cloud/bundled version checks for control-board and camera SHALL honor the Device Information **Auto-Check for Updates** master switch (same flag as system OTA and Product Home tips). Those upgrade pages MUST NOT host a separate auto-check checkbox. Auto-check MUST NOT auto-apply; it may only surface the update-available state / prompt toward confirm.

If the CDN manifest is unreachable, the checker SHALL report unavailable/failed for the cloud leg and MUST NOT claim a false “up to date” solely from cloud failure when a bundled comparison was not performed.

#### Scenario: Manual cloud check finds newer control-board firmware

- **WHEN** the operator runs Check for Updates on the control-board upgrade page and `https://cdn.lasercyber.com/lws-hmi/control-board/release.json` points at a HW-matching `.bin` newer than the live control SW
- **THEN** the page SHALL show update available
- **AND** Update Now SHALL download, verify, and start Modbus transfer only after operator confirmation

#### Scenario: Manual cloud check finds newer camera firmware

- **WHEN** the operator runs Check for Updates on the camera program upgrade page and `https://cdn.lasercyber.com/lws-hmi/camera/release.json` points at a model-compatible ZIP newer than live `appVersion`
- **THEN** the page SHALL show update available
- **AND** Update Now SHALL download, verify, and start CGI flash only after operator confirmation

#### Scenario: Peripheral check works with cloud services disabled

- **WHEN** cloud services are disabled and the operator runs Check for Updates on a peripheral upgrade page and the CDN manifest is reachable
- **THEN** the check SHALL run against the CDN `release.json` URL
- **AND** MUST NOT require enabling cloud services

#### Scenario: Verify failure refuses peripheral apply

- **WHEN** a cloud peripheral package fails Ed25519 verification
- **THEN** the App SHALL refuse Modbus or CGI apply
- **AND** MUST NOT claim success

#### Scenario: Auto-check does not auto-apply

- **WHEN** Auto-Check for Updates is enabled on Device Information and a peripheral channel check finds a newer release
- **THEN** the App SHALL surface update available (or an equivalent confirm prompt)
- **AND** MUST NOT start Modbus or CGI flash without operator confirmation

#### Scenario: Master switch gates peripheral auto-check

- **WHEN** Auto-Check for Updates is off on Device Information
- **THEN** Product Home MUST NOT auto-tip peripheral updates
- **AND** opening control-board / camera upgrade pages MUST NOT auto-run a version check solely from that page open
