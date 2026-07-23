## Context

The device maintains a long-lived `/ws/device` WebSocket with automatic reconnect and network-driven connect attempts, as specified in `device-websocket-connectivity`. The server can evict or administratively disconnect a session; the product needs an explicit HMI signal and must stop “fighting” the server by reconnecting for the rest of the **current app process**.

## Goals / Non-Goals

**Goals:**

- Parse `command.disconnect` on the device WebSocket using the unified envelope (`device-ws-unified-envelope`).
- Present a user-visible dialog with the exact title and body pattern requested (reason interpolated from `payload`).
- Tear down the WebSocket from the client after handling the command.
- Suppress **all** automatic `/ws/device` connect and reconnect behavior **while this process stays alive**, including triggers from exponential backoff and from `NetworkCallback` “network available” events.

**Non-Goals:**

- Defining server-side policy for when `command.disconnect` is sent.
- Persisting suppression across **process** restart (after the app process exits and starts again, normal connect rules apply until another disconnect).
- Changing unrelated command ACK flows unless the server contract explicitly requires an ACK for this type (confirm with backend if ambiguous).

## Decisions

1. **Process-scoped (in-memory) suppression**  
   **Decision:** Hold reconnect suppression in process memory only (for example `AtomicBoolean`), set when `command.disconnect` is handled.  
   **Rationale:** Product requirement: app restart allows reconnect without waiting for device reboot; avoids SharedPreferences / boot receivers and OEM `BOOT_COMPLETED` quirks.  
   **Alternative considered:** Persist across boot — rejected for current product direction.

2. **Where to handle the message**  
   **Decision:** Handle in the same inbound JSON routing layer that dispatches other `command.*` types (next to existing handlers), not in UI fragments.  
   **Rationale:** Keeps transport logic centralized and avoids duplicate listeners.

3. **Dialog presentation**  
   **Decision:** Post to the main thread and use the same shell as WiFi init / global prompts (`GlobalDialogUtil` + layout aligned with `dialog_wifi_init_prompt`).  
   **Rationale:** WebSocket callbacks may not run on the UI thread; match established HMI styling.

4. **Missing or non-string `reason`**  
   **Decision:** Use an empty string for the `{reason}` segment so the sentence remains grammatical (product copy can read “reason: ” with nothing after).

5. **Ordering: dialog vs close**  
   **Decision:** Arm suppression and close the socket immediately so no further frames are processed from the same session; show the dialog when a safe UI context exists.  
   **Rationale:** Avoids race where reconnect starts before suppression is armed.

## Risks / Trade-offs

- **[Risk] Dialog never shows if no activity is resumed** → **Mitigation:** Log and rely on existing activity tracking; optional deferred show out of scope unless requested.

- **[Risk] User kills app to regain cloud session without server cooperation** → **Mitigation:** Accepted by design (process restart clears suppression).

- **[Risk] Server expects an ACK frame** → **Mitigation:** Confirm contract; if required, add outbound ack in implementation and a follow-up spec delta.

## Migration Plan

No data migration. Deploy with app update; devices already connected begin honoring `command.disconnect` once they run the new build.

Rollback: revert the change; older builds ignore unknown `type` values per existing parsing policy.

## Open Questions

- Whether the server requires an outbound acknowledgement frame for `command.disconnect` (if yes, specify `type` and payload in a small follow-up to `device-ws-unified-envelope`).
