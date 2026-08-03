## MODIFIED Requirements

### Requirement: make build-ai stages prebuilt stamp

The build system SHALL provide `make build-ai` that cross-compiles the daemon into `prebuilt/ai/linux-arm64/` with a recognizable prebuilt stamp, and SHALL stage App-owned companion shared libraries required at runtime **other than** the Rockchip RKNN runtime. Link-time RKNN inputs remain `prebuilt/rknn-rt` (`make fetch-rknn-rt`). The staged `prebuilt/ai/linux-arm64/lib/` tree MUST NOT include `librknnrt.so` (product runtime uses `/usr/lib/librknnrt.so`). Missing OpenCV or RKNN inputs MUST fail with a clear message pointing at `make build-opencv` / `make fetch-rknn-rt`.

#### Scenario: Successful stage

- **WHEN** OpenCV and RKNN prebuilts are present and `make build-ai` completes
- **THEN** `prebuilt/ai/linux-arm64/lws_ai_daemon` exists and is executable
- **AND** a stamp file exists under that directory for bundle gating
- **AND** `prebuilt/ai/linux-arm64/lib/librknnrt.so` MUST be absent
