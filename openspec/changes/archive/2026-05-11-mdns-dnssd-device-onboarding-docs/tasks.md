## 1. Discovery protocol contract

- [x] 1.1 Define DNS-SD service type and TXT field schema (`sn`, `model`, `fw_ver`, `api_ver`, `connect_proto`) for device-side advertisement.
- [x] 1.2 Add publish-time validation rules for required TXT fields and malformed metadata handling.
- [x] 1.3 Define service publish/unpublish lifecycle rules for network up/down and connection-service health changes.

## 2. Device-side mDNS advertising implementation

- [x] 2.1 Implement HMI app mDNS service publish/unpublish logic tied to device connectivity state.
- [x] 2.2 Implement metadata producer for TXT fields with strict schema validation before publish.
- [x] 2.3 Implement advertisement re-publish on IP change, Wi-Fi reconnect, and service restart events.
- [x] 2.4 Add diagnostics logs/metrics for publish status, metadata errors, and lifecycle transitions.

## 3. Mobile connection entry integration

- [x] 3.1 Define and implement device-side connection endpoint contract consumed after mobile discovery.
- [x] 3.2 Define handshake timeout/error semantics for unreachable endpoint and protocol mismatch cases.
- [x] 3.3 Verify identity mapping from discovered `sn` to existing QR/SN canonical identity.

## 4. Mobile integration documentation deliverables

- [x] 4.1 Produce mobile integration document sections for discovery contract, field definitions, and compatibility matrix.
- [x] 4.2 Produce discovery-to-connection sequence documentation covering happy path and failure/retry flows.
- [x] 4.3 Produce standardized error mapping table and required observability fields.
- [x] 4.4 Produce cross-team acceptance checklist for mobile app, HMI app, and QA sign-off.
- [x] 4.5 Document coexistence boundary with existing mobile QR/SN binding flow and identity convergence rules.

## 5. Verification and rollout readiness

- [x] 5.1 Create test cases for publish failure, network switch re-publish, metadata missing fields, and endpoint unreachability.
- [x] 5.2 Validate at least one real device model end-to-end through mobile discovery and connection flow.
- [x] 5.3 Review document/version alignment in release checklist and confirm rollback guidance for advertisement capability.
