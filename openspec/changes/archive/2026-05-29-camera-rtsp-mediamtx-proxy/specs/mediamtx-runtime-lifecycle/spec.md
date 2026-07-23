## ADDED Requirements

### Requirement: APK extracts and executes bundled MediaMTX

The application SHALL extract the bundled MediaMTX binary for the device ABI from `assets/mediamtx/<abi>/mediamtx` into application-private storage, set executable permissions, and MAY launch it via `ProcessBuilder` with the generated configuration file path as a **positional** CLI argument (not `-conf`).

#### Scenario: First launch prepares binary

- **WHEN** the relay coordinator needs MediaMTX and no valid extracted binary exists for the active bundled version
- **THEN** the system MUST extract the asset binary and MUST NOT execute directly from APK assets without extraction

### Requirement: LAN RTSP publish URL for camera main stream

While the relay is active and upstream RTSP is reachable, the system SHALL make the camera main stream (`CameraConfig.RECORDING_RTSP_URL`, path `/PR0`) available to LAN clients at:

**`rtsp://<device-lan-ip>:8554/camera/pr0`**

using TCP-consistent RTSP transport to the upstream camera. The relay MUST NOT re-encode video to another codec (pass-through / remux only).

#### Scenario: LAN client plays relayed PR0

- **WHEN** a client opens `rtsp://<device-lan-ip>:8554/camera/pr0` while the device relay is running and the camera RTSP main stream is reachable
- **THEN** the client MUST receive continuous encoded video from the PR0 stream

### Requirement: Single upstream ingest with multi-reader fan-out

MediaMTX configuration SHALL use one upstream pull of `RECORDING_RTSP_URL` for path `camera/pr0`. Multiple simultaneous RTSP readers on that path MUST NOT each open a separate upstream RTSP session to the camera (fan-out via MediaMTX).

#### Scenario: Two concurrent RTSP viewers

- **WHEN** two LAN clients subscribe to `rtsp://<device-lan-ip>:8554/camera/pr0` at the same time
- **THEN** the camera MUST see at most one upstream RTSP session attributable to MediaMTX for that path (on-demand pull semantics permitted)

### Requirement: Application-controlled start and stop

The application SHALL own MediaMTX process lifecycle: start when the relay policy requires it, stop on application termination or when the coordinator determines the relay is no longer needed, and MUST destroy the process tree on stop to avoid orphans.

#### Scenario: Application process ends

- **WHEN** the Android application process is terminating
- **THEN** any running MediaMTX subprocess started by the app MUST be stopped

### Requirement: Upstream on-demand when configured

When `sourceOnDemand` (or MediaMTX-equivalent) is enabled in generated config, upstream RTSP to the camera MUST connect when the first reader attaches and MUST disconnect after the configured idle period when no readers remain.

#### Scenario: Last viewer disconnects

- **WHEN** the last RTSP client disconnects from `camera/pr0` and idle timeout elapses
- **THEN** the upstream RTSP session to the camera for that path MUST be torn down

### Requirement: Relay failure observability

On start failure, unexpected process exit, or upstream unreachable while readers are attached, the system SHALL emit structured logs including binary path, config path, exit code when applicable, and a short stderr tail.

#### Scenario: MediaMTX exits unexpectedly

- **WHEN** the MediaMTX process exits while the coordinator expects it to be running
- **THEN** the application MUST log exit code and MUST apply bounded restart or degraded state per coordinator policy

### Requirement: Local relay reader URL for on-device consumers

The application SHALL expose a canonical loopback RTSP reader URL for in-process PR0 consumers:

**`rtsp://127.0.0.1:8554/camera/pr0`**

(port and path MUST match the generated MediaMTX config). LAN clients MAY use `rtsp://<device-lan-ip>:8554/camera/pr0` for the same path.

#### Scenario: On-device reader uses loopback

- **WHEN** Fast Mode, Engineer Mode, or HTTP record control starts PR0 recording
- **THEN** `EasyPlayerClient` (or equivalent) MUST connect to `rtsp://127.0.0.1:8554/camera/pr0` and MUST NOT connect directly to `CameraConfig.RECORDING_RTSP_URL`

### Requirement: Fast and Engineer mode recording uses relay fan-out

Process-video recording started from Quick Mode or Engineer Mode UI (`CameraController` → `EasyPlayerClientManger`) SHALL ingest from the local relay reader URL. The system MUST ensure MediaMTX is running (relay lease acquired) before `EasyPlayerClient.start` is invoked for recording.

#### Scenario: User starts record in Fast Mode

- **WHEN** the user starts process-video recording from Fast Mode and preflight checks pass
- **THEN** the recorder MUST pull from `rtsp://127.0.0.1:8554/camera/pr0`
- **AND** the camera MUST have at most one upstream RTSP session for PR0 attributable to MediaMTX

#### Scenario: User starts record in Engineer Mode

- **WHEN** the user starts process-video recording from Engineer Mode and preflight checks pass
- **THEN** the recorder MUST pull from `rtsp://127.0.0.1:8554/camera/pr0`
- **AND** MUST NOT open a parallel direct RTSP session to `RECORDING_RTSP_URL`

### Requirement: HTTP record control uses relay fan-out

`POST /v1/camera/record` with `{ "switch": "on" }` SHALL start PR0 recording through the same relay reader URL and lease semantics as UI-initiated recording in Fast / Engineer mode.

#### Scenario: Remote HTTP record start

- **WHEN** a client successfully starts recording via `POST /v1/camera/record`
- **THEN** `EasyPlayerClientManger` MUST use `rtsp://127.0.0.1:8554/camera/pr0` for ingest
- **AND** MUST NOT use `RECORDING_RTSP_URL` as the player URL

### Requirement: Recording and LAN viewers share one upstream

When PR0 recording and one or more LAN RTSP clients read `camera/pr0` concurrently, all MUST be downstream readers on the same MediaMTX path. The system MUST NOT open a second direct RTSP session from the app to the camera for recording while MediaMTX is the upstream consumer.

#### Scenario: Record while LAN client watches

- **WHEN** a LAN client plays `rtsp://<device-lan-ip>:8554/camera/pr0` and the user starts Fast/Engineer or HTTP recording
- **THEN** both recording and the LAN client MUST continue without the app opening `RECORDING_RTSP_URL` on `EasyPlayerClient`
- **AND** the camera MUST still see at most one upstream PR0 session via MediaMTX

### Requirement: Relay lease while recording is active

The relay coordinator SHALL hold an active lease (or equivalent refcount) for the MediaMTX process for the duration of PR0 recording started through in-scope paths. Releasing the lease on record stop MUST NOT tear down MediaMTX while other valid readers (LAN clients or other leases) remain.

#### Scenario: Record stops with LAN viewer still connected

- **WHEN** recording stops and at least one external reader remains on `camera/pr0`
- **THEN** MediaMTX MUST remain running and the LAN viewer MUST NOT be disconnected solely due to record stop
