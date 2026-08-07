## MODIFIED Requirements

### Requirement: Daemon ships under /opt/hmi via build-app

Product packaging SHALL install `lws_ai_daemon` at `/opt/hmi/bin/lws_ai_daemon` during `make build-app` / HMI bundle install (from `prebuilt/ai/linux-arm64/`). OpenCV MUST be embedded in the daemon binary (static link); the product MUST NOT ship OpenCV shared libraries (`libopencv_*.so*`) under `/opt/hmi/lib/` for the AI daemon. The product MUST NOT install `librknnrt.so` under `/opt/hmi/lib/`; the daemon SHALL load the system RKNN runtime from `/usr/lib/librknnrt.so` (provided by `fetch-rknn-rt` / rootfs). The binary MUST NOT be installed into the shared rootfs overlay as `/usr/bin/lws_ai_daemon`, and the product MUST NOT ship an `ai.service` systemd unit for this daemon.

#### Scenario: Bundle install places binary without OpenCV .so

- **WHEN** `make build-app` runs with a valid AI prebuilt stamp
- **THEN** the staged HMI tree contains `bin/lws_ai_daemon` with execute permission
- **AND** MUST NOT add `mediamtx`-style rootfs overlay paths for the AI daemon under `/usr/bin`
- **AND** MUST NOT place `lib/librknnrt.so` under the staged `/opt/hmi` tree
- **AND** MUST NOT place `lib/libopencv_*.so*` under the staged `/opt/hmi` tree

#### Scenario: Missing prebuilt fails or skips clearly

- **WHEN** AI prebuilt is missing at bundle time
- **THEN** the build MUST either fail with a message to run `make build-ai`, or skip AI install with an explicit log line (implementation MUST pick one consistent policy and document it — prefer fail when AI is part of the product release gate)
