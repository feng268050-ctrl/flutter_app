## Context

`ProcessParametersData` is a Room `@Entity` on `t_process_parameters_data`, Gson-serialized in MQTT/WebSocket paths and stored inside `ProcessParamsVideo.processParametersJson`. Lombok generates accessors from field names; Gson uses Java field names as JSON keys by default. `ProcessParametersNameData` mirrors a subset of columns for lightweight list queries.

## Goals / Non-Goals

**Goals:**

- Rename the three fields on `ProcessParametersData` and SQLite columns in one migration.
- Update every in-repo reference (DAO SQL, bindings, ViewModels, importers, tests, related DTOs).
- Document the **BREAKING** JSON key change in OpenSpec deltas for device WebSocket behavior.

**Non-Goals:**

- Backward-compatible deserialization (`@SerializedName` for old keys) — explicitly excluded.
- Changing cloud APIs, firmware, or server contracts — user handles elsewhere.
- Migrating historical `processParametersJson` text in `t_params_process_video` unless we add an optional explicit task (see Open Questions).

## Decisions

1. **Room column rename via `Migration_N_N+1`** using `ALTER TABLE ... RENAME COLUMN` (SQLite 3.25+) or recreate-table pattern if minimum SDK SQLite is older — implementation shall follow the project’s existing migration style for column renames.
2. **Keep `ProcessParametersNameData` aligned** with the same three property/column names so `@Query` constructor mapping and popup code stay coherent.
3. **No `@SerializedName`** on the renamed fields so Gson wire names match Java names (user coordinates other systems).
4. **Root `openspec/specs/`**: Update in the same change when implementing (or note in tasks for apply phase) so archived truth matches; this change’s `specs/` folder carries deltas until archive merges.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Missed `paramsName` in XML or raw SQL | Grep for legacy strings; run unit/instrumented tests touching DB and WS parsers. |
| Old video rows have old JSON inside `processParametersJson` | Document; optional follow-up migration script or accept nulls until re-record. |
| `name` is a reserved word in SQL | SQLite allows it as identifier when quoted; Room generates quoted identifiers for columns — verify export schema. |

## Migration Plan

1. Ship app with migration that renames three columns on `t_process_parameters_data`.
2. Coordinate server/device JSON updates before or simultaneous with app release (user-owned).
3. Rollback: ship a migration reverting column names only if absolutely needed; data written under new names would need a second rename pass.

## Open Questions

- Whether to add a **one-time UPDATE** that rewrites `processParametersJson` substrings (`paramsName` → `name`, etc.) for in-app consistency; user said no compat on entity — clarify product need before implementing.
