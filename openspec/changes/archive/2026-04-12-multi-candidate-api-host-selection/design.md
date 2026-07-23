## Context

`DeviceApiOriginConfig` today returns a fixed hostname and HTTPS origin from `BuildConfig.RELEASE_CHANNEL` only. `NetworkCallback.onAvailable` immediately calls `DeviceWebSocketConnectionManager.connectOrReconnect`, which ultimately uses that static host. There is no way to prefer a reachable mirror (Worker vs LAN gateway) without rebuilding or manual configuration.

The product already maps **production** vs **non-production** builds using the Gradle-injected `BuildConfig.RELEASE_CHANNEL` boolean (the `RELEASE_CHANNEL` project property is interpreted as a boolean in `app/build.gradle.kts`; this document treats “`RELEASE_CHANNEL=1`” as the **production** channel and “`!=1`” as **non-production**, matching that wiring).

## Goals / Non-Goals

**Goals:**

- Keep **two ordered candidates per channel** as specified: non-production `https://api-test.lasercyber.workers.dev`, `http://47.86.53.176:8080/test`; production `https://api-prod.lasercyber.workers.dev`, `http://47.86.53.176:8080/prod`.
- On **`ConnectivityManager.NetworkCallback.onAvailable`**, start a **race** of lightweight HTTP probes to each candidate’s **`/`** route, pick the **first to succeed**, and **cancel** (or hard-ignore results from) slower calls so work stops promptly after a winner.
- **Pin** the resolved **API base URL** (scheme + authority + optional path prefix, normalized **without** a trailing slash) in process memory; **all** Worker-facing HTTPS calls and **`/ws/device`** WebSockets use this pin until replaced by a later selection (see decision on re-probe).
- Build WebSocket URLs by **scheme switch** (`https`→`wss`, `http`→`ws`) on the same authority and path prefix, then append **`/ws/device`** with correct single-slash joining relative to the pinned base (supports `/test` and `/prod` prefixes).

**Non-Goals:**

- DNS-based failover, client-side load balancing weights, or operator-editable candidate lists in UI.
- Cross-process persistence of the selection (no disk cache requirement).
- Changing server contracts (`/ws/device`, presigned paths) beyond using a new dynamic origin.

## Decisions

1. **Probe method and success criteria**  
   Use **OkHttp** `Call` instances (GET or HEAD) against each candidate’s root URL (`HttpUrl` resolved so the path is `/` on that origin). Treat **success** as: the call completes **without** an `IOException` and an HTTP response is delivered to the callback (any status code is acceptable as long as the server answers—avoids rejecting `/` that returns `404` but proves reachability).  
   *Alternatives considered:* only `2xx` (rejected: LAN gateways may return non-2xx on `/` while API routes work); TCP connect only (rejected: less proof of HTTP stack compatibility).

2. **Concurrency and cancellation**  
   Launch one OkHttp `Call` per candidate on a shared dispatcher; on first success, **`cancel()`** all other in-flight calls and ignore late completions. Use an `AtomicReference` / synchronized guard so only one winner is published.  
   *Alternatives considered:* `ExecutorService.invokeAny` with custom tasks (more boilerplate than OkHttp-native cancel).

3. **Where the race runs**  
   Run the probe from the same **`onAvailable`** path **before** (or as part of ordering before) opening the WebSocket, so the connection manager always reads a **ready pin** when possible. If no probe has completed yet, either queue the WS connect until a pin exists or use a **synchronous** “first probe” gate on that thread—implementation detail left to tasks, but the observable behavior is: **no long-lived use of a stale static default** after the first successful selection in-process.  
   *Clarification for cold start:* when `onAvailable` fires and candidates are probed, the **first** successful completion sets the pin; WS connect triggered from that callback uses the pin.

4. **Re-probe policy**  
   On **each** `onAvailable`, start a **new** probe round (still single winner). If a new winner differs from the previous pin, subsequent HTTP/WS use the new base; cancel in-flight WS connect if needed via existing connection manager replace semantics.  
   *Rationale:* new network interfaces often imply a new best path (Wi‑Fi vs cellular policy is out of scope, but `onAvailable` is the natural hook the user asked for).  
   *Alternative:* pin forever after first success in process (rejected: contradicts “联网回调里” emphasis and hurts network changes).

5. **Failure when every probe fails**  
   Do **not** fall back silently to an arbitrary hardcoded host for WS/HTTP after a failed round; **surface** failure (log + skip connect or retry on backoff) until a later `onAvailable` or user action. Preserve last-good pin **only** if we explicitly keep “sticky on total failure”—default is **no new pin** on all-fail (keep previous pin if any, else remain unselected).  
   *Mitigation for “no pin yet”:* connection attempts wait or no-op with logging until first successful selection.

6. **HTTP cleartext**  
   The `http://47.86.53.176:8080/...` candidates require **cleartext**; rely on existing **network security config** / manifest allowances already assumed for LAN use. No new cleartext domains beyond this IP pattern.

## Risks / Trade-offs

- **[Risk] Race adds latency before first WS connect** → Mitigation: use short connect/read timeouts on probe calls; HEAD if server supports it to reduce body transfer.
- **[Risk] `http` winner implies `ws://` path** → Some intermediaries treat WS differently; mitigated by server parity on both schemes.
- **[Risk] Thundering herd on flaky Wi‑Fi** → Mitigation: cancel losers immediately; optional small jitter is a future optimization (non-goal here).

## Migration Plan

1. Land selection module + wire `NetworkCallback` → probe → pin → `DeviceWebSocketConnectionManager.connectOrReconnect`.
2. Refactor `DeviceApiOriginConfig` (or successor) so HTTP clients call **pinned** HTTPS/http origin helpers.
3. Update unit tests for URL building and WS URL derivation; manual test on device with Wi‑Fi to confirm first reachable gateway wins.

**Rollback:** revert to prior fixed-host `DeviceApiOriginConfig` behavior behind a compile-time flag only if needed for hotfix (non-goal unless production incident).

## Open Questions

- Whether **`/`** on Workers always returns quickly enough for factory floors (if not, switch probe path in a follow-up change with spec delta).
- Whether presigned upload or other flows require **TLS-only** even when LAN `http` wins (product/security decision—currently no extra restriction in requirements).
