# peripheral-firmware-cloud-ota Specification

## Purpose

In-app cloud check/download for control-board and camera program firmware (`release.json` only), newest-wins vs bundled, signed apply, and peripheral safe-update prep (stop work, quiesce/restore radios, quiet C002 during camera flash).

## Requirements

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

### Requirement: Peripheral apply follows safe-update prep

Before control-board Modbus flash or camera CGI flash (operator Update Now, Home tip confirm, or host `make upgrade-control-board` / `upgrade-camera`), the HMI SHALL stop active laser/welding/job outputs (same product safe-state family as whole-device OTA). After the firmware payload is available locally (bundled load, host file, or signed download+verify) and before Modbus/CGI apply begins, the HMI SHALL turn off Wi‑Fi and Bluetooth (Ethernet MAY remain). Radio disable MUST soft-fail when unavailable. When the peripheral flash session ends (success or failure), the HMI SHALL restore Wi‑Fi and Bluetooth that were enabled before quiesce.

#### Scenario: Update Now stops work then quiesces radios before flash

- **WHEN** the operator confirms Update Now for control-board or camera firmware
- **THEN** the HMI stops job/laser outputs before any download or apply
- **AND** after the payload is ready and verified (when downloaded), turns off Wi‑Fi and Bluetooth before Modbus or CGI apply

#### Scenario: Radios restored after peripheral flash

- **WHEN** Wi‑Fi and/or Bluetooth were enabled before peripheral radio quiesce
- **AND** the control-board or camera flash session ends (success or failure)
- **THEN** the HMI SHALL restore those radios that were previously enabled

#### Scenario: Camera firmware upgrade pauses C002

- **WHEN** a camera program firmware apply session is flashing / rebooting / waiting online
- **THEN** the HMI SHALL suspend IP-camera communication health probes
- **AND** SHALL suppress C002 (Camera Communication) alarm edges for that window
- **AND** SHALL resume probes after the session ends (success or failure)

### Requirement: Newest wins between bundled and cloud candidates

For operator policy checks (Settings and Product Home tips), the App SHALL evaluate both the **bundled** candidate (when ship assets exist) and the **cloud** candidate (when cloud check is possible) for each peripheral channel.

The App SHALL offer at most one candidate per channel: the **newer** of bundled vs cloud by the channel’s typed version order (control-board: matching HW then software integer; camera: SemVer then build). When versions are equal, the App SHALL prefer the **bundled** payload (no network download).

Host-force policy (`make upgrade-control-board` / `make upgrade-camera`) SHALL continue to skip this selection gate and apply the host-provided payload after verify.

#### Scenario: Cloud newer than bundled is selected

- **WHEN** bundled control-board SW is 1017 and cloud release.json offers HW-matching SW 1020, and device SW is 1010
- **THEN** the operator offer SHALL select the cloud 1020 payload

#### Scenario: Bundled newer than cloud is selected

- **WHEN** bundled camera ZIP is SemVer/build newer than the cloud release.zip and both are newer than the device
- **THEN** the operator offer SHALL select the bundled ZIP
- **AND** SHALL NOT require a cloud download to apply

#### Scenario: Equal versions prefer bundled

- **WHEN** bundled and cloud candidates parse to the same typed version and both are newer than the device
- **THEN** the operator offer SHALL use the bundled asset
