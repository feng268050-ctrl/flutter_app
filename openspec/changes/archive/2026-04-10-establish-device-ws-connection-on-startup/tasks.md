## 1. WebSocket Endpoint And Configuration

- [x] 1.1 Add reusable production/test host constants for device WS and future REST usage (`api-prod.lasercyber.workers.dev`, `api-test.lasercyber.workers.dev`)
- [x] 1.2 Implement release-channel-based host selection (`RELEASE_CHANNEL=1` -> prod, otherwise test)
- [x] 1.3 Implement WS URL builder `wss://<host>/ws/device?sn=<device-sn>` with SN validation/encoding safeguards

## 2. Connection Lifecycle Integration

- [x] 2.1 Introduce or extend a device WS connection manager with explicit lifecycle states (including pre-online pending state)
- [x] 2.2 Trigger connect attempts during app startup after required device identity context is available
- [x] 2.3 Trigger connect/reconnect on network or Wi-Fi recovery events without requiring manual action
- [x] 2.4 Transition to online only after receiving the server `connected` frame (not just socket open)

## 3. Failure Handling And Reconnect Policy

- [x] 3.1 Implement exponential backoff reconnect scheduling (`1s`, `2s`, `4s`, ...) with configurable max delay and reset on successful `connected`
- [x] 3.2 Classify handshake HTTP `401` as SN/registration/auth configuration issue and emit actionable diagnostics
- [x] 3.3 Handle close code `4409` as expected replacement behavior and avoid fatal/error escalation
- [x] 3.4 Ensure generic disconnect and transport errors re-enter reconnect flow with proper state transitions

## 4. Protocol Frame Handling (Heartbeat / ACK)

- [x] 4.1 Add outbound heartbeat message support and inbound `heartbeat_ack` handling hooks
- [x] 4.2 Implement command ACK emission with required fields (`commandId`, `data.code`, correlation metadata)
- [x] 4.3 Normalize WS ACK/telemetry events through existing channel abstraction models instead of direct business handling

## 5. Channel Abstraction Alignment

- [x] 5.1 Update command channel lifecycle logic to gate dispatch success on transport online-readiness
- [x] 5.2 Preserve protocol-agnostic ACK observability fields across WS and MQTT routing paths
- [x] 5.3 Update data channel readiness and telemetry behavior to include transport keepalive/heartbeat outcomes

## 6. Validation And Rollout Safety

- [x] 6.1 Add unit/integration tests for host selection, URL generation, and startup/network-recovery connect triggers
- [x] 6.2 Add tests for lifecycle transitions (`connected` gating), reconnect backoff progression, and reset-on-success behavior
- [x] 6.3 Add tests for `401` handshake rejection handling and `4409` replacement close behavior
- [x] 6.4 Verify backward-safe rollout path with protocol routing/feature flag and MQTT fallback
