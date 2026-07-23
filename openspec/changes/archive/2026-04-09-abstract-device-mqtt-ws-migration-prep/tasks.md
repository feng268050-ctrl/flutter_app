## 1. Channel abstraction foundation

- [x] 1.1 Define protocol-agnostic interfaces for data ingestion and command dispatch (`DeviceDataChannel`, `DeviceCommandChannel`)
- [x] 1.2 Define standardized domain models for `DeviceDataEvent`, `DeviceCommandRequest`, and `DeviceCommandResult` with required metadata fields
- [x] 1.3 Add validation and error classification contracts for normalized device data and command lifecycle failures

## 2. MQTT adapter refactor

- [x] 2.1 Refactor existing MQTT data reporting flow to publish through `DeviceDataChannel` instead of direct business handler invocation
- [x] 2.2 Refactor existing MQTT command sending and acknowledgement processing to go through `DeviceCommandChannel`
- [x] 2.3 Implement MQTT adapter mapping rules to convert topic/payload formats into standardized internal models

## 3. Command lifecycle and resilience

- [x] 3.1 Implement unified command lifecycle transitions (`accepted`, `dispatched`, `acknowledged`, `failed`, `timeout`)
- [x] 3.2 Implement timeout handling and idempotent duplicate acknowledgement processing by `correlationId`
- [x] 3.3 Add configurable protocol routing with MQTT default and fallback behavior when selected adapter is unavailable

## 4. Observability and rollout safety

- [x] 4.1 Add protocol-independent structured logs and metrics for both data ingestion and command dispatch paths
- [x] 4.2 Add feature-flag controls for per-device/per-group protocol selection and emergency rollback to MQTT
- [x] 4.3 Add regression and contract tests that verify protocol-agnostic behavior and MQTT compatibility
