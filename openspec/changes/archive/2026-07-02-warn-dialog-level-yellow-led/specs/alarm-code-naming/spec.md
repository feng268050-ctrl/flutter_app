## ADDED Requirements

### Requirement: W001 wire feeder communication alarm uses distinct title and content resources

`AlarmCodeEnums.W001` SHALL bind:

- `titleId` → `R.string.wire_feeder_communication_alarm_title`
- `contentId` → `R.string.contact_cyber_after_sales_team_text` (or the product-approved body string for W001)

The title string MUST NOT reuse `wire_feeder_communication_alarm_content`. Localized title strings MUST exist in `values`, `values-en`, and `values-zh`.

#### Scenario: W001 dialog shows dedicated title

- **WHEN** the app materializes a W001 warn dialog
- **THEN** `WarnDialogVo.title` MUST come from `wire_feeder_communication_alarm_title`
- **AND** MUST NOT use `wire_feeder_communication_alarm_content` as the title

#### Scenario: W001 enum references title resource

- **WHEN** `AlarmCodeEnums.W001.titleId` is resolved
- **THEN** it MUST equal `R.string.wire_feeder_communication_alarm_title`
