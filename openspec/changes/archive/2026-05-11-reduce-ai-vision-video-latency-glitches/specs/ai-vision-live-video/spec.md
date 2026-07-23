## ADDED Requirements

### Requirement: Root-cause diagnosis precedes latency or artifact remediation

The engineering process for this capability SHALL classify the dominant failure mode before shipping player or buffer tuning that is intended to fix high latency or visible corruption. The classification MUST be supported by at least one reproducible artifact (e.g., same-URL VLC comparison, attributable device logs, or a short field note) that rules out or implicates network, server, decoder, or CPU-contention causes.

#### Scenario: Team addresses reported AI Vision glitching

- **WHEN** elevated latency or corruption is reported  
- **THEN** the team SHALL document a root-cause hypothesis and evidence under the change or linked notes  
- **AND** implementation tasks that change buffering, transport, or decoding SHALL only proceed after that documentation exists or is explicitly waived with recorded rationale  

### Requirement: AI Vision network readiness before playback

The system SHALL configure or verify camera-link Ethernet connectivity (same subnet as IPC) before or at the start of AI Vision RTSP playback, such that unreachable network configuration is visible in diagnostics (log or documented verification steps).

#### Scenario: User opens AI Vision on a bonded camera network

- **WHEN** the user navigates to AI Vision and playback begins  
- **THEN** the implementation SHALL attempt camera-segment Ethernet setup per product configuration  
- **AND** successful or failed attempts SHALL be attributable in device logs without silent failure  

### Requirement: Stable RTSP connection with bounded recovery

The system SHALL connect to the configured RTSP URL using TCP transport as the default mode and SHALL recover from transient failures with bounded retries and backoff such that indefinite hang without user-visible status is avoided.

#### Scenario: Transient RTSP disconnect

- **WHEN** the RTSP session fails or times out during AI Vision playback  
- **THEN** the system SHALL surface a reconnecting or failed state to the operator  
- **AND** retries SHALL stop after a defined maximum count until the user leaves the screen or manual retry is triggered  

### Requirement: Controlled end-to-end latency behavior

The system SHALL favor low-latency playback defaults for AI Vision (within the capabilities of the integrated RTSP stack) including minimizing unnecessary receive/decode buffering where supported.

#### Scenario: Steady playback under nominal LAN

- **WHEN** the network is nominal and the stream parameters are stable  
- **THEN** playback SHALL converge to visibly low delay relative to baseline (measured comparison pre/post change documented in verification notes)  

### Requirement: Reduced visible corruption recovery

When decode or transport errors cause severe visual artifacts, the system SHALL apply a recovery strategy (e.g., stream restart or keyframe-oriented recovery supported by the player) rather than indefinitely displaying corrupted frames.

#### Scenario: Decoder glitch after burst loss

- **WHEN** the player reports an unrecoverable video error supported by integration tests or field checklist  
- **THEN** playback SHALL restart or recover within a bounded interval defined in verification notes  

### Requirement: Diagnostics for new devices

The system SHALL support configuring the RTSP camera host independently of firmware defaults so that DHCP or non-default camera addresses do not silently break AI Vision playback.

#### Scenario: DHCP-assigned IPC address

- **WHEN** the camera IP differs from factory default  
- **THEN** the operator SHALL be able to set the reachable host preserved across process restarts  
- **AND** AI Vision SHALL use that host when opening RTSP  

### Requirement: Optional AI inference must not dominate the video pipeline

When lens-guard inference is enabled, frame processing from the decoding path MUST NOT unboundedly stall decoding; overloaded conditions SHALL degrade AI delivery (bounded queue or configurable decimation) before dropping video decoding entirely unless product policy states otherwise.

#### Scenario: High CPU contention during AI and video

- **WHEN** both video decode callbacks and inference frame delivery are active  
- **THEN** video playback SHALL remain the primary uninterrupted path  
