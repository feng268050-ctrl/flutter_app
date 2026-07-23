## Context

`DeviceRemoteSnapshot` embeds `StaticData` from Room (`static_data`). Today `staticData.commonUse` stores the dominant material **enum** (kept in sync with `common_use_consumable`). The UI resolves text via `EngineerWashConvert.convertCleaningMaterialsText`. WebSocket consumers only see the integer unless they reimplement mapping.

## Goals / Non-Goals

**Goals:**

- Expose **`commonUseText`** next to `commonUse` in JSON for `command.stat_response` (`payload.data.staticData`) and `device.online` (`payload.staticData`), using the **same resolution rules** as the Frequent Usage tile (current app `Resources` / locale).
- Keep **`commonUse`** unchanged for backward compatibility.

**Non-Goals:**

- Sending the full `common_use_consumable` breakdown or per-type counts.
- Server-driven locale or i18n bundles; resolution stays **device-local** at serialization time.
- Persisting `commonUseText` in SQLite (wire-only field).

## Decisions

1. **Transient field on `StaticData` with `@Ignore`**  
   **Rationale:** Snapshot assembly already reads `StaticData` from DAO; filling a non-persisted property right before JSON serialization avoids a parallel DTO and keeps one object graph. **Alternative:** separate `StaticDataWire` type — rejected as extra mapping for little gain.

2. **Populate in the snapshot pack path** (`DeviceStatusPut` / equivalent that builds `DeviceRemoteSnapshot` / `DeviceInfoVo`)  
   **Rationale:** Single choke point so MQTT vs WS stays consistent if both use the same packer. If only WS needs it, still set it there to avoid changing unrelated HTTP payloads unless they share the same object instance (then document).

3. **Unresolvable semantics**  
   When `commonUse` is null or cannot be mapped to a localized label, set `commonUseText` to the literal ASCII string **`unknown`** (lowercase). The field remains present so consumers do not branch on key absence.

4. **No schema version bump**  
   Additive JSON field only; `device-ws-unified-envelope` `v` stays `1`.

## Risks / Trade-offs

- **[Risk] Locale differs from server expectations** → Mitigation: document that `commonUseText` is device UI locale at send time; servers should treat as display hint, not a stable API key.
- **[Risk] Gson serializes `@Ignore` field** → Mitigation: confirm Gson uses field visibility; use `@SerializedName` if needed, or explicit DTO if Room/Gson interaction is awkward.
- **[Risk] Double mutation** → Mitigation: clone or set-and-clear around serialization if the same `StaticData` instance is cached elsewhere (unlikely for `getOneData()` if only used for outbound pack).

## Migration Plan

- Deploy app update; servers may start reading `commonUseText` optionally.
- Rollback: stop reading the field; older app versions simply omit it.

## Open Questions

- Whether HTTP/MQTT payloads that embed `StaticData` should also carry `commonUseText` for parity (decision: match proposal — WS snapshot paths only unless implementation shares one code path and always sets the field).
