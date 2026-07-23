## 1. Model and persistence

- [x] 1.1 Add wire-only `commonUseText` on `StaticData` (Room `@Ignore`, not in DB schema) or equivalent non-persisted carrier agreed in design
- [x] 1.2 Confirm Gson / serialization includes the field for remote snapshot JSON and Room ignores it on read/write

## 2. Snapshot assembly

- [x] 2.1 In `DeviceStatusPut` (or single snapshot builder), set `commonUseText` from `EngineerWashConvert.convertCleaningMaterialsText(staticData.getCommonUse())` using app `Context` / `Resources` before packing `DeviceRemoteSnapshot` / `DeviceInfoVo`
- [x] 2.2 When `commonUse` is null or unmapped, set `commonUseText` to literal `unknown` (per spec)

## 3. Verification and docs

- [x] 3.1 Add or update unit/instrumentation test asserting `command.stat_response` / `device.online` JSON contains `staticData.commonUseText` when `commonUse` is set
- [x] 3.2 Update `docs/network-api-reference.md` (or canonical API doc) to list `staticData.commonUseText`

## 4. Spec baseline (post-apply)

- [x] 4.1 After implementation, fold delta from `openspec/changes/ws-staticdata-common-use-text/specs/device-remote-snapshot/spec.md` into `openspec/specs/device-remote-snapshot/spec.md` and archive the change per project workflow
