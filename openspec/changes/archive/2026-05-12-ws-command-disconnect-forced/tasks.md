## 1. Process-scoped suppression flag

- [x] 1.1 Add an in-memory flag (for example `AtomicBoolean`) representing “forced disconnect — no WS reconnect until process exit”.
- [x] 1.2 Expose read/write helpers on a single owner (`ForcedWsReconnectSuppression`) used by WebSocket lifecycle code.

## 2. Inbound `command.disconnect` handling

- [x] 2.1 Register parsing/dispatch for `type` `command.disconnect` in the existing WebSocket JSON router alongside other `command.*` handlers.
- [x] 2.2 On receipt: read optional string `payload.reason`; normalize non-string / missing to empty string for UI.
- [x] 2.3 Arm suppression before any code path can schedule reconnect; then close the active `/ws/device` socket from the client.

## 3. Reconnect and network triggers

- [x] 3.1 Guard the exponential-backoff reconnect scheduler so it does not start or continue while suppression is active for the current process.
- [x] 3.2 Guard `ConnectivityManager.NetworkCallback` (or equivalent) driven connect attempts so “network available” does not open `/ws/device` while suppression is active in this process.

## 4. User-visible dialog

- [x] 4.1 Post UI work to the main thread; obtain a suitable foreground `Context` / `Activity` using the same strategy as other global alerts in this app.
- [x] 4.2 Show a modal dialog with title `Disconnected from Server` and message `This device has been forced to disconnect from the server, reason: ` + resolved reason string (empty allowed per spec).
- [x] 4.3 Ensure no window leak if the activity is finishing (dismiss or defer per existing patterns).

## 5. Verification

- [x] 5.1 Manual or automated test: inject / simulate `command.disconnect` → dialog copy, socket closed, no reconnect while process lives; after process restart, normal connect may resume.
- [x] 5.2 Confirm with backend whether an ACK frame is required; if yes, add send path and update specs in a follow-up.
