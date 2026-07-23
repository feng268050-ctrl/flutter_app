## Context

`DeviceApiOriginProber` probes ordered candidate bases on `NetworkCallback.onAvailable`, pins the winner in `DeviceApiOriginConfig` (`pinnedBase`), and all Worker HTTPS + WebSocket URLs derive from that pin via `joinUnderBase` / WebSocket builders. `DeviceInformationFragment.checkUpgrade()` currently builds `manifestUrl` from a constant `LWS_APP_MANIFEST_BASE` pointing at `https://api-prod.lasercyber.workers.dev/view/lws-app/`, ignoring the pin.

## Goals / Non-Goals

**Goals:**

- Build the OTA manifest URL as `joinUnderBase(pinnedBase, "/view/lws-app/" + BuildConfig.LWS_MANIFEST_JSON_FILE)` (or equivalent single helper), preserving behavior for LAN gateways that use a non-empty path prefix on the pinned base.
- Keep `staging.json` vs `release.json` selection exactly as today (`MANIFEST_JSON_FILE` / Makefile).
- Ensure download `url` inside the manifest remains valid (same R2 bucket; presigned or absolute URLs unchanged by this client change).

**Non-Goals:**

- Changing probe candidates, semver rules, zip layout, or manifest JSON schema.
- Persisting the pin to disk or adding new network permissions.

## Decisions

1. **Use `DeviceApiOriginConfig.getPinnedBase()` + existing join helper**  
   Reuse `joinUnderBase` (or the same normalization rules documented in `DeviceApiOriginConfig`) so OTA behaves like `DeviceWorkerPresignedVideoClient` and other Worker calls. **Alternative:** duplicate string concatenation on host only — **rejected** because it breaks path-prefixed bases (`http://host:8080/prod`).

2. **No hardcoded fallback when `getPinnedBase()` is null**  
   If the user opens “check upgrade” before any successful probe, treat as failure (same UX family as manifest HTTP errors today: close loading dialog, show failure / “latest version” message per existing code paths — implementation may tighten messaging in a follow-up). **Alternative:** fall back to `api-prod` — **rejected** per product request to align with pin and avoid split-brain origins.

3. **Single call site**  
   Centralize manifest URL construction in one place (static helper on `DeviceApiOriginConfig` or a tiny `LwsAppManifestUrls` utility) if more than one caller appears during implementation; otherwise inline in `checkUpgrade` is acceptable to minimize churn.

## Risks / Trade-offs

- **[Risk]** OTA check immediately after cold start before `onAvailable` probe completes → pin null → check fails. **Mitigation:** Matches other Worker features; user can retry after network settles; optional later improvement to trigger probe or show “wait for connection” copy.
- **[Risk]** Regression if join helper mishandles trailing slashes. **Mitigation:** Reuse tested `joinUnderBase`; add or extend unit test if a new helper is introduced.

## Migration Plan

- Ship in app release; no server migration (same R2, same `/view/lws-app/*` routes on Worker).
- Rollback: revert client to previous constant base if needed.

## Open Questions

- (none) — product confirmed R2 equivalence and channel split via `staging.json` / `release.json` only.
