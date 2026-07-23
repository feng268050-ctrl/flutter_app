## ADDED Requirements

### Requirement: Static data includes resolved dominant consumable label

When the app serializes `staticData` as part of the remote snapshot (the object carried at `command.stat_response` `payload.data` and at the root of `device.online` `payload`, per `device-ws-unified-envelope`), the JSON object for `staticData` MUST always include string field `commonUseText`. Its value MUST be the device-resolved human-readable label for the dominant consumable material type when `commonUse` maps to one, derived with the same material-type mapping as the on-device Frequent Usage presentation for the current app locale.

The JSON object MUST continue to include integer field `commonUse` when a dominant material code is defined, unchanged from prior behavior. When no label can be resolved (for example `commonUse` is null or has no defined mapping), `commonUseText` MUST be the literal ASCII string `unknown` (lowercase).

#### Scenario: Stat response staticData carries text alongside code

- **WHEN** the device sends `command.stat_response` whose `payload.data.staticData.commonUse` is a non-null material type code
- **THEN** the same `staticData` object MUST include `commonUseText` as a non-empty string consistent with that code under the app’s current locale

#### Scenario: Device online matches stat_response staticData shape

- **WHEN** the device sends `device.online` with a `payload` that includes `staticData`
- **THEN** `staticData` MUST satisfy the same `commonUseText` rules as in `command.stat_response`’s `payload.data.staticData`

#### Scenario: Unknown dominant material

- **WHEN** the remote snapshot is built and `staticData.commonUse` is null or has no defined mapping
- **THEN** `commonUseText` MUST equal `unknown` (literal string), and consumers MUST treat that value as “no resolvable material label” rather than a localized display name
