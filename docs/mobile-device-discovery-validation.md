# Mobile Discovery Validation & Rollback

## Test Cases

### Publish Failure Cases

- Required TXT field missing (`sn` / `model` / `system_version` / `api_ver` / `connect_proto`) => service MUST NOT publish.
- Unsupported `connect_proto` value => publish blocked with diagnosable log.
- Connection service unhealthy => mDNS service unpublish triggered.

### Network Lifecycle Cases

- Wi-Fi disconnect => service unpublish.
- Wi-Fi reconnect with new IP => old service withdrawn and new one published.
- Capabilities changed while internet available => service publish state re-evaluated.

### Endpoint Reachability Cases

- Resolved endpoint unreachable => `ENDPOINT_UNREACHABLE`.
- Handshake timeout > 5000ms => `HANDSHAKE_TIMEOUT`.
- Protocol/version mismatch => `PROTOCOL_MISMATCH`.

### Identity Convergence Cases

- Same device discovered by mDNS and bound by QR/SN maps to same canonical `sn`.
- Existing QR/SN-only flow remains unchanged after enabling mDNS capability.

## Release Readiness Checklist

- `docs/mobile-device-discovery-integration.md` version reviewed with mobile/HMI/QA owners.
- `api_ver` changes include migration notes and compatibility updates.
- On-device logs include mDNS publish/unpublish reason and metadata validation failures.
- Error code mapping verified against mobile app handling matrix.

## Rollback Guidance

If release quality issues are detected:

1. Disable mDNS publish path in HMI startup sequence.
2. Keep existing QR/SN flow active (no change required).
3. Confirm service is no longer visible on LAN (`_lws-device._tcp.` browse returns empty).
4. Maintain endpoint contract docs but mark mDNS feature status as rolled back.