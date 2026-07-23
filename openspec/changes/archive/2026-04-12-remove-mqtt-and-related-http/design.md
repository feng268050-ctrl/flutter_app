## Context

The Android client still carries MQTT (Eclipse Paho), MQTT-specific adapters under the device channel abstractions, and HTTP models or endpoints used to obtain RabbitMQ/MQTT credentials. Product traffic for device command and telemetry is intended to run exclusively over the existing WebSocket stack and unified envelope. Keeping MQTT duplicates lifecycle handling, increases attack surface and bundle size, and contradicts the documented migration away from MQTT.

## Goals / Non-Goals

**Goals:**

- Remove all runtime MQTT usage (connect, subscribe, publish, reconnect, topic routing) from the application.
- Remove HTTP client code and DTOs whose sole purpose is MQTT/RabbitMQ broker authentication or metadata, and stop persisting those credentials where they are no longer needed.
- Collapse command and data channel wiring to the WebSocket implementations only; delete MQTT adapter classes and unregister them from any factory or service locator.
- Align OpenSpec requirements with a single supported device transport for this client.

**Non-Goals:**

- Changing backend WebSocket protocol semantics, payload schemas, or server-side MQTT behavior for other clients.
- Broader refactors of unrelated networking (OTA, general REST) except where they directly reference removed MQTT auth types.
- Renaming every historical `Mq`-suffixed type in one sweep unless it blocks compilation or remains user-visible API surface.

## Decisions

- **Transport**: WebSocket is the only supported device command and device data transport in this app after this change; no feature-flag or silent fallback to MQTT.
- **Dependency removal**: Drop Paho (and any MQTT-specific Android service manifest entries) from Gradle; fix imports and shrink rules accordingly.
- **HTTP removal**: Identify Retrofit interfaces and response wrappers for RabbitMQ/MQTT auth; remove methods and fields from shared login/device info models only when no other feature reads them—prefer a short compatibility read path only if other modules still deserialize stored JSON (handle via migration or default nulls rather than keeping live network calls).
- **Persistence**: If `DeviceInfo` or similar entities store broker username/password, stop writing them and optionally clear on upgrade via Room migration to avoid stale secrets on disk.
- **Tests**: Update or delete tests that assert MQTT-shaped envelopes where WebSocket envelopes are now authoritative; keep behavioral tests on shared parsers only if they still represent valid server payloads over WebSocket.

## Risks / Trade-offs

- **[Risk] Older app versions or documentation still mention MQTT** → Update `docs/network-api-reference.md` and internal migration notes in the same change series so support and QA are not misled.
- **[Risk] Hidden dynamic MQTT bootstrap via reflection or string-built URLs** → Run static search for `mqtt`, `paho`, `rabbitmq`, topic constants, and verify ProGuard consumer rules.
- **[Risk] Server still returns auth fields** → Safe to ignore at HTTP layer if removed from models; confirm Gson/serialization does not require non-null fields (use defaults or `@Nullable`).
- **[Trade-off] Loss of offline MQTT-specific behavior** → Accepted; non-goal if WebSocket already covers operational requirements.

## Migration Plan

1. Land code removal behind a single release (no partial MQTT in production): remove dependencies, delete MQTT packages, strip HTTP calls, adjust DI/wiring, update Room if needed.
2. Run unit tests and a smoke test pass focused on login, device bind, WebSocket connect, process parameter/library push, and command dispatch.
3. Rollback: revert the release commit; no server-side flag required for the client-only removal.

## Open Questions

- Whether any OEM or debug build flavor still forces MQTT via build config (search `BuildConfig` / product flavors).
- Whether backend continues to emit optional RabbitMQ fields on login responses—if yes, client may omit parsing without contract negotiation.
