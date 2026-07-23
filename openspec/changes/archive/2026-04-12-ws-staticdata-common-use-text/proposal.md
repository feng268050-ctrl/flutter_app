## Why

Remote consumers of `command.stat_response` and `device.online` receive `staticData.commonUse` as a material type **enum code** only. They must duplicate the app’s mapping (and locale rules) to show the same human-readable label as the on-device **Frequent Usage** tile. Adding a **device-resolved** string removes that duplication and avoids drift when enums or copy change.

## What Changes

- When building the WebSocket remote snapshot (`command.stat_response` `payload.data` and `device.online` `payload`), **augment** the serialized `staticData` object with a string field **`commonUseText`**: the same resolved label the UI uses for the dominant consumable type (e.g. via `EngineerWashConvert.convertCleaningMaterialsText`), using the **current app locale** at send time.
- **`commonUse`** remains for backward compatibility; **`commonUseText`** is additive (**not BREAKING** for consumers that ignore unknown fields).
- Document the field in the capability spec and implementation notes (serialization path: `DeviceStatusPut` / `DeviceRemoteSnapshot` / Gson or equivalent).

## Capabilities

### New Capabilities

- _(none — behavior is an extension of the existing remote snapshot contract.)_

### Modified Capabilities

- `device-remote-snapshot`: Require that JSON `staticData` in the remote snapshot includes `commonUseText` with defined semantics; when `commonUse` cannot be resolved, `commonUseText` is the literal `unknown`.

## Impact

- Java: `StaticData` (or DTO used only for WS serialization), snapshot builder, tests that assert JSON shape for `stat_response` / `device.online`.
- Docs: `docs/network-api-reference.md` if it lists `staticData` fields.
- Server/clients: may start reading `commonUseText`; old clients unchanged.
