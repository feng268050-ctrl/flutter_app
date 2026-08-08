## MODIFIED Requirements

### Requirement: Daemon ships under /opt/hmi via build-app

Product packaging SHALL install `lws_ai_daemon` at `/opt/hmi/bin/lws_ai_daemon` and App-owned companion libraries (e.g. OpenCV) under `/opt/hmi/lib/` during `make build-app` / HMI bundle install when an executable daemon is present at `prebuilt/ai/linux-arm64/lws_ai_daemon` (companions from that tree’s `lib/` as applicable). Packaging MUST NOT require a `.lws-prebuilt` stamp under the AI prebuilt directory. The product MUST NOT install `librknnrt.so` under `/opt/hmi/lib/`; the daemon SHALL load the system RKNN runtime from `/usr/lib/librknnrt.so` (provided by `fetch-rknn-rt` / rootfs). The binary MUST NOT be installed into the shared rootfs overlay as `/usr/bin/lws_ai_daemon`, and the product MUST NOT ship an `ai.service` systemd unit for this daemon.

#### Scenario: Bundle install places binary when daemon prebuilt exists

- **WHEN** `make build-app` runs and `prebuilt/ai/linux-arm64/lws_ai_daemon` is executable
- **THEN** the staged HMI tree contains `bin/lws_ai_daemon` with execute permission
- **AND** MUST NOT add `mediamtx`-style rootfs overlay paths for the AI daemon under `/usr/bin`
- **AND** MUST NOT place `lib/librknnrt.so` under the staged `/opt/hmi` tree
- **AND** MUST NOT require `prebuilt/ai/linux-arm64/.lws-prebuilt` to be present

#### Scenario: Missing daemon fails or skips clearly

- **WHEN** the AI daemon binary is missing at bundle time
- **THEN** the build MUST either fail with a message to run `make build-ai` (when `REQUIRE_AI=1` or equivalent release gate), or skip AI install with an explicit log line
- **AND** the decision MUST NOT depend on a `.lws-prebuilt` stamp file
