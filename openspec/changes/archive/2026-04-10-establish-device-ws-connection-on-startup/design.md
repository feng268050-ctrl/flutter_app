## Context

The app currently has MQTT-oriented networking flows and channel abstractions. A new server-side device WebSocket endpoint is now available and must be used when the app starts or regains network connectivity. Environment routing is release-channel dependent:
- production (`RELEASE_CHANNEL=1`) -> `api-prod.lasercyber.workers.dev`
- non-production (`RELEASE_CHANNEL!=1`) -> `api-test.lasercyber.workers.dev`

Connection URL format is `wss://<host>/ws/device?sn=<device-sn>`. Server-side semantics are protocol-specific: online is only confirmed after receiving a JSON `connected` frame, invalid `sn` fails handshake with HTTP `401`, and new sessions may replace old ones (`4409` close on old connection). The device side must also support heartbeat/heartbeat_ack and command ack payload handling.

## Goals / Non-Goals

**Goals:**
- Establish a deterministic WS connection lifecycle triggered by app startup and network recovery events.
- Route endpoint host by release channel with reusable constants (also for future REST migration).
- Mark online state only after receiving `connected`.
- Implement robust reconnect behavior with exponential backoff and bounded retry intervals.
- Define explicit handling for `401` handshake failures and `4409` replacement close behavior.
- Ensure heartbeat and command ACK behaviors are represented in transport-facing logic.

**Non-Goals:**
- Replacing all MQTT business logic in one step.
- Introducing token-based or certificate-based authentication in this iteration.
- Redesigning application-level command schemas beyond current ACK contract fields.
- Changing backend WS API shape (`/ws/device`, query-string `sn`) in this change.

## Decisions

1. **Introduce a dedicated WS connectivity capability and lifecycle state model**
   - Decision: Add a transport-level state machine (`idle`, `connecting`, `connected-pending`, `online`, `reconnecting`, `offline-auth-error`) to avoid false-online state.
   - Rationale: Server `connected` frame is the authoritative online signal; socket-open is insufficient.
   - Alternative considered: Treat socket open as online. Rejected due to protocol mismatch and potential command routing before backend acceptance.

2. **Use static host constants selected by `RELEASE_CHANNEL`**
   - Decision: Keep production/test hosts as explicit constants and choose host at runtime using release channel.
   - Rationale: Keeps endpoint logic simple, auditable, and reusable for pending REST API migration.
   - Alternative considered: Read host from dynamic config only. Rejected for now because channel-based deterministic routing is required immediately.

3. **Trigger connect attempts on startup and network-recovery hooks**
   - Decision: Wire connection manager into app bootstrap and network-availability transitions.
   - Rationale: Ensures automatic recovery without manual intervention and aligns with field-device behavior.
   - Alternative considered: Manual connect only from user actions. Rejected due to unattended deployment requirements.

4. **Exponential backoff with cap and reset-on-success**
   - Decision: Retry delays start at 1s and double (`1s`, `2s`, `4s`, ...) up to a configured max; successful `connected` resets attempt count.
   - Rationale: Balances server protection and device recovery speed.
   - Alternative considered: Fixed retry interval. Rejected because it is either too aggressive during outages or too slow after transient failures.

5. **Classify failure paths by transport/protocol outcome**
   - Decision: Handle `401` as auth/registration configuration issue, `4409` as expected session replacement, and generic disconnect as reconnectable fault.
   - Rationale: Enables actionable logs/telemetry and reduces noisy false errors for expected replacement behavior.
   - Alternative considered: Uniform reconnect on all failures. Rejected because repeated `401` retries hide provisioning issues.

6. **Keep ACK/heartbeat handling in channel abstraction boundary**
   - Decision: WS adapter handles transport framing and forwards normalized ack/data events through existing channel abstractions.
   - Rationale: Preserves protocol-agnostic boundaries and avoids leaking WS specifics into business workflows.
   - Alternative considered: Process WS payloads directly in business services. Rejected due to abstraction regression.

## Risks / Trade-offs

- **[Risk] Reconnect storm during large outage** -> **Mitigation**: exponential backoff with configurable cap and optional jitter.
- **[Risk] Device appears online before server accepts session** -> **Mitigation**: only transition to online after `connected` frame.
- **[Risk] Infinite retry on invalid `sn` (`401`)** -> **Mitigation**: classify auth failure separately, emit diagnostics, and apply slower retry policy or gated retry.
- **[Risk] Duplicate handling around `4409` close** -> **Mitigation**: treat `4409` as expected replacement event and avoid elevated severity logs.
- **[Trade-off] More lifecycle states increase implementation complexity** -> **Mitigation**: centralize state transitions in one manager and keep adapter responsibilities narrow.

## Migration Plan

1. Add WS connectivity constants and URL builder without removing MQTT path.
2. Implement connection manager and state transitions wired to startup/network-recovery events.
3. Integrate WS frame handlers for `connected`, `heartbeat_ack`, and command ACK forwarding.
4. Add reconnect/backoff logic and failure classification (`401`, `4409`, generic faults).
5. Gate rollout behind protocol routing/feature flag where applicable; keep MQTT fallback active.
6. Validate in test channel first (`api-test...`), then production channel (`api-prod...`).

Rollback strategy:
- Disable WS route via feature flag/protocol router and fall back to MQTT command/data channels.
- Keep host constants and parsing helpers as inactive code paths if rollback is required.

## Open Questions

- Should `401` failures use a hard cooldown window before retry, or continue exponential retries with telemetry alerts only?
- Should reconnect backoff include random jitter now or in a follow-up hardening change?
- Do we require explicit heartbeat send interval from device side in this change, or only support handler/parsing for now?
