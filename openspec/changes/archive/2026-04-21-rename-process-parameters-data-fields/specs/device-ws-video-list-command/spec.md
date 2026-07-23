## ADDED Requirements

### Requirement: List element processParameters JSON uses ProcessParametersData canonical keys

When the system includes `processParameters` in each `command.video_list_response` `data.list` element as a parsed JSON object (per existing list minimization rules), that object SHALL follow the same property naming as `ProcessParametersData` after rename: **`name`**, **`materialType`**, and **`materialName`** for the former `paramsName`, `materials`, and `materialsName` semantics. List serialization MUST NOT reintroduce legacy keys `paramsName`, `materials`, or `materialsName` when emitting parsed objects.

#### Scenario: Parsed list processParameters matches canonical keys

- **WHEN** a list row’s persisted process-parameters string parses to a JSON object that was stored under the renamed model
- **THEN** the `data.list` element’s `processParameters` object MUST expose material and naming fields only under `name`, `materialType`, and `materialName` when those members are present

#### Scenario: Legacy-key JSON is not rewritten by the list path alone

- **WHEN** a row still contains persisted JSON using legacy property names only
- **THEN** parsing MAY fail or yield null `processParameters` per existing unparseable rules; the list command SHALL NOT be required to transform legacy keys (optional separate migration is out of scope for this requirement)
