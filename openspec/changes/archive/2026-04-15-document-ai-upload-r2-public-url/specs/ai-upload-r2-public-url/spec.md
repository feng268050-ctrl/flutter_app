## ADDED Requirements

### Requirement: Public HTTPS URL construction for AI R2 objects

The project documentation SHALL state that, for development and integration verification of AI report images stored in R2, a readable HTTPS URL MAY be formed by concatenating the public R2 bucket base host with the object key using exactly one path separator between the host and the first key segment.

#### Scenario: URL has no double slash

- **WHEN** the base host is `https://pub-3955e5ba2e5e40958c5eb9bc14cca6c0.r2.dev` without a trailing slash
- **AND** the object key is `uploads/ai/staging/0/2026-04-15/SN001/550e8400-e29b-41d4-a716-446655440000.jpg`
- **THEN** the full URL SHALL be `https://pub-3955e5ba2e5e40958c5eb9bc14cca6c0.r2.dev/uploads/ai/staging/0/2026-04-15/SN001/550e8400-e29b-41d4-a716-446655440000.jpg`

### Requirement: Normative AI object key includes type and date segments

The normative object key for AI-uploaded images SHALL match:

`uploads/ai/{staging|release}/{type}/{yyyy-mm-dd}/{sn}/{uuid_filename}`

where `{yyyy-mm-dd}` denotes the calendar date path segment formatted consistently with `yyyy-MM-dd` (for example `2026-04-15`), `{type}` is the detection category (currently `0` for the unified failure class), and `{staging|release}` reflects the Worker deployment channel.

#### Scenario: Example key matches documentation

- **WHEN** staging Worker stores a failure-class image for SN `SN001` on `2026-04-15`
- **THEN** the object key SHALL be of the form `uploads/ai/staging/0/2026-04-15/SN001/{uuid_filename}`

### Requirement: Environment segment SHALL be staging or release

The segment immediately after `uploads/ai/` SHALL be either `staging` or `release`, and SHALL NOT be derived from an untrusted client-proclaimed environment field.

#### Scenario: Staging deployment prefix

- **WHEN** a staging Worker writes the object
- **THEN** the key SHALL begin with `uploads/ai/staging/`
