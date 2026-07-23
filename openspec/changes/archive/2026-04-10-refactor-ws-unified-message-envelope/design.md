## Context

The Android app uses `DeviceWebSocketConnectionManager` to open `wss://.../ws/device`, gate “online” on a server `connected` frame, parse `heartbeat_ack` / `ack` / `command`, and send flat JSON for `heartbeat` and `ack`. The product wants a **single bidirectional envelope** so every frame shares `v`, `type`, `id`, `ts`, and `payload`, with type-specific payloads only inside `payload`.

## Goals / Non-Goals

**Goals:**

- Define wire format: all JSON text frames use the envelope; initial typed payloads: `heartbeat` (device), `heartbeat_ack` and `connected` (server) per product input.
- Keep lifecycle semantics: first server `connected` (under envelope) still marks online; reconnect backoff reset unchanged.
- Document how correlation moves: prefer envelope `id` as the primary message id; `heartbeat_ack` MAY echo the client `id` in the same field or in payload only if explicitly added later.

**Non-Goals:**

- Changing the WebSocket URL, handshake auth, or TCP reconnect policy.
- Implementing server-side changes in this repo (document contract only; backend tracks separately).
- Broader command bus redesign beyond wrapping existing `command` / `ack` flows in the envelope (covered as a follow-on if payloads differ today).

## Decisions

1. **Envelope shape (normative)**  
   Every JSON text frame is an object with:
   - `v` (number): protocol version; start at `1`.
   - `type` (string): discriminator (e.g. `heartbeat`, `connected`).
   - `id` (string): unique id per emitted message (UUID or ulid-style string acceptable).
   - `ts` (number): Unix epoch **milliseconds** (aligns with existing docs and Android `System.currentTimeMillis()`).
   - `payload` (object): type-specific; use `{}` when empty.

   *Rationale:* One parser path, explicit versioning, stable correlation without overloading `type`.

2. **Naming inside `payload`**  
   Use **snake_case** for new payload keys (`sn`, `connection_id`) as specified. For `ack` payloads not listed in the proposal, prefer `command_id`, `correlation_id`, `code` in `payload` when migrating from today’s top-level camelCase, unless backend mandates otherwise.

3. **Breaking change vs compatibility**  
   Default stance: **no dual-parse** in the app long term—server and app deploy together. If needed, a **single release** MAY accept legacy flat `connected` for one version only; treat as temporary and remove in a follow-up.

   *Alternative considered:* Permanent dual parser—rejected as ongoing complexity.

4. **Parsing implementation**  
   Prefer a small DTO or helper (e.g. parse envelope, then switch on `type` and validate `payload` shape) instead of scattered `JsonUtils.getString(text, "type")` on the raw string.

5. **`connected` payload**  
   `payload` MUST contain `sn` (string) and `connection_id` (string). Online gating MAY still require `v === 1` and non-empty `id`/`ts` as in the envelope spec.

## Risks / Trade-offs

- **[Risk] Deploy skew** (server sends old flat JSON, app expects envelope) **→** Mitigation: coordinate release; optional short-lived compatibility branch with feature flag.
- **[Risk] Telemetry today reads `correlationId` from `heartbeat_ack` body** **→** Mitigation: update telemetry to use envelope `id` or agreed payload field before removing old paths.
- **[Trade-off] `ts` as number vs string** **→** Number chosen for consistency with existing millis usage; document in spec.

## Migration Plan

1. Land spec + app changes to emit/parse envelope for `heartbeat`, `heartbeat_ack`, `connected`.
2. Update integration tests / manual smoke: connect → receive `connected` → online; send `heartbeat` → receive `heartbeat_ack`.
3. Deploy backend envelope support, then app (or simultaneous).
4. Remove any temporary legacy parser if introduced.

## Open Questions

- Should `heartbeat_ack` echo the client heartbeat’s `id` in the response envelope `id` field, or always use a server-generated `id`?
- Exact `payload` schema for `command` and `ack` when migrated (fields and required vs optional).
- Whether non-JSON binary frames are allowed; current code treats bytes as UTF-8 text—confirm unchanged.
